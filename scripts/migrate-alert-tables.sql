-- ============================================================================
-- 修复预警模块：alert_rule / alert_record 表结构与实体不一致
-- ============================================================================
-- 背景
--   线上日志持续报错，导致预警模块 8 个接口全部 500：
--     SQLSyntaxErrorException: Unknown column 'alert_type' in 'field list'
--     SQLSyntaxErrorException: Unknown column 'deleted'    in 'where clause'
--     SQLSyntaxErrorException: Unknown column 'title'      in 'field list'
--
--   实测比对（生产库实际列 vs 代码实体所需列）：
--     alert_rule   缺 9 列：alert_type, threshold1, threshold2, rule_name,
--                          enabled, is_default, create_time, update_time, deleted
--     alert_record 缺 8 列：title, content, trigger_value, status,
--                          handle_time, create_time, update_time, deleted
--
--   其中 deleted 是 MyBatis-Plus 的 @TableLogic 逻辑删除列，缺失会导致
--   该表**每一条**查询的 WHERE 都追加 deleted=0 而直接报错。
--
-- 说明
--   * 采用「补列」而非重建表 —— 不丢数据，且保留原有列（如 data_type、
--     threshold_value、is_read 等历史字段，仅作废不再使用）。
--   * 迁移前自动备份两张表（CREATE TABLE ... LIKE + INSERT SELECT）。
--   * 幂等：可重复执行，已存在的列会跳过。
--   * 执行前请确认两表行数（见脚本末尾的核对查询）。
-- ============================================================================

USE health_center_db;

-- ---------------------------------------------------------------------------
-- 0) 备份（保留历史列与数据）
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `alert_rule_bak_20260928`;
DROP TABLE IF EXISTS `alert_record_bak_20260928`;
CREATE TABLE `alert_rule_bak_20260928`   LIKE `alert_rule`;
INSERT INTO `alert_rule_bak_20260928`   SELECT * FROM `alert_rule`;
CREATE TABLE `alert_record_bak_20260928` LIKE `alert_record`;
INSERT INTO `alert_record_bak_20260928` SELECT * FROM `alert_record`;

-- ---------------------------------------------------------------------------
-- 1) alert_rule 补齐实体所需列
-- ---------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `add_col_if_absent`;
DELIMITER $$
CREATE PROCEDURE `add_col_if_absent`(
    IN p_table VARCHAR(64), IN p_col VARCHAR(64), IN p_ddl TEXT)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_table AND COLUMN_NAME = p_col
    ) THEN
        SET @s = CONCAT('ALTER TABLE `', p_table, '` ADD COLUMN `', p_col, '` ', p_ddl);
        PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
    END IF;
END$$
DELIMITER ;

-- alert_rule：实体字段 alertType / alertLevel / conditionType / threshold1 / threshold2
--             / ruleName / enabled / isDefault / createTime / updateTime / deleted
CALL add_col_if_absent('alert_rule', 'alert_type',
     "VARCHAR(50) NOT NULL DEFAULT 'blood_pressure' COMMENT '预警类型（与原有 data_type 同义）'");
CALL add_col_if_absent('alert_rule', 'threshold1',
     "DOUBLE DEFAULT NULL COMMENT '阈值1（原 threshold_value）'");
CALL add_col_if_absent('alert_rule', 'threshold2',
     "DOUBLE DEFAULT NULL COMMENT '阈值2（区间比较时的上界）'");
CALL add_col_if_absent('alert_rule', 'rule_name',
     "VARCHAR(100) DEFAULT NULL COMMENT '规则名称'");
CALL add_col_if_absent('alert_rule', 'enabled',
     "TINYINT DEFAULT 1 COMMENT '是否启用（原 is_enabled）'");
CALL add_col_if_absent('alert_rule', 'is_default',
     "TINYINT DEFAULT 0 COMMENT '是否系统默认规则'");
CALL add_col_if_absent('alert_rule', 'create_time',
     "DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间（原 created_at）'");
CALL add_col_if_absent('alert_rule', 'update_time',
     "DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'");
CALL add_col_if_absent('alert_rule', 'deleted',
     "TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0-未删除，1-已删除'");

-- alert_record：实体字段 title / content / triggerValue / status
--               / handleTime / createTime / updateTime / deleted
CALL add_col_if_absent('alert_record', 'title',
     "VARCHAR(100) DEFAULT NULL COMMENT '预警标题'");
CALL add_col_if_absent('alert_record', 'content',
     "VARCHAR(500) DEFAULT NULL COMMENT '预警内容'");
