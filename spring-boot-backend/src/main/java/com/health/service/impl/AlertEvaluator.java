package com.health.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.health.domain.entity.AlertRecord;
import com.health.domain.entity.AlertRule;
import com.health.domain.mapper.AlertRecordMapper;
import com.health.domain.mapper.AlertRuleMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 预警评估器
 *
 * 背景（重要）：本项目此前只实现了"预警规则的增删改查"，
 * 却没有评估逻辑 —— 全项目搜 alertRecordMapper.insert 为 0 处引用，
 * 因此 alert_record 表永远是空的，App 里一直显示"暂无预警记录"。
 * 实时心率监控必须能报警，所以补上这一环。
 *
 * 判定语义：
 *   gt      数值 >  threshold1        （如心率 > 100）
 *   lt      数值 <  threshold1        （如心率 < 60）
 *   eq      数值 == threshold1
 *   between 数值在 threshold2 ~ threshold1 之外算越界（按"超出区间"处理）
 *
 * ── 冷却去重（补这一环的原因）────────────────────────────────────────
 * 上面那版"命中就插一条"配合板子的 **5 秒一报**，会把预警列表彻底刷爆：
 * 走路心率 105 的成员，每 5 秒命中一次 → 12 次/分钟 → 约 1.7 万条/天。
 * 实测：spike 场景跑 62 秒（14 次上报）→ alert_record 正好新增 **14 条**，
 * 与上报次数 1:1，用户在预警页看到的是一屏一模一样的记录。
 *
 * 因此命中后先看"这是不是**同一个异常事件的延续**"：
 *   同一事件的延续且距上次记录 < 冷却窗口 → 不新建，只把那条的 update_time 前移
 *   否则（新事件 / 冷却已过）              → 照旧新建
 * 冷却窗口：danger 3 分钟 / warning 与 info 30 分钟。
 *
 * **只按"距上一条多久"判断是不够的**：那会把"降下来又升上去"当成同一次而吞掉，
 * 而这恰恰是最该提醒的情况。所以冷却键里带上"异常是否仍在持续" —— 见
 * {@link #LAST_VIOLATED}。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AlertEvaluator {

    /** 冷却窗口：danger 类异常值得重复提醒，但要收敛到同一数量级 */
    private static final Duration COOLDOWN_DANGER = Duration.ofMinutes(3);

    /** 冷却窗口：warning / info 类 */
    private static final Duration COOLDOWN_DEFAULT = Duration.ofMinutes(30);

    /**
     * 该 (用户, 成员, 规则) **上一次评估**时是否处于异常状态。
     *
     * 用途：区分"异常仍在持续"与"回落之后又升高"。
     *   · 上一条也异常 → 同一次事件，走冷却压制
     *   · 上一条正常   → 新事件，即使还在冷却窗口内也必须新建记录
     *
     * 为什么用内存 Map 而不是查库：它描述的是"紧接着的上一条上报"，本来就只存在于
     * 实时数据流里，库里没有"该规则上一次没命中"的记录可查。
     * 代价是**进程重启后为空**，此时第一个异常读数会被当成新事件而多产生一条记录。
     * 这是刻意选的"失败方向"：告警系统里，静默吞掉一次预警比多记一条严重得多。
     * （同理，多实例部署时每个实例最多各多记一条，之后由 DB 冷却统一压制。）
     */
    private static final Map<String, Boolean> LAST_VIOLATED = new ConcurrentHashMap<>();

    /**
     * LAST_VIOLATED 的容量上限。键的数量本该随 用户×成员×规则 增长（有界），
     * 但成员被删、规则被删后键不会自动消失，所以给个上限兜底：
     * 超了直接清空 —— 清空的后果只是"下一次异常多记一条"，不会漏报。
     */
    private static final int LAST_VIOLATED_MAX = 5000;

    private final AlertRuleMapper alertRuleMapper;
    private final AlertRecordMapper alertRecordMapper;

    /**
     * 对一条健康数据做规则评估，命中则写预警记录。
     *
     * @param userId   数据归属用户
     * @param memberId 数据归属家庭成员
     * @param dataType health_data 的 data_type，如 heart_rate / blood_pressure
     * @param value1   主数值
     * @return 本次**新建**的预警条数（被冷却压制的那些不计入）
     */
    public int evaluate(Long userId, Long memberId, String dataType, BigDecimal value1) {
        if (userId == null || dataType == null || value1 == null) {
            return 0;
        }
        final double v = value1.doubleValue();
        final LocalDateTime now = LocalDateTime.now();

        List<AlertRule> rules = alertRuleMapper.selectList(new LambdaQueryWrapper<AlertRule>()
                .eq(AlertRule::getUserId, userId)
                .eq(AlertRule::getEnabled, 1));
        int created = 0;
        for (AlertRule rule : rules) {
            if (!typeMatches(rule.getAlertType(), dataType)) {
                continue;
            }
            final boolean violated = isViolated(rule, v);
            final String key = stateKey(userId, memberId, rule.getId());
            // 先取上一轮状态，再写入本轮状态（顺序反了会把本轮当成"上一轮"）
            final boolean continuing = Boolean.TRUE.equals(LAST_VIOLATED.get(key));
            rememberState(key, violated);

            if (!violated) {
                // 这一条正常 —— 即便之前有预警，也意味着那次异常已经结束，
                // 于是下一次超标会被正确识别成"新事件"（见类注释）
                continue;
            }

            if (continuing && suppressAsDuplicate(userId, memberId, rule, now)) {
                continue;
            }

            insertRecord(userId, memberId, rule, dataType, v, now);
            created++;
            log.info("预警命中: 用户 {} 成员 {} {}={} 规则「{}」级别 {}",
                    userId, memberId, dataType, v, rule.getRuleName(), rule.getAlertLevel());
        }
        return created;
    }

    /**
     * 同一次异常事件的延续 → 压制（不新建记录，只把那条的 update_time 前移，
     * 仍能看出"异常一直持续到什么时候"）。
     *
     * @return true 表示本次已被压制，不应再新建
     */
    private boolean suppressAsDuplicate(Long userId, Long memberId, AlertRule rule,
                                        LocalDateTime now) {
        final AlertRecord latest = latestRecord(userId, memberId, rule.getId());
        if (latest == null || latest.getCreateTime() == null) {
            return false; // 没有可延续的记录（例如被手工删了）→ 照常新建
        }
        if (Duration.between(latest.getCreateTime(), now).compareTo(cooldownOf(rule)) >= 0) {
            return false; // 冷却窗口已过 → 应当再提醒一次
        }
        latest.setUpdateTime(now);
        alertRecordMapper.updateById(latest);
        log.debug("预警冷却中，不重复新建: 规则「{}」成员 {} 上次 {}",
                rule.getRuleName(), memberId, latest.getCreateTime());
        return true;
    }

    /**
     * 该 (用户, 规则, 成员) 最近一条预警记录。
     * 走复合索引 (user_id, rule_id, create_time)，见 db/schema.sql 与
     * db/migration-alert-dedup.sql。
     */
    private AlertRecord latestRecord(Long userId, Long memberId, Long ruleId) {
        LambdaQueryWrapper<AlertRecord> w = new LambdaQueryWrapper<AlertRecord>()
                .eq(AlertRecord::getUserId, userId)
                .eq(AlertRecord::getRuleId, ruleId);
        if (memberId == null) {
            w.isNull(AlertRecord::getMemberId);
        } else {
            w.eq(AlertRecord::getMemberId, memberId);
        }
        w.orderByDesc(AlertRecord::getCreateTime)
                .orderByDesc(AlertRecord::getId)
                .last("limit 1");
        return alertRecordMapper.selectOne(w);
    }

    private Duration cooldownOf(AlertRule rule) {
        return "danger".equals(rule.getAlertLevel()) ? COOLDOWN_DANGER : COOLDOWN_DEFAULT;
    }

    private void insertRecord(Long userId, Long memberId, AlertRule rule,
                              String dataType, double v, LocalDateTime now) {
        AlertRecord r = new AlertRecord();
        r.setUserId(userId);
        r.setMemberId(memberId);
        r.setRuleId(rule.getId());
        r.setAlertType(rule.getAlertType());
        r.setAlertLevel(rule.getAlertLevel() == null ? "warning" : rule.getAlertLevel());
        r.setTitle(buildTitle(dataType, rule.getAlertLevel()));
        r.setContent(buildContent(rule, dataType, v));
        r.setTriggerValue(String.valueOf(v));
        r.setStatus("unread");
        r.setCreateTime(now);
        r.setUpdateTime(now);
        r.setDeleted(0);
        alertRecordMapper.insert(r);
    }

    private static String stateKey(Long userId, Long memberId, Long ruleId) {
        return userId + "|" + memberId + "|" + ruleId;
    }

    /** 记录本轮状态，并在键过多时清空兜底（清空只会导致多记一条，不会漏报） */
    private static void rememberState(String key, boolean violated) {
        if (LAST_VIOLATED.size() >= LAST_VIOLATED_MAX) {
            LAST_VIOLATED.clear();
            log.warn("预警持续状态缓存超过 {} 条，已清空（下次异常会各多记一条，不会漏报）",
                    LAST_VIOLATED_MAX);
        }
        LAST_VIOLATED.put(key, violated);
    }

    /** 规则类型与数据类型做宽松匹配（规则表的 alertType 取值不统一） */
    private boolean typeMatches(String alertType, String dataType) {
        if (alertType == null || alertType.isEmpty()) {
            return false;
        }
        String a = alertType.replace("_", "").toLowerCase();
        String d = dataType.replace("_", "").toLowerCase();
        if (a.equals(d)) {
            return true;
        }
        // heartRate 对 heart_rate；bloodPressure 对 blood_pressure
        return a.contains(d) || d.contains(a);
    }

    private boolean isViolated(AlertRule rule, double v) {
        final Double t1 = rule.getThreshold1();
        final Double t2 = rule.getThreshold2();
        final String c = rule.getConditionType() == null ? "gt" : rule.getConditionType();
        switch (c) {
            case "gt":
                return t1 != null && v > t1;
            case "lt":
                return t1 != null && v < t1;
            case "eq":
                return t1 != null && Math.abs(v - t1) < 1e-6;
            case "between":
                if (t1 == null || t2 == null) {
                    return false;
                }
                final double lo = Math.min(t1, t2);
                final double hi = Math.max(t1, t2);
                return v < lo || v > hi;
            default:
                return false;
        }
    }

    private String buildTitle(String dataType, String level) {
        String name = switch (dataType) {
            case "heart_rate" -> "心率";
            case "blood_pressure" -> "血压";
            case "blood_sugar" -> "血糖";
            case "temperature" -> "体温";
            default -> "健康指标";
        };
        String lv = "danger".equals(level) ? "严重" : ("info".equals(level) ? "提示" : "异常");
        return name + lv;
    }

    private String buildContent(AlertRule rule, String dataType, double v) {
        String unit = "heart_rate".equals(dataType) ? "bpm" : "";
        String cond = switch (rule.getConditionType() == null ? "gt" : rule.getConditionType()) {
            case "gt" -> "高于 " + rule.getThreshold1();
            case "lt" -> "低于 " + rule.getThreshold1();
            case "eq" -> "等于 " + rule.getThreshold1();
            case "between" -> "超出 " + rule.getThreshold1() + " ~ " + rule.getThreshold2();
            default -> "触发";
        };
        return "检测到数值 " + v + unit + "，" + cond + unit
                + (rule.getRuleName() == null ? "" : "（规则：" + rule.getRuleName() + "）");
    }
}
