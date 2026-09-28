-- ============================================================================
-- 家庭健康中心APP - H2 数据库表结构（开发 / 模拟环境）
-- ============================================================================
-- 重要：本文件必须与 com.health.domain.entity 下的实体保持严格一致。
--
-- 历史问题（2026-09 修复）：本文件长期停留在早期版本，与实体严重脱节，
-- 导致 dev(模拟) 环境几乎所有接口都会 SQL 报错，典型表现为登录直接 500：
--   SQL: SELECT ... FROM `user` WHERE deleted=0 AND (phone = ?)
--   Cause: org.h2.jdbc.JdbcSQLSyntaxErrorException: Table "USER" not found
-- 具体差异：
--   1. 用户表名为 sys_user，而 User 实体映射 @TableName("`user`")
--   2. user 表缺 role / family_id / family_role / last_login_ip 四列
--   3. 完全没有 family 表（Family 实体映射 @TableName("family")）
--   4. family_member / health_data / alert_rule / alert_record 用的是
--      is_deleted，而实体统一用 @TableLogic deleted -> "Column DELETED not found"
--   5. family_member 缺 family_id、notes；health_data 缺 family_id、device_name
-- 另外 application-dev.yml 曾把 logic-delete-field 覆盖为 isDeleted，
-- 但实体字段带 @TableLogic 注解，注解优先，因此该覆盖只会造成混乱，已移除。
-- ============================================================================

-- ============================================================================
-- 用户表
-- ============================================================================
CREATE TABLE IF NOT EXISTS `user` (
    id BIGINT NOT NULL PRIMARY KEY,
    phone VARCHAR(20) NOT NULL,
    password VARCHAR(255) NOT NULL,
    nickname VARCHAR(50),
    avatar VARCHAR(500),
    gender VARCHAR(10),
    birthday DATE,
    status TINYINT DEFAULT 1,
    role VARCHAR(20) DEFAULT 'USER',
    family_id BIGINT,
    family_role VARCHAR(20) DEFAULT 'member',
    last_login_time TIMESTAMP,
    last_login_ip VARCHAR(50),
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted TINYINT DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_user_phone ON `user`(phone);
CREATE INDEX IF NOT EXISTS idx_user_status ON `user`(status);
CREATE INDEX IF NOT EXISTS idx_user_create_time ON `user`(create_time);
CREATE INDEX IF NOT EXISTS idx_user_family_id ON `user`(family_id);

-- ============================================================================
-- 家庭表
-- ============================================================================
CREATE TABLE IF NOT EXISTS family (
    id BIGINT NOT NULL PRIMARY KEY,
    family_name VARCHAR(100) NOT NULL,
    family_code VARCHAR(20) NOT NULL,
    admin_id BIGINT NOT NULL,
    member_count INT DEFAULT 1,
    status TINYINT DEFAULT 1,
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted TINYINT DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_family_code ON family(family_code);
CREATE INDEX IF NOT EXISTS idx_family_admin_id ON family(admin_id);

-- ============================================================================
-- 家庭成员表
-- ============================================================================
CREATE TABLE IF NOT EXISTS family_member (
    id BIGINT NOT NULL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    family_id BIGINT,
    name VARCHAR(50) NOT NULL,
    gender VARCHAR(10),
    relation VARCHAR(20),
    role VARCHAR(20) DEFAULT 'member',
    birthday DATE,
    avatar VARCHAR(500),
    notes VARCHAR(500),
    sort_order INT DEFAULT 0,
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted TINYINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_family_member_user_id ON family_member(user_id);
CREATE INDEX IF NOT EXISTS idx_family_member_family_id ON family_member(family_id);
CREATE INDEX IF NOT EXISTS idx_family_member_sort_order ON family_member(sort_order);

-- ============================================================================
-- 健康数据表
-- ============================================================================
CREATE TABLE IF NOT EXISTS health_data (
    id BIGINT NOT NULL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    family_id BIGINT,
    member_id BIGINT,
    data_type VARCHAR(50) NOT NULL,
    value1 DECIMAL(10,2),
    value2 DECIMAL(10,2),
    value3 DECIMAL(10,2),
    unit VARCHAR(20),
    measure_time TIMESTAMP NOT NULL,
    data_source VARCHAR(20) DEFAULT 'manual',
    device_name VARCHAR(100),
    notes VARCHAR(500),
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted TINYINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_health_data_user_id ON health_data(user_id);
CREATE INDEX IF NOT EXISTS idx_health_data_family_id ON health_data(family_id);
CREATE INDEX IF NOT EXISTS idx_health_data_member_id ON health_data(member_id);
CREATE INDEX IF NOT EXISTS idx_health_data_type ON health_data(data_type);
CREATE INDEX IF NOT EXISTS idx_health_data_measure_time ON health_data(measure_time);
CREATE INDEX IF NOT EXISTS idx_health_data_user_member_type ON health_data(user_id, member_id, data_type);

-- ============================================================================
-- 预警规则表
-- ============================================================================
CREATE TABLE IF NOT EXISTS alert_rule (
    id BIGINT NOT NULL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    alert_type VARCHAR(50) NOT NULL,
    alert_level VARCHAR(20) NOT NULL,
    condition_type VARCHAR(20) NOT NULL,
    threshold1 DOUBLE,
    threshold2 DOUBLE,
    rule_name VARCHAR(100),
    enabled TINYINT DEFAULT 1,
    is_default TINYINT DEFAULT 0,
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted TINYINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_alert_rule_user_id ON alert_rule(user_id);
CREATE INDEX IF NOT EXISTS idx_alert_rule_type ON alert_rule(alert_type);
CREATE INDEX IF NOT EXISTS idx_alert_rule_enabled ON alert_rule(enabled);

-- ============================================================================
-- 预警记录表
-- ============================================================================
CREATE TABLE IF NOT EXISTS alert_record (
    id BIGINT NOT NULL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    member_id BIGINT,
    rule_id BIGINT,
    alert_type VARCHAR(50) NOT NULL,
    alert_level VARCHAR(20) NOT NULL,
    title VARCHAR(100),
    content VARCHAR(500),
    trigger_value VARCHAR(50),
    status VARCHAR(20) DEFAULT 'unread',
    handle_time TIMESTAMP,
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted TINYINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_alert_record_user_id ON alert_record(user_id);
CREATE INDEX IF NOT EXISTS idx_alert_record_member_id ON alert_record(member_id);
CREATE INDEX IF NOT EXISTS idx_alert_record_status ON alert_record(status);
CREATE INDEX IF NOT EXISTS idx_alert_record_type ON alert_record(alert_type);
CREATE INDEX IF NOT EXISTS idx_alert_record_create_time ON alert_record(create_time);

-- ============================================================================
-- 健康内容表（暂无对应实体，保留以兼容后续内容接口）
-- ============================================================================
CREATE TABLE IF NOT EXISTS health_content (
    id BIGINT NOT NULL PRIMARY KEY,
    category VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    summary VARCHAR(500),
    content CLOB NOT NULL,
    cover_image VARCHAR(500),
    tags VARCHAR(200),
    view_count INT DEFAULT 0,
    like_count INT DEFAULT 0,
    is_published TINYINT DEFAULT 1,
    published_at TIMESTAMP,
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted TINYINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_health_content_category ON health_content(category);
CREATE INDEX IF NOT EXISTS idx_health_content_published ON health_content(is_published);
CREATE INDEX IF NOT EXISTS idx_health_content_published_at ON health_content(published_at);
