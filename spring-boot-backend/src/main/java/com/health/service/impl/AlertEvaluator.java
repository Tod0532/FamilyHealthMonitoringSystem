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
import java.time.LocalDateTime;
import java.util.List;

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
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AlertEvaluator {

    private final AlertRuleMapper alertRuleMapper;
    private final AlertRecordMapper alertRecordMapper;

    /**
     * 对一条健康数据做规则评估，命中则写预警记录。
     *
     * @param userId   数据归属用户
     * @param memberId 数据归属家庭成员
     * @param dataType health_data 的 data_type，如 heart_rate / blood_pressure
     * @param value1   主数值
     * @return 命中的预警条数
     */
    public int evaluate(Long userId, Long memberId, String dataType, BigDecimal value1) {
        if (userId == null || dataType == null || value1 == null) {
            return 0;
        }
        final double v = value1.doubleValue();

        List<AlertRule> rules = alertRuleMapper.selectList(new LambdaQueryWrapper<AlertRule>()
                .eq(AlertRule::getUserId, userId)
                .eq(AlertRule::getEnabled, 1));
        int hit = 0;
        for (AlertRule rule : rules) {
            if (!typeMatches(rule.getAlertType(), dataType)) {
                continue;
            }
            if (!isViolated(rule, v)) {
                continue;
            }
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
            r.setCreateTime(LocalDateTime.now());
            r.setUpdateTime(LocalDateTime.now());
            r.setDeleted(0);
            alertRecordMapper.insert(r);
            hit++;
            log.info("预警命中: 用户 {} 成员 {} {}={} 规则「{}」级别 {}",
                    userId, memberId, dataType, v, rule.getRuleName(), rule.getAlertLevel());
        }
        return hit;
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
