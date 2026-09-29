-- ============================================================================
-- 修复：alert_rule.data_type 导致线上新增预警规则恒失败（HTTP 500）
-- ============================================================================
-- 背景
--   线上 MySQL 的 alert_rule 表仍保留早期列 data_type（VARCHAR(20), NOT NULL,
--   无默认值），而当前实体 AlertRule 与接口 AlertRuleRequest 已改用 alert_type，
--   INSERT 不会再写 data_type。MySQL 对「NOT NULL 且无默认值」的列在未赋值时
--   直接报错，于是每次新增规则都失败：
--
--     INSERT INTO alert_rule (id, user_id, alert_type, alert_level, condition_type,
--                             threshold1, threshold2, rule_name, enabled, is_default,
--                             create_time, update_time) VALUES (...)
--     java.sql.SQLException: Field 'data_type' doesn't have a default value
--
--   这也是线上 alert_rule 表长期为空、预警功能不可用的直接原因之一。
--
-- 处理
--   该列已无任何业务用途，这里只把它改为可空（不删列、不改动数据，可逆）。
--   如需彻底清理，可另行评估后 DROP COLUMN，但需先确认没有历史脚本读取它。
--
-- 执行记录
--   2026-09-29 已在生产库 health_center_db 执行；
--   执行后线上新增/更新/启用/删除预警规则全部返回 200 并正确落库。
-- ============================================================================

ALTER TABLE alert_rule MODIFY COLUMN data_type VARCHAR(20) NULL DEFAULT NULL;

-- 校验
SELECT COLUMN_NAME, IS_NULLABLE, IFNULL(COLUMN_DEFAULT, '<<NULL>>') AS DEF
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'health_center_db'
  AND TABLE_NAME = 'alert_rule'
  AND COLUMN_NAME = 'data_type';
