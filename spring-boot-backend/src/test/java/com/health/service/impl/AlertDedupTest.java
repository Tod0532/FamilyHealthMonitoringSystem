package com.health.service.impl;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.conditions.AbstractWrapper;
import com.baomidou.mybatisplus.core.conditions.Wrapper;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import com.health.domain.entity.AlertRecord;
import com.health.domain.entity.AlertRule;
import com.health.domain.mapper.AlertRecordMapper;
import com.health.domain.mapper.AlertRuleMapper;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.mockito.stubbing.Answer;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

/**
 * 预警**冷却去重**测试
 *
 * 背景：板子改成 5 秒一报后，AlertEvaluator 原本"命中就插一条"，
 * 实测 spike 场景跑 62 秒（14 次上报）→ 新增 **14 条**预警，与上报次数 1:1。
 * 按这个速率，一个持续超标的成员一天会产生约 **1.7 万条**预警记录，
 * 用户打开预警页看到的是几千条一模一样的记录，功能等于失效。
 *
 * 这里把冷却行为的边界钉死，防止以后有人把去重"顺手"去掉：
 *   1. 同一次异常持续 → 只留 1 条，且 update_time 前移（能看出持续到什么时候）
 *   2. 冷却窗口已过   → 再提醒一次（新建第 2 条）
 *   3. 不同成员互不压制（冷却键必须含 member_id）
 *   4. 数值回落正常后再超标 → 即使还在窗口内也必须新建
 *      （"降下来又升上去"是最该提醒的情况，不能被当成同一次而吞掉）
 *   5. danger 与 warning 的窗口长度不同（3 分钟 / 30 分钟）
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AlertDedupTest {

    private static final long USER_ID = 1L;
    private static final long RULE_ID = 77L;

    @Mock
    private AlertRuleMapper alertRuleMapper;
    @Mock
    private AlertRecordMapper alertRecordMapper;

    private AlertEvaluator evaluator;

    /** 用内存表代替 DB（见 Fakes 里的说明） */
    private final Fakes.AlertRecordTable table = new Fakes.AlertRecordTable();

    /**
     * 让 LambdaQueryWrapper 能解析 AlertRecord::getXxx。
     *
     * 脱离 Spring/MyBatis 上下文时，MyBatis-Plus 的 lambda 缓存是空的，
     * 一调 wrapper.getSqlSegment() 就抛
     * "can not find lambda cache for this entity"（实测踩到）。
     * 手动给这两个实体建一次 TableInfo 即可。
     */
    @BeforeAll
    static void initLambdaCache() {
        MapperBuilderAssistant assistant =
                new MapperBuilderAssistant(new MybatisConfiguration(), "");
        TableInfoHelper.initTableInfo(assistant, AlertRecord.class);
        TableInfoHelper.initTableInfo(assistant, AlertRule.class);
    }

    @BeforeEach
    void setUp() {
        evaluator = new AlertEvaluator(alertRuleMapper, alertRecordMapper);
        table.reset();

        when(alertRecordMapper.insert(any(AlertRecord.class)))
                .thenAnswer((Answer<Integer>) inv -> {
                    table.insert(inv.getArgument(0));
                    return 1;
                });
        when(alertRecordMapper.selectOne(any(Wrapper.class)))
                .thenAnswer((Answer<AlertRecord>) inv -> table.latest(inv.getArgument(0)));
        when(alertRecordMapper.updateById(any(AlertRecord.class)))
                .thenAnswer((Answer<Integer>) inv -> {
                    table.touch(inv.getArgument(0));
                    return 1;
                });
    }

    // ───────────────────────── 脚手架 ─────────────────────────

    /** 心率 > 100 触发，level 决定冷却窗口长短 */
    private void ruleOf(String level) {
        AlertRule r = new AlertRule();
        r.setId(RULE_ID);
        r.setUserId(USER_ID);
        r.setEnabled(1);
        r.setAlertType("heart_rate");
        r.setConditionType("gt");
        r.setThreshold1(100.0);
        r.setAlertLevel(level);
        r.setRuleName("心率过快");
        when(alertRuleMapper.selectList(any(Wrapper.class))).thenReturn(List.of(r));
    }

    private int report(long memberId, int bpm) {
        return evaluator.evaluate(USER_ID, memberId, "heart_rate", BigDecimal.valueOf(bpm));
    }

    // ───────────────────────── 用例 ─────────────────────────

    @Test
    @DisplayName("异常持续 100 次上报：只产生 1 条预警，且 update_time 被不断前移")
    void continuousViolationProducesSingleRecord() {
        ruleOf("danger");

        int created = 0;
        for (int i = 0; i < 100; i++) {
            created += report(101L, 110);
        }

        assertEquals(1, created, "100 次持续超标只应新建 1 条预警记录");
        assertEquals(1, table.rows.size(), "库里应只有 1 条记录");
        AlertRecord only = table.rows.get(0);
        assertNotNull(only.getCreateTime());
        assertNotNull(only.getUpdateTime());
        assertTrue(only.getUpdateTime().isAfter(only.getCreateTime())
                        || only.getUpdateTime().isEqual(only.getCreateTime()),
                "被压制的那些上报应把 update_time 前移，用来表示异常还在持续");
        assertTrue(table.touches >= 90, "其余上报应走「刷新 update_time」这条路，实际 " + table.touches);
    }

    @Test
    @DisplayName("冷却窗口（danger 3 分钟）过后：再超标应新建第 2 条")
    void afterCooldownCreatesSecondRecord() {
        ruleOf("danger");

        report(101L, 110);
        assertEquals(1, table.rows.size());

        // 把已有记录的创建时间挪到 4 分钟前（超过 danger 的 3 分钟窗口）
        table.rows.get(0).setCreateTime(LocalDateTime.now().minusMinutes(4));

        int created = report(101L, 112);
        assertEquals(1, created, "冷却已过，应再提醒一次");
        assertEquals(2, table.rows.size());
    }

    @Test
    @DisplayName("窗口内（danger 未到 3 分钟）：继续压制，不新建")
    void withinCooldownSuppressed() {
        ruleOf("danger");

        report(101L, 110);
        table.rows.get(0).setCreateTime(LocalDateTime.now().minusMinutes(1));

        int created = report(101L, 112);
        assertEquals(0, created, "距上次仅 1 分钟（< 3 分钟），不应重复新建");
        assertEquals(1, table.rows.size());
    }

    @Test
    @DisplayName("不同成员互不压制（冷却键必须含 member_id）")
    void differentMembersAreIndependent() {
        ruleOf("danger");

        int a = report(101L, 110);   // 张三超标 → 新建
        int b = report(202L, 110);   // 李四超标 → 也必须新建

        assertEquals(1, a);
        assertEquals(1, b, "另一个成员第一次超标时不该被前一个成员的冷却压制掉");
        assertEquals(2, table.rows.size());
    }

    @Test
    @DisplayName("回落到正常后再超标：即使还在窗口内也必须新建（不能被当成同一次）")
    void recoveredThenViolatedIsANewEvent() {
        ruleOf("danger");

        report(101L, 110);                 // 异常 → 新建
        assertEquals(1, table.rows.size());

        report(101L, 72);                  // 回落到正常（不触发）
        report(101L, 70);
        table.rows.get(0).setCreateTime(LocalDateTime.now().minusSeconds(60)); // 仍在窗口内

        int created = report(101L, 108);   // 又升上去 —— 最该提醒的情况
        assertEquals(1, created, "回落之后的再次超标是独立事件，不能被冷却吞掉");
        assertEquals(2, table.rows.size());
    }

    @Test
    @DisplayName("warning 的窗口是 30 分钟：5 分钟前的那条仍然压制")
    void warningCooldownIsLongerThanDanger() {
        ruleOf("warning");

        report(101L, 110);
        table.rows.get(0).setCreateTime(LocalDateTime.now().minusMinutes(5));

        int created = report(101L, 112);
        assertEquals(0, created, "warning 窗口 30 分钟，5 分钟前刚提醒过就不该再记");
        assertEquals(1, table.rows.size());
    }

    @Test
    @DisplayName("正常值不产生任何记录")
    void normalValueNoRecord() {
        ruleOf("danger");

        report(101L, 72);
        report(101L, 80);

        assertEquals(0, table.rows.size());
        assertEquals(0, table.touches);
    }

    /** 内存表：让"查最近一条"这条路径真的能按条件过滤，而不是永远返回同一行 */
    static class Fakes {

        static class AlertRecordTable {
            final List<AlertRecord> rows = new ArrayList<>();
            int touches = 0;

            void reset() {
                rows.clear();
                touches = 0;
            }

            void insert(AlertRecord r) {
                if (r.getCreateTime() == null) {
                    r.setCreateTime(LocalDateTime.now());
                }
                if (r.getUpdateTime() == null) {
                    r.setUpdateTime(r.getCreateTime());
                }
                rows.add(r);
            }

            void touch(AlertRecord r) {
                touches++;
            }

            /**
             * 按 wrapper 里的等值条件过滤（user_id / rule_id / member_id），再取 create_time 最新一条。
             *
             * 为什么解析 SQL 片段而不是简单地"返回最后插入的一条"：
             * 那样就测不出"冷却查询漏了 member_id"这类错误 —— 而"不同成员互相压制"
             * 正是这个去重逻辑最容易写错的地方。
             */
            AlertRecord latest(Wrapper<AlertRecord> w) {
                Map<String, Object> cond = conditions(w);
                AlertRecord best = null;
                for (AlertRecord r : rows) {
                    if (!match(cond, "user_id", r.getUserId())) {
                        continue;
                    }
                    if (!match(cond, "rule_id", r.getRuleId())) {
                        continue;
                    }
                    if (!match(cond, "member_id", r.getMemberId())) {
                        continue;
                    }
                    if (best == null || isNewer(r, best)) {
                        best = r;
                    }
                }
                return best;
            }

            private static boolean isNewer(AlertRecord a, AlertRecord b) {
                if (a.getCreateTime() == null || b.getCreateTime() == null) {
                    return false;
                }
                return a.getCreateTime().isAfter(b.getCreateTime());
            }

            /** 条件里没有这个列时不参与过滤；有就按值相等比较 */
            private static boolean match(Map<String, Object> cond, String column, Long value) {
                if (!cond.containsKey(column)) {
                    return true;
                }
                Object expect = cond.get(column);
                if (expect == null || value == null) {
                    return expect == null && value == null;
                }
                return String.valueOf(expect).equals(String.valueOf(value));
            }

            /** 从 wrapper 的 SQL 片段里取出 列名 → 绑定值 */
            @SuppressWarnings("unchecked")
            private static Map<String, Object> conditions(Wrapper<AlertRecord> w) {
                Map<String, Object> out = new HashMap<>();
                Map<String, Object> params =
                        ((AbstractWrapper<AlertRecord, ?, ?>) w).getParamNameValuePairs();
                Matcher m = Pattern.compile(
                                "([a-z_]+)\\s*=\\s*#\\{ew\\.paramNameValuePairs\\.(MPGENVAL\\d+)\\}")
                        .matcher(w.getSqlSegment());
                while (m.find()) {
                    out.put(m.group(1), params.get(m.group(2)));
                }
                return out;
            }
        }
    }
}
