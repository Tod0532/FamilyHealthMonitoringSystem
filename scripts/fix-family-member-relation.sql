-- ============================================================================
-- 预防性修复：family_member.relation 与 alert_rule.data_type 属同类隐患
-- ============================================================================
-- family_member.relation 是 VARCHAR(20) NOT NULL 且无默认值。
-- 一旦有代码路径新增成员时未显式写 relation（历史数据/其它客户端/未来重构
-- 都可能发生），MySQL 会直接报：
--     Field 'relation' doesn't have a default value
-- 而 alert_rule.data_type 已经因为同一模式导致线上新增规则恒 500。
-- 这里把它改为可空（不删列、不改数据，可逆），应用层仍会写 'other' 兜底。
-- ============================================================================

ALTER TABLE family_member MODIFY COLUMN relation VARCHAR(20) NULL DEFAULT 'other';

-- 校验
SELECT TABLE_NAME, COLUMN_NAME, IS_NULLABLE, IFNULL(COLUMN_DEFAULT, '<<NULL>>') AS DEF
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'health_center_db'
  AND COLUMN_NAME = 'relation'
  AND TABLE_NAME IN ('family_member', 'family_member_bak_20260928b')
ORDER BY TABLE_NAME;
