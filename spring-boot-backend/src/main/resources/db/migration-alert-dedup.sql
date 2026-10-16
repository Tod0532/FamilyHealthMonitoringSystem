-- ============================================================================
--  预警去重（冷却）所需的复合索引 —— 线上已有库的增量变更
--
--  为什么需要：
--    预警评估加入冷却去重后，每次命中都要查
--      SELECT ... FROM alert_record
--       WHERE user_id=? AND rule_id=? [AND member_id=?]
--       ORDER BY create_time DESC, id DESC LIMIT 1
--    alert_record 现有的索引只有单列（user_id / member_id / status /
--    alert_type / create_time），选择性都不够；而这张表会持续增长，
--    不能让这个查询落到全表扫描上。
--
--  ⚠️ 执行顺序：**索引先上，代码后上**。
--     反过来的话，新代码会在没有索引的表上先跑一阵子。
--
--  执行方式：MySQL 8.0 客户端手工执行（本项目未引入 Flyway）。
--    变更前先备份：mysqldump -h <host> -u <user> -p health_center_db alert_record > alert_record.sql
--
--  幂等：MySQL 不支持 CREATE INDEX IF NOT EXISTS，用 information_schema 判一次，
--        重复执行只会打印"已存在，跳过"，不会报错。
-- ============================================================================

SET @idx_exists := (
  SELECT COUNT(*) FROM information_schema.statistics
   WHERE table_schema = DATABASE()
     AND table_name   = 'alert_record'
     AND index_name   = 'idx_user_rule_time'
);

SET @ddl := IF(@idx_exists = 0,
  'ALTER TABLE `alert_record` ADD KEY `idx_user_rule_time` (`user_id`, `rule_id`, `create_time`)',
  'SELECT ''索引 idx_user_rule_time 已存在，跳过'' AS msg'
);

PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 校验：应能看到 idx_user_rule_time，且列顺序为 user_id, rule_id, create_time
-- SHOW INDEX FROM `alert_record` WHERE Key_name = 'idx_user_rule_time';
