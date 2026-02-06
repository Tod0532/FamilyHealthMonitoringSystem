-- ============================================================================
-- 家庭功能 - 数据库迁移脚本
-- ============================================================================

USE health_center_db;

-- ============================================================================
-- 1. 新增家庭表
-- ============================================================================
CREATE TABLE IF NOT EXISTS `family` (
    `id` BIGINT NOT NULL COMMENT '家庭ID',
    `family_name` VARCHAR(100) NOT NULL COMMENT '家庭名称',
    `family_code` VARCHAR(20) NOT NULL COMMENT '家庭邀请码（6位）',
    `admin_id` BIGINT NOT NULL COMMENT '管理员用户ID',
    `member_count` INT DEFAULT 1 COMMENT '成员数量',
    `status` TINYINT DEFAULT 1 COMMENT '状态：0-禁用，1-正常',
    `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted` TINYINT DEFAULT 0 COMMENT '逻辑删除：0-未删除，1-已删除',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_family_code` (`family_code`),
    KEY `idx_admin_id` (`admin_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='家庭表';

-- ============================================================================
-- 2. 修改用户表 - 添加家庭相关字段
-- ============================================================================
ALTER TABLE `sys_user`
ADD COLUMN `family_id` BIGINT DEFAULT NULL COMMENT '所属家庭ID' AFTER `role`,
ADD COLUMN `family_role` VARCHAR(20) DEFAULT 'member' COMMENT '家庭角色：admin-管理员，member-普通成员' AFTER `family_id`,
ADD INDEX `idx_family_id` (`family_id`);

-- ============================================================================
-- 3. 修改家庭成员表 - 添加family_id字段
-- ============================================================================
ALTER TABLE `family_member`
ADD COLUMN `family_id` BIGINT DEFAULT NULL COMMENT '所属家庭ID' AFTER `user_id`,
ADD INDEX `idx_family_id` (`family_id`);

-- ============================================================================
-- 4. 修改健康数据表 - 添加family_id字段
-- ============================================================================
ALTER TABLE `health_data`
ADD COLUMN `family_id` BIGINT DEFAULT NULL COMMENT '所属家庭ID' AFTER `user_id`,
ADD INDEX `idx_family_id` (`family_id`);
