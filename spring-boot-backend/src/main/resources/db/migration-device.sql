-- ============================================================================
--  设备接入表（手环心率桥等硬件）
--
--  鉴权模型：App 生成一次性绑定码 → 设备用绑定码换取设备令牌 →
--            令牌只存 SHA-256 哈希，只能写健康数据，App 可随时解绑。
--
--  MySQL 执行；H2(dev) 用同名表的 H2 方言版本写在 schema-h2.sql 里。
-- ============================================================================

CREATE TABLE IF NOT EXISTS `device` (
  `id`                 BIGINT       NOT NULL COMMENT '主键（雪花ID）',
  `user_id`            BIGINT       NOT NULL COMMENT '归属用户',
  `member_id`          BIGINT       NULL     COMMENT '数据归属的家庭成员 family_member.id',
  `device_sn`          VARCHAR(64)  NOT NULL COMMENT '设备序列号（唯一）',
  `device_name`        VARCHAR(64)  NULL     COMMENT '设备显示名',
  `device_type`        VARCHAR(32)  NULL     COMMENT '设备类型，如 esp32_hr_bridge',
  `token_hash`         VARCHAR(128) NULL     COMMENT '设备令牌的 SHA-256（不存明文）',
  `bind_code`          VARCHAR(16)  NULL     COMMENT '一次性绑定码（用后置空）',
  `bind_code_expire`   DATETIME     NULL     COMMENT '绑定码过期时间',
  `last_seen`          DATETIME     NULL     COMMENT '最近一次心跳/上报时间',
  `status`             TINYINT      NOT NULL DEFAULT 1 COMMENT '1 正常 0 已解绑',
  `firmware_version`   VARCHAR(32)  NULL     COMMENT '固件版本',
  `create_time`        DATETIME     NULL     COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_device_sn` (`device_sn`),
  KEY `idx_device_token` (`token_hash`),
  KEY `idx_device_user` (`user_id`, `status`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT ='已接入的硬件设备';

-- health_data 已有 data_source 字段，设备上报时置 'device'，
-- 并把 device_name 写成设备名，便于 App 区分手工录入与自动采集。
-- 如需追溯具体设备，可再加一列（当前用 device_name 已足够区分）：
-- ALTER TABLE `health_data` ADD COLUMN `device_id` BIGINT NULL COMMENT '来源设备id';
