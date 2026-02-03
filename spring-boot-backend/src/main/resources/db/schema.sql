-- ============================================================================
-- 家庭健康中心APP - 数据库初始化脚本
-- ============================================================================
-- 创建数据库
CREATE DATABASE IF NOT EXISTS health_center_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE health_center_db;

-- ============================================================================
-- 用户表
-- ============================================================================
CREATE TABLE IF NOT EXISTS `user` (
    `id` BIGINT NOT NULL COMMENT '用户ID',
    `phone` VARCHAR(20) NOT NULL COMMENT '手机号',
    `password` VARCHAR(255) NOT NULL COMMENT '密码（BCrypt加密）',
    `nickname` VARCHAR(50) DEFAULT NULL COMMENT '昵称',
    `avatar` VARCHAR(500) DEFAULT NULL COMMENT '头像URL',
    `gender` VARCHAR(10) DEFAULT NULL COMMENT '性别：male-男，female-女',
    `birthday` DATE DEFAULT NULL COMMENT '生日',
    `status` TINYINT DEFAULT 1 COMMENT '状态：0-禁用，1-正常',
    `last_login_time` DATETIME DEFAULT NULL COMMENT '最后登录时间',
    `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted` TINYINT DEFAULT 0 COMMENT '逻辑删除：0-未删除，1-已删除',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_phone` (`phone`),
    KEY `idx_status` (`status`),
    KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- ============================================================================
-- 家庭成员表
-- ============================================================================
CREATE TABLE IF NOT EXISTS `family_member` (
    `id` BIGINT NOT NULL COMMENT '成员ID',
    `user_id` BIGINT NOT NULL COMMENT '所属用户ID',
    `name` VARCHAR(50) NOT NULL COMMENT '成员姓名',
    `gender` VARCHAR(10) DEFAULT NULL COMMENT '性别：male-男，female-女',
    `birthday` DATE DEFAULT NULL COMMENT '出生日期',
    `relation` VARCHAR(20) DEFAULT NULL COMMENT '关系：father-父亲，mother-母亲，spouse-配偶，child-子女，other-其他',
    `role` VARCHAR(20) DEFAULT 'member' COMMENT '角色：admin-管理员，member-普通成员',
    `avatar` VARCHAR(500) DEFAULT NULL COMMENT '头像URL',
    `sort_order` INT DEFAULT 0 COMMENT '排序序号',
    `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted` TINYINT DEFAULT 0 COMMENT '逻辑删除：0-未删除，1-已删除',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_sort_order` (`sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='家庭成员表';

-- ============================================================================
-- 健康数据表
-- ============================================================================
CREATE TABLE IF NOT EXISTS `health_data` (
    `id` BIGINT NOT NULL COMMENT '数据ID',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `member_id` BIGINT DEFAULT NULL COMMENT '成员ID',
    `data_type` VARCHAR(50) NOT NULL COMMENT '数据类型：blood_pressure-血压，heart_rate-心率，blood_sugar-血糖，temperature-体温，weight-体重，height-身高，steps-步数，sleep-睡眠',
    `value1` DECIMAL(10,2) DEFAULT NULL COMMENT '数值1（收缩压/心率/血糖/体温/体重/身高/步数/睡眠时长）',
    `value2` DECIMAL(10,2) DEFAULT NULL COMMENT '数值2（舒张压）',
    `value3` DECIMAL(10,2) DEFAULT NULL COMMENT '数值3（预留）',
    `unit` VARCHAR(20) DEFAULT NULL COMMENT '单位',
    `measure_time` DATETIME NOT NULL COMMENT '测量时间',
    `data_source` VARCHAR(20) DEFAULT 'manual' COMMENT '数据来源：manual-手动，device-设备，sync-同步',
    `notes` VARCHAR(500) DEFAULT NULL COMMENT '备注',
    `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted` TINYINT DEFAULT 0 COMMENT '逻辑删除：0-未删除，1-已删除',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_member_id` (`member_id`),
    KEY `idx_data_type` (`data_type`),
    KEY `idx_measure_time` (`measure_time`),
    KEY `idx_user_member_type` (`user_id`, `member_id`, `data_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='健康数据表';

-- ============================================================================
-- 预警规则表
-- ============================================================================
CREATE TABLE IF NOT EXISTS `alert_rule` (
    `id` BIGINT NOT NULL COMMENT '规则ID',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `alert_type` VARCHAR(50) NOT NULL COMMENT '预警类型：blood_pressure-血压，heart_rate-心率，blood_sugar-血糖，temperature-体温，weight-体重',
    `alert_level` VARCHAR(20) NOT NULL COMMENT '预警级别：info-信息，warning-警告，danger-危险',
    `condition_type` VARCHAR(20) NOT NULL COMMENT '条件类型：gt-大于，lt-小于，eq-等于，between-区间',
    `threshold1` DOUBLE DEFAULT NULL COMMENT '阈值1（最小值/下限）',
    `threshold2` DOUBLE DEFAULT NULL COMMENT '阈值2（最大值/上限）',
    `rule_name` VARCHAR(100) DEFAULT NULL COMMENT '规则名称',
    `enabled` TINYINT DEFAULT 1 COMMENT '是否启用：0-禁用，1-启用',
    `is_default` TINYINT DEFAULT 0 COMMENT '是否系统默认：0-自定义，1-系统默认',
    `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted` TINYINT DEFAULT 0 COMMENT '逻辑删除：0-未删除，1-已删除',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_alert_type` (`alert_type`),
    KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='预警规则表';

-- ============================================================================
-- 预警记录表
-- ============================================================================
CREATE TABLE IF NOT EXISTS `alert_record` (
    `id` BIGINT NOT NULL COMMENT '记录ID',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `member_id` BIGINT DEFAULT NULL COMMENT '成员ID',
    `rule_id` BIGINT DEFAULT NULL COMMENT '预警规则ID',
    `alert_type` VARCHAR(50) NOT NULL COMMENT '预警类型',
    `alert_level` VARCHAR(20) NOT NULL COMMENT '预警级别',
    `title` VARCHAR(100) DEFAULT NULL COMMENT '预警标题',
    `content` VARCHAR(500) DEFAULT NULL COMMENT '预警内容',
    `trigger_value` VARCHAR(50) DEFAULT NULL COMMENT '触发数值',
    `status` VARCHAR(20) DEFAULT 'unread' COMMENT '状态：unread-未读，read-已读，handled-已处理',
    `handle_time` DATETIME DEFAULT NULL COMMENT '处理时间',
    `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted` TINYINT DEFAULT 0 COMMENT '逻辑删除：0-未删除，1-已删除',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_member_id` (`member_id`),
    KEY `idx_status` (`status`),
    KEY `idx_alert_type` (`alert_type`),
    KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='预警记录表';

-- ============================================================================
-- 健康内容表
-- ============================================================================
CREATE TABLE IF NOT EXISTS `health_content` (
    `id` BIGINT NOT NULL COMMENT '内容ID',
    `category` VARCHAR(50) NOT NULL COMMENT '分类：nutrition-营养，exercise-运动，psychology-心理，disease-疾病',
    `title` VARCHAR(200) NOT NULL COMMENT '标题',
    `summary` VARCHAR(500) DEFAULT NULL COMMENT '摘要',
    `content` TEXT NOT NULL COMMENT '内容（Markdown格式）',
    `cover_image` VARCHAR(500) DEFAULT NULL COMMENT '封面图片URL',
    `tags` VARCHAR(200) DEFAULT NULL COMMENT '标签（逗号分隔）',
    `view_count` INT DEFAULT 0 COMMENT '浏览次数',
    `like_count` INT DEFAULT 0 COMMENT '点赞次数',
    `is_published` TINYINT DEFAULT 1 COMMENT '是否发布：0-草稿，1-已发布',
    `published_at` DATETIME DEFAULT NULL COMMENT '发布时间',
    `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted` TINYINT DEFAULT 0 COMMENT '逻辑删除：0-未删除，1-已删除',
    PRIMARY KEY (`id`),
    KEY `idx_category` (`category`),
    KEY `idx_is_published` (`is_published`),
    KEY `idx_published_at` (`published_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='健康内容表';

-- ============================================================================
-- 测试数据（可选）
-- ============================================================================

-- 插入测试用户（密码：123456）
INSERT INTO `user` (`id`, `phone`, `password`, `nickname`, `gender`, `status`)
VALUES (1, '13800138000', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi', '测试用户', 'male', 1)
ON DUPLICATE KEY UPDATE `phone` = `phone`;

-- 插入测试家庭成员
INSERT INTO `family_member` (`id`, `user_id`, `name`, `gender`, `birthday`, `relation`, `role`, `sort_order`)
VALUES
    (1, 1, '张三', 'male', '1990-01-01', 'other', 'admin', 1),
    (2, 1, '李四', 'female', '1992-05-15', 'spouse', 'member', 2),
    (3, 1, '小明', 'male', '2020-06-01', 'child', 'member', 3)
ON DUPLICATE KEY UPDATE `user_id` = `user_id`;

-- 插入测试健康数据
INSERT INTO `health_data` (`id`, `user_id`, `member_id`, `data_type`, `value1`, `value2`, `unit`, `measure_time`, `data_source`)
VALUES
    (1, 1, 1, 'blood_pressure', 120.0, 80.0, 'mmHg', NOW(), 'manual'),
    (2, 1, 1, 'heart_rate', 75.0, NULL, '次/分', NOW(), 'manual'),
    (3, 1, 1, 'blood_sugar', 5.5, NULL, 'mmol/L', NOW(), 'manual'),
    (4, 1, 1, 'temperature', 36.5, NULL, '℃', NOW(), 'manual'),
    (5, 1, 1, 'weight', 70.0, NULL, 'kg', NOW(), 'manual')
ON DUPLICATE KEY UPDATE `user_id` = `user_id`;
