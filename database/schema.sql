-- ============================================================================
-- 家庭健康中心APP - 数据库建表脚本
-- ============================================================================
-- 数据库: health_center_db
-- 版本: 1.0.0
-- 创建时间: 2026-01-29
-- 字符集: utf8mb4
-- 存储引擎: InnoDB
-- ============================================================================

-- 创建数据库
CREATE DATABASE IF NOT EXISTS `health_center_db` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE `health_center_db`;

-- ============================================================================
-- 1. 用户表 (user)
-- ============================================================================
-- 存储APP注册用户信息，支持手机号登录
-- ============================================================================
DROP TABLE IF EXISTS `user`;
CREATE TABLE `user` (
    `id` BIGINT NOT NULL COMMENT '主键ID（雪花算法）',
    `phone` VARCHAR(20) NOT NULL COMMENT '手机号（登录账号）',
    `password` VARCHAR(255) NOT NULL COMMENT '密码（BCrypt加密）',
    `nickname` VARCHAR(50) DEFAULT NULL COMMENT '昵称',
    `avatar` VARCHAR(500) DEFAULT NULL COMMENT '头像URL',
    `role` VARCHAR(20) NOT NULL DEFAULT 'USER' COMMENT '角色：ADMIN-管理员, USER-普通用户, GUEST-访客',
    `status` VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '账号状态：ACTIVE-启用, DISABLED-禁用',
    `last_login_time` DATETIME DEFAULT NULL COMMENT '最后登录时间',
    `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `is_deleted` TINYINT NOT NULL DEFAULT 0 COMMENT '删除标记：0-未删除, 1-已删除',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_phone` (`phone`),
    KEY `idx_status` (`status`),
    KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- ============================================================================
-- 2. 家庭表 (family)
-- ============================================================================
-- 存储家庭基础信息，一个用户可创建多个家庭
-- ============================================================================
DROP TABLE IF EXISTS `family`;
CREATE TABLE `family` (
    `id` BIGINT NOT NULL COMMENT '主键ID',
    `name` VARCHAR(100) NOT NULL COMMENT '家庭名称',
    `admin_id` BIGINT NOT NULL COMMENT '管理员用户ID',
    `avatar` VARCHAR(500) DEFAULT NULL COMMENT '家庭头像URL',
    `health_score` INT NOT NULL DEFAULT 0 COMMENT '家庭健康评分（0-100）',
    `is_default` BOOLEAN NOT NULL DEFAULT FALSE COMMENT '是否默认家庭',
    `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `is_deleted` TINYINT NOT NULL DEFAULT 0 COMMENT '删除标记',
    PRIMARY KEY (`id`),
    KEY `idx_admin_id` (`admin_id`),
    KEY `idx_health_score` (`health_score`),
    CONSTRAINT `fk_family_admin` FOREIGN KEY (`admin_id`) REFERENCES `user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='家庭表';

-- ============================================================================
-- 3. 家庭成员表 (family_member)
-- ============================================================================
-- 存储家庭成员详情，非注册用户也可被添加
-- ============================================================================
DROP TABLE IF EXISTS `family_member`;
CREATE TABLE `family_member` (
    `id` BIGINT NOT NULL COMMENT '主键ID',
    `family_id` BIGINT NOT NULL COMMENT '家庭ID',
    `user_id` BIGINT DEFAULT NULL COMMENT '关联用户ID（可选，非注册用户为NULL）',
    `name` VARCHAR(50) NOT NULL COMMENT '成员姓名',
    `age` INT DEFAULT NULL COMMENT '年龄',
    `gender` VARCHAR(10) DEFAULT NULL COMMENT '性别：MALE-男, FEMALE-女',
    `relationship` VARCHAR(50) NOT NULL COMMENT '关系：本人、父母、子女、配偶等',
    `medical_history` TEXT DEFAULT NULL COMMENT '基础病史（AES加密存储）',
    `allergies` TEXT DEFAULT NULL COMMENT '过敏史（AES加密存储）',
    `blood_type` VARCHAR(10) DEFAULT NULL COMMENT '血型：A、B、AB、O',
    `height` DECIMAL(5,2) DEFAULT NULL COMMENT '身高（cm）',
    `weight` DECIMAL(5,2) DEFAULT NULL COMMENT '体重（kg）',
    `avatar` VARCHAR(500) DEFAULT NULL COMMENT '头像URL',
    `creator_id` BIGINT NOT NULL COMMENT '创建人ID',
    `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `is_deleted` TINYINT NOT NULL DEFAULT 0 COMMENT '删除标记',
    PRIMARY KEY (`id`),
    KEY `idx_family_id` (`family_id`),
    KEY `idx_user_id` (`user_id`),
    CONSTRAINT `fk_member_family` FOREIGN KEY (`family_id`) REFERENCES `family` (`id`),
    CONSTRAINT `fk_member_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='家庭成员表';

-- ============================================================================
-- 4. 健康数据表 (health_data)
-- ============================================================================
-- 存储所有家庭成员的健康指标数据，按月分表
-- ============================================================================
DROP TABLE IF EXISTS `health_data`;
CREATE TABLE `health_data` (
    `id` BIGINT NOT NULL COMMENT '主键ID',
    `member_id` BIGINT NOT NULL COMMENT '成员ID',
    `metric_type` VARCHAR(20) NOT NULL COMMENT '指标类型：BP_SYS-收缩压, BP_DIA-舒张压, BG_FASTING-空腹血糖等',
    `metric_value` VARCHAR(50) NOT NULL COMMENT '指标值',
    `unit` VARCHAR(20) DEFAULT NULL COMMENT '单位',
    `record_time` DATETIME NOT NULL COMMENT '记录时间',
    `input_method` VARCHAR(20) NOT NULL DEFAULT 'MANUAL' COMMENT '录入方式：MANUAL-手动, DEVICE-设备',
    `device_id` VARCHAR(100) DEFAULT NULL COMMENT '设备ID',
    `extra_data` JSON DEFAULT NULL COMMENT '额外数据（如血压舒张压、心率等关联数据）',
    `input_user_id` BIGINT NOT NULL COMMENT '录入人ID',
    `is_synced` BOOLEAN NOT NULL DEFAULT TRUE COMMENT '是否已同步（离线标记）',
    `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    KEY `idx_member_record_time` (`member_id`, `record_time` DESC),
    KEY `idx_metric_type` (`metric_type`),
    KEY `idx_record_time` (`record_time`),
    CONSTRAINT `fk_health_data_member` FOREIGN KEY (`member_id`) REFERENCES `family_member` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='健康数据表';

-- ============================================================================
-- 5. 预警规则表 (warning_rule)
-- ============================================================================
-- 存储各成员各指标的预警规则配置
-- ============================================================================
DROP TABLE IF EXISTS `warning_rule`;
CREATE TABLE `warning_rule` (
    `id` BIGINT NOT NULL COMMENT '主键ID',
    `member_id` BIGINT DEFAULT NULL COMMENT '成员ID（NULL表示系统默认模板规则）',
    `metric_type` VARCHAR(20) NOT NULL COMMENT '指标类型',
    `threshold_min` DECIMAL(10,2) DEFAULT NULL COMMENT '阈值下限',
    `threshold_max` DECIMAL(10,2) DEFAULT NULL COMMENT '阈值上限',
    `compare_type` VARCHAR(10) NOT NULL DEFAULT 'BETWEEN' COMMENT '比较类型：BETWEEN-之间, GT-大于, LT-小于',
    `is_custom` BOOLEAN NOT NULL DEFAULT FALSE COMMENT '是否自定义规则',
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE COMMENT '是否生效',
    `continuous_count` INT NOT NULL DEFAULT 1 COMMENT '连续异常次数触发',
    `creator_id` BIGINT NOT NULL COMMENT '创建人ID',
    `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_member_metric` (`member_id`, `metric_type`),
    KEY `idx_is_active` (`is_active`),
    CONSTRAINT `fk_warning_rule_member` FOREIGN KEY (`member_id`) REFERENCES `family_member` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='预警规则表';

-- ============================================================================
-- 6. 预警记录表 (warning_record)
-- ============================================================================
-- 存储历史预警信息，跟踪处理状态
-- ============================================================================
DROP TABLE IF EXISTS `warning_record`;
CREATE TABLE `warning_record` (
    `id` BIGINT NOT NULL COMMENT '主键ID',
    `member_id` BIGINT NOT NULL COMMENT '成员ID',
    `family_id` BIGINT NOT NULL COMMENT '家庭ID',
    `rule_id` BIGINT DEFAULT NULL COMMENT '规则ID',
    `metric_type` VARCHAR(20) NOT NULL COMMENT '指标类型',
    `abnormal_value` VARCHAR(50) NOT NULL COMMENT '异常值',
    `warning_level` VARCHAR(20) NOT NULL DEFAULT 'NORMAL' COMMENT '预警级别：LOW-低, MEDIUM-中, HIGH-高, URGENT-紧急',
    `warning_time` DATETIME NOT NULL COMMENT '预警时间',
    `status` VARCHAR(20) NOT NULL DEFAULT 'PENDING' COMMENT '处理状态：PENDING-未处理, VIEWED-已查看, HANDLED-已处理, MEDICAL-已就医',
    `receivers` JSON DEFAULT NULL COMMENT '接收人ID列表',
    `push_methods` JSON DEFAULT NULL COMMENT '推送方式列表',
    `remark` TEXT DEFAULT NULL COMMENT '备注',
    `handler_id` BIGINT DEFAULT NULL COMMENT '处理人ID',
    `handled_time` DATETIME DEFAULT NULL COMMENT '处理时间',
    `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    KEY `idx_status_warning_time` (`status`, `warning_time` DESC),
    KEY `idx_member_id` (`member_id`),
    KEY `idx_family_id` (`family_id`),
    CONSTRAINT `fk_warning_record_member` FOREIGN KEY (`member_id`) REFERENCES `family_member` (`id`),
    CONSTRAINT `fk_warning_record_family` FOREIGN KEY (`family_id`) REFERENCES `family` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='预警记录表';

-- ============================================================================
-- 7. 健康内容表 (health_content)
-- ============================================================================
-- 存储健康活动、食谱等内容
-- ============================================================================
DROP TABLE IF EXISTS `health_content`;
CREATE TABLE `health_content` (
    `id` BIGINT NOT NULL COMMENT '主键ID',
    `content_type` VARCHAR(20) NOT NULL COMMENT '内容类型：ACTIVITY-活动, RECIPE-食谱',
    `title` VARCHAR(200) NOT NULL COMMENT '标题',
    `summary` VARCHAR(500) DEFAULT NULL COMMENT '摘要',
    `content` TEXT NOT NULL COMMENT '详情内容',
    `cover_image` VARCHAR(500) DEFAULT NULL COMMENT '封面图URL',
    `tags` JSON DEFAULT NULL COMMENT '标签数组',
    `target_audience` JSON DEFAULT NULL COMMENT '适应人群',
    `difficulty` VARCHAR(20) DEFAULT NULL COMMENT '难度（仅活动）',
    `duration` INT DEFAULT NULL COMMENT '时长（分钟，仅活动）',
    `calories` INT DEFAULT NULL COMMENT '热量（kcal，仅食谱）',
    `nutrition` JSON DEFAULT NULL COMMENT '营养成分',
    `ingredients` JSON DEFAULT NULL COMMENT '食材清单',
    `steps` JSON DEFAULT NULL COMMENT '制作步骤',
    `audit_status` VARCHAR(20) NOT NULL DEFAULT 'PENDING' COMMENT '审核状态：PENDING-待审核, APPROVED-已通过, REJECTED-已拒绝',
    `source` VARCHAR(100) DEFAULT NULL COMMENT '来源',
    `view_count` INT NOT NULL DEFAULT 0 COMMENT '浏览次数',
    `favorite_count` INT NOT NULL DEFAULT 0 COMMENT '收藏次数',
    `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_type_audit` (`content_type`, `audit_status`),
    KEY `idx_view_count` (`view_count` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='健康内容表';

-- ============================================================================
-- 8. 设备表 (device)
-- ============================================================================
-- 存储已适配的智能健康设备信息
-- ============================================================================
DROP TABLE IF EXISTS `device`;
CREATE TABLE `device` (
    `id` BIGINT NOT NULL COMMENT '主键ID',
    `device_name` VARCHAR(100) NOT NULL COMMENT '设备名称',
    `brand` VARCHAR(50) NOT NULL COMMENT '品牌',
    `model` VARCHAR(100) NOT NULL COMMENT '型号',
    `device_type` VARCHAR(20) NOT NULL COMMENT '设备类型：BP_MONITOR-血压计, BG_METER-血糖仪等',
    `connection_type` VARCHAR(20) NOT NULL COMMENT '连接方式：BLE-蓝牙, WIFI-无线',
    `protocol` VARCHAR(50) DEFAULT NULL COMMENT '协议类型',
    `supported_metrics` JSON NOT NULL COMMENT '支持的指标',
    `is_supported` BOOLEAN NOT NULL DEFAULT TRUE COMMENT '是否已适配',
    `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_brand_model` (`brand`, `model`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='设备表';

-- ============================================================================
-- 9. 设备绑定关系表 (device_binding)
-- ============================================================================
-- 存储用户与设备的绑定关系
-- ============================================================================
DROP TABLE IF EXISTS `device_binding`;
CREATE TABLE `device_binding` (
    `id` BIGINT NOT NULL COMMENT '主键ID',
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `device_id` BIGINT NOT NULL COMMENT '设备ID',
    `device_mac` VARCHAR(100) NOT NULL COMMENT '设备MAC地址',
    `member_id` BIGINT DEFAULT NULL COMMENT '关联成员ID',
    `nickname` VARCHAR(50) DEFAULT NULL COMMENT '设备昵称',
    `last_sync_time` DATETIME DEFAULT NULL COMMENT '最后同步时间',
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE COMMENT '是否启用',
    `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '绑定时间',
    `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_device_mac` (`device_mac`),
    KEY `idx_user_id` (`user_id`),
    CONSTRAINT `fk_device_binding_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`),
    CONSTRAINT `fk_device_binding_device` FOREIGN KEY (`device_id`) REFERENCES `device` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='设备绑定关系表';

-- ============================================================================
-- 10. 健康日记表 (health_diary)
-- ============================================================================
-- 存储家庭成员的健康日记记录
-- ============================================================================
DROP TABLE IF EXISTS `health_diary`;
CREATE TABLE `health_diary` (
    `id` BIGINT NOT NULL COMMENT '主键ID',
    `member_id` BIGINT NOT NULL COMMENT '成员ID',
    `diary_date` DATE NOT NULL COMMENT '日记日期',
    `content` TEXT NOT NULL COMMENT '日记内容',
    `mood` VARCHAR(20) DEFAULT NULL COMMENT '心情状态',
    `symptoms` JSON DEFAULT NULL COMMENT '症状记录',
    `medication` JSON DEFAULT NULL COMMENT '用药记录',
    `images` JSON DEFAULT NULL COMMENT '图片列表',
    `creator_id` BIGINT NOT NULL COMMENT '创建人ID',
    `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_member_date` (`member_id`, `diary_date`),
    KEY `idx_diary_date` (`diary_date` DESC),
    CONSTRAINT `fk_health_diary_member` FOREIGN KEY (`member_id`) REFERENCES `family_member` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='健康日记表';

-- ============================================================================
-- 11. 家庭活动表 (family_activity)
-- ============================================================================
-- 存储家庭健康打卡活动
-- ============================================================================
DROP TABLE IF EXISTS `family_activity`;
CREATE TABLE `family_activity` (
    `id` BIGINT NOT NULL COMMENT '主键ID',
    `family_id` BIGINT NOT NULL COMMENT '家庭ID',
    `activity_name` VARCHAR(100) NOT NULL COMMENT '活动名称',
    `activity_type` VARCHAR(20) NOT NULL COMMENT '活动类型',
    `target_value` INT NOT NULL COMMENT '目标值',
    `unit` VARCHAR(20) NOT NULL COMMENT '单位',
    `start_date` DATE NOT NULL COMMENT '开始日期',
    `end_date` DATE DEFAULT NULL COMMENT '结束日期',
    `is_recurring` BOOLEAN NOT NULL DEFAULT FALSE COMMENT '是否循环',
    `recurring_pattern` VARCHAR(50) DEFAULT NULL COMMENT '循环模式：DAILY-每日, WEEKLY-每周',
    `status` VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE-进行中, PAUSED-暂停, COMPLETED-已完成',
    `creator_id` BIGINT NOT NULL COMMENT '创建人ID',
    `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    KEY `idx_family_status` (`family_id`, `status`),
    KEY `idx_date_range` (`start_date`, `end_date`),
    CONSTRAINT `fk_family_activity_family` FOREIGN KEY (`family_id`) REFERENCES `family` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='家庭活动表';

-- ============================================================================
-- 12. 活动参与记录表 (activity_participant)
-- ============================================================================
-- 存储成员参与家庭活动的打卡记录
-- ============================================================================
DROP TABLE IF EXISTS `activity_participant`;
CREATE TABLE `activity_participant` (
    `id` BIGINT NOT NULL COMMENT '主键ID',
    `activity_id` BIGINT NOT NULL COMMENT '活动ID',
    `member_id` BIGINT NOT NULL COMMENT '成员ID',
    `record_date` DATE NOT NULL COMMENT '打卡日期',
    `actual_value` INT NOT NULL COMMENT '实际完成值',
    `note` VARCHAR(500) DEFAULT NULL COMMENT '备注',
    `images` JSON DEFAULT NULL COMMENT '图片证明',
    `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_activity_member_date` (`activity_id`, `member_id`, `record_date`),
    KEY `idx_record_date` (`record_date` DESC),
    CONSTRAINT `fk_activity_participant_activity` FOREIGN KEY (`activity_id`) REFERENCES `family_activity` (`id`),
    CONSTRAINT `fk_activity_participant_member` FOREIGN KEY (`member_id`) REFERENCES `family_member` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='活动参与记录表';

-- ============================================================================
-- 初始化数据
-- ============================================================================

-- 插入默认管理员用户（密码：123456，BCrypt加密后）
INSERT INTO `user` (`id`, `phone`, `password`, `nickname`, `role`, `status`) VALUES
(1, '13800000001', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi', '系统管理员', 'ADMIN', 'ACTIVE');

-- 插入系统默认预警规则模板（医学标准）
-- 注意：member_id 为 NULL 表示这是系统默认模板，创建成员时会复制这些规则
-- 血压规则
INSERT INTO `warning_rule` (`id`, `member_id`, `metric_type`, `threshold_min`, `threshold_max`, `compare_type`, `is_custom`, `continuous_count`, `creator_id`) VALUES
(1, NULL, 'BP_SYS', 90, 140, 'BETWEEN', FALSE, 1, 1),
(2, NULL, 'BP_DIA', 60, 90, 'BETWEEN', FALSE, 1, 1);

-- 血糖规则
INSERT INTO `warning_rule` (`id`, `member_id`, `metric_type`, `threshold_min`, `threshold_max`, `compare_type`, `is_custom`, `continuous_count`, `creator_id`) VALUES
(3, NULL, 'BG_FASTING', 3.9, 6.1, 'BETWEEN', FALSE, 1, 1),
(4, NULL, 'BG_POSTPRANDIAL', 4.4, 7.8, 'BETWEEN', FALSE, 1, 1);

-- 心率规则
INSERT INTO `warning_rule` (`id`, `member_id`, `metric_type`, `threshold_min`, `threshold_max`, `compare_type`, `is_custom`, `continuous_count`, `creator_id`) VALUES
(5, NULL, 'HR', 60, 100, 'BETWEEN', FALSE, 1, 1);

-- 体温规则
INSERT INTO `warning_rule` (`id`, `member_id`, `metric_type`, `threshold_min`, `threshold_max`, `compare_type`, `is_custom`, `continuous_count`, `creator_id`) VALUES
(6, NULL, 'TEMP', 36.0, 37.3, 'BETWEEN', FALSE, 1, 1);

-- ============================================================================
-- 索引优化建议
-- ============================================================================
-- 1. 高频查询优化：按成员+时间范围查询健康数据
--    已创建: idx_member_record_time (member_id, record_time DESC)
-- 2. 预警记录查询：按状态+时间查询
--    已创建: idx_status_warning_time (status, warning_time DESC)
-- 3. 设备MAC唯一索引
--    已创建: uk_device_mac (device_mac)

-- ============================================================================
-- 分表策略说明
-- ============================================================================
-- health_data 表建议按月分表，命名规则：health_data_YYYYMM
-- 创建分表SQL:
-- CREATE TABLE health_data_202601 LIKE health_data;
--
-- 数据迁移定时任务建议每月1号凌晨创建下月分表
-- ============================================================================

-- ============================================================================
-- 备份策略建议
-- ============================================================================
-- 全量备份: 每日凌晨执行
-- 增量备份: 每小时执行
-- 日志备份: 实时binlog备份
-- 保留时间: 全量备份30天，增量备份7天
-- ============================================================================