CALL add_col_if_absent('alert_record', 'trigger_value',
     "VARCHAR(50) DEFAULT NULL COMMENT '触发值（原 data_value）'");
CALL add_col_if_absent('alert_record', 'status',
     "VARCHAR(20) DEFAULT 'unread' COMMENT '处理状态：unread/read/handled'");
CALL add_col_if_absent('alert_record', 'handle_time',
     "DATETIME DEFAULT NULL COMMENT '处理时间'");
CALL add_col_if_absent('alert_record', 'create_time',
     "DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间（原 created_at）'");
CALL add_col_if_absent('alert_record', 'update_time',
     "DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'");
CALL add_col_if_absent('alert_record', 'deleted',
     "TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除：0-未删除，1-已删除'");

DROP PROCEDURE IF EXISTS `add_col_if_absent`;

-- ---------------------------------------------------------------------------
-- 2) 把历史列的数据搬到新列（表为空时无实际影响，但保证幂等可重跑）
-- ---------------------------------------------------------------------------
UPDATE `alert_rule`
   SET alert_type = data_type
 WHERE (alert_type IS NULL OR alert_type = '')
   AND data_type IS NOT NULL;

UPDATE `alert_rule`
   SET threshold1 = threshold_value
 WHERE threshold1 IS NULL
   AND threshold_value IS NOT NULL;

UPDATE `alert_rule`
   SET enabled = is_enabled
 WHERE enabled IS NULL
   AND is_enabled IS NOT NULL;

UPDATE `alert_rule`
   SET create_time = created_at
 WHERE create_time IS NULL
   AND created_at IS NOT NULL;

UPDATE `alert_record`
   SET trigger_value = CAST(data_value AS CHAR)
 WHERE trigger_value IS NULL
   AND data_value IS NOT NULL;

UPDATE `alert_record`
   SET status = CASE
         WHEN is_processed = 1 THEN 'handled'
         WHEN is_read = 1 THEN 'read'
         ELSE 'unread'
       END
 WHERE status IS NULL OR status = '';

UPDATE `alert_record`
   SET create_time = created_at
 WHERE create_time IS NULL
   AND created_at IS NOT NULL;

-- 兜底：把逻辑删除列可能的 NULL 归一为 0，避免 @TableLogic 生成的
-- 「WHERE deleted=0」查不到历史行
UPDATE `alert_rule`   SET deleted = 0 WHERE deleted IS NULL;
UPDATE `alert_record` SET deleted = 0 WHERE deleted IS NULL;

-- ---------------------------------------------------------------------------
-- 3) 索引（便于按用户/类型/时间检索）
--    注意：必须幂等。MySQL 客户端执行脚本时遇到错误会中止，若直接在重跑时
--    报 "Duplicate key name"，后续的核对查询就不会执行 —— 预演已验证过这个坑。
--    这里复用同一套「存在则跳过」的过程式做法。
-- ---------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `add_idx_if_absent`;
DELIMITER $$
CREATE PROCEDURE `add_idx_if_absent`(
    IN p_table VARCHAR(64), IN p_idx VARCHAR(64), IN p_cols TEXT)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_table AND INDEX_NAME = p_idx
    ) THEN
        SET @s = CONCAT('ALTER TABLE `', p_table, '` ADD INDEX `', p_idx, '` (', p_cols, ')');
        PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
    END IF;
END$$
DELIMITER ;

CALL add_idx_if_absent('alert_rule',   'idx_alert_rule_user_type',      '`user_id`, `alert_type`');
CALL add_idx_if_absent('alert_record', 'idx_alert_record_user_status',  '`user_id`, `status`');
CALL add_idx_if_absent('alert_record', 'idx_alert_record_create_time',  '`create_time`');

DROP PROCEDURE IF EXISTS `add_idx_if_absent`;

-- ---------------------------------------------------------------------------
-- 4) 核对结果
-- ---------------------------------------------------------------------------
SELECT '=== alert_rule 最终列 ===' AS info;
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'alert_rule'
ORDER BY ORDINAL_POSITION;

SELECT '=== alert_record 最终列 ===' AS info;
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'alert_record'
ORDER BY ORDINAL_POSITION;

SELECT '=== 备份行数（应与原表一致）===' AS info;
SELECT (SELECT COUNT(*) FROM alert_rule_bak_20260928)   AS alert_rule_backup_rows,
       (SELECT COUNT(*) FROM alert_record_bak_20260928) AS alert_record_backup_rows,
       (SELECT COUNT(*) FROM alert_rule)                AS alert_rule_now,
       (SELECT COUNT(*) FROM alert_record)              AS alert_record_now;
