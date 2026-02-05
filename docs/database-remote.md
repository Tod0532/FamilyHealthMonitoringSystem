# 家庭健康中心APP - 远程数据库结构

> 最后更新时间：2026-02-05 晚
> 数据库类型：MySQL 8.0.45
> 字符集：utf8mb4
> 服务器：阿里云 ECS 139.129.108.119:8080

---

## 📊 数据库概览

```
health_center_db (阿里云生产数据库)
├── user                 # 用户表
├── family_member        # 家庭成员表
├── health_data          # 健康数据表
├── alert_rule           # 预警规则表
├── alert_record         # 预警记录表
└── health_content       # 健康内容表
```

---

## 🔐 数据库连接信息

### 连接方式1：SSH到服务器后连接

```bash
# 1. SSH连接到阿里云服务器
ssh aliyun

# 2. 连接MySQL（使用health_app用户）
mysql -u health_app -pHealthApp2024! health_center_db
```

### 连接方式2：本地MySQL客户端

| 项目 | 值 |
|------|-----|
| 主机 | 139.129.108.119 |
| 端口 | 3306 |
| 用户名 | health_app |
| 密码 | HealthApp2024! |
| 数据库 | health_center_db |

```bash
# 本地连接（需开放防火墙或SSH隧道）
mysql -h 139.129.108.119 -P 3306 -u health_app -p health_center_db
```

### 连接方式3：SSH隧道

```bash
# 建立SSH隧道
ssh -L 3307:localhost:3306 aliyun

# 本地连接
mysql -h 127.0.0.1 -P 3307 -u health_app -p health_center_db
```

---

## 👥 数据库账号密码

### 应用账号（推荐使用）

| 项目 | 值 | 说明 |
|------|-----|------|
| **用户名** | health_app | 应用专用账号 |
| **密码** | HealthApp2024! | 强密码 |
| **主机** | localhost | 仅限本地连接 |
| **权限** | ALL PRIVILEGES ON health_center_db.* | 完整权限 |

### 管理员账号

| 项目 | 值 | 说明 |
|------|-----|------|
| **用户名** | root | MySQL管理员 |
| **密码** | (空) | 仅服务器本地可用 |
| **认证方式** | mysql_native_password | 已配置 |

### 密码修改命令

```bash
# 修改health_app密码
mysql -u root -e "ALTER USER 'health_app'@'localhost' IDENTIFIED BY '新密码';"

# 修改root密码
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '新密码';"
```

---

## 📋 表结构详细说明

### 1. user（用户表）

存储APP注册用户信息。

#### 字段说明

| 字段名 | 类型 | 可空 | 默认值 | 说明 |
|--------|------|------|--------|------|
| id | BIGINT | NO | AUTO_INCREMENT | 主键 |
| phone | VARCHAR(20) | NO | - | 手机号（唯一索引） |
| password | VARCHAR(255) | NO | - | BCrypt加密密码 |
| nickname | VARCHAR(50) | YES | - | 昵称 |
| avatar | VARCHAR(500) | YES | - | 头像URL |
| gender | VARCHAR(10) | YES | male | 性别（male/female） |
| birthday | DATE | YES | - | 出生日期 |
| status | TINYINT | NO | 1 | 状态（0-禁用，1-正常） |
| last_login_time | DATETIME | YES | - | 最后登录时间 |
| last_login_ip | VARCHAR(50) | YES | - | 最后登录IP |
| create_time | DATETIME | NO | CURRENT_TIMESTAMP | 创建时间 |
| update_time | DATETIME | NO | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | 更新时间 |
| deleted | TINYINT | NO | 0 | 逻辑删除（0-未删除，1-已删除） |

#### 索引
```sql
PRIMARY KEY (id),
UNIQUE KEY uk_phone (phone),
KEY idx_status (status),
KEY idx_create_time (create_time)
```

#### 当前数据示例

| id | phone | nickname | status | deleted |
|----|-------|----------|--------|---------|
| 2019307347694460930 | 13800138000 | TestUser | 1 | 0 |

---

### 2. family_member（家庭成员表）

存储家庭成员信息。

#### 字段说明

| 字段名 | 类型 | 可空 | 默认值 | 说明 |
|--------|------|------|--------|------|
| id | BIGINT | NO | AUTO_INCREMENT | 主键 |
| user_id | BIGINT | NO | - | 所属用户ID（外键到user表） |
| name | VARCHAR(50) | NO | - | 成员姓名 |
| relation | VARCHAR(20) | NO | - | 关系（father/mother/spouse/child/other） |
| role | VARCHAR(20) | NO | member | 角色（admin/member/guest） |
| gender | VARCHAR(10) | YES | male | 性别（male/female） |
| birthday | DATE | YES | - | 出生日期 |
| phone | VARCHAR(20) | YES | - | 联系电话 |
| avatar | VARCHAR(500) | YES | - | 头像 |
| notes | TEXT | YES | - | 备注 |
| sort_order | INT | NO | 0 | 排序序号 |
| create_time | DATETIME | NO | CURRENT_TIMESTAMP | 创建时间 |
| update_time | DATETIME | YES | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | 更新时间 |
| deleted | TINYINT | NO | 0 | 逻辑删除 |

#### 索引
```sql
PRIMARY KEY (id),
KEY idx_user_id (user_id),
CONSTRAINT fk_family_member_user FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE
```

#### 当前数据示例

| id | user_id | name | relation | role | gender |
|----|---------|------|----------|------|--------|
| 2019307748401487874 | 2019307347694460930 | Father | father | member | male |

---

### 3. health_data（健康数据表）

存储健康指标数据。

#### 字段说明

| 字段名 | 类型 | 可空 | 默认值 | 说明 |
|--------|------|------|--------|------|
| id | BIGINT | NO | AUTO_INCREMENT | 主键 |
| user_id | BIGINT | NO | - | 所属用户ID |
| member_id | BIGINT | YES | - | 成员ID（外键） |
| data_type | VARCHAR(20) | NO | - | 数据类型 |
| value1 | DECIMAL(10,2) | YES | - | 数据值1（收缩压/心率/血糖） |
| value2 | DECIMAL(10,2) | YES | - | 数据值2（舒张压） |
| value3 | DECIMAL(10,2) | YES | - | 数据值3（睡眠时长等） |
| unit | VARCHAR(20) | YES | - | 单位 |
| measure_time | DATETIME | YES | - | 测量时间 |
| data_source | VARCHAR(20) | YES | manual | 数据来源（manual/device） |
| device_name | VARCHAR(100) | YES | - | 设备名称 |
| notes | TEXT | YES | - | 备注 |
| create_time | DATETIME | NO | CURRENT_TIMESTAMP | 创建时间 |
| update_time | DATETIME | YES | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | 更新时间 |
| deleted | TINYINT | NO | 0 | 逻辑删除 |

#### 数据类型枚举

| 代码 | 名称 | value1 | value2 | unit | 说明 |
|------|------|--------|--------|------|------|
| blood_pressure | 血压 | 收缩压 | 舒张压 | mmHg | 需要value2 |
| heart_rate | 心率 | 心率值 | - | bpm | 只需value1 |
| blood_sugar | 血糖 | 血糖值 | - | mmol/L | 只需value1 |
| temperature | 体温 | 体温值 | - | ℃ | 只需value1 |
| weight | 体重 | 体重值 | - | kg | 只需value1 |
| height | 身高 | 身高值 | - | cm | 只需value1 |
| steps | 步数 | 步数值 | - | steps | 只需value1 |
| sleep | 睡眠 | 时长 | - | h | 只需value1 |

#### 索引
```sql
PRIMARY KEY (id),
KEY idx_user_id (user_id),
KEY idx_member_id (member_id),
CONSTRAINT fk_health_data_member FOREIGN KEY (member_id) REFERENCES family_member(id) ON DELETE SET NULL
```

#### 当前数据示例

| id | user_id | member_id | data_type | value1 | value2 | unit |
|----|---------|----------|----------|-------|-------|------|
| 2019307891787964418 | 2019307347694460930 | 2019307748401487874 | blood_pressure | 120.00 | 80.00 | mmHg |
| 2019308028337725441 | 2019307347694460930 | 2019307748401487874 | heart_rate | 75.00 | - | bpm |
| 2019308118943080449 | 2019307347694460930 | 2019307748401487874 | heart_rate | 75.00 | - | bpm |

---

### 4. alert_rule（预警规则表）

存储健康预警规则配置。

#### 字段说明

| 字段名 | 类型 | 可空 | 默认值 | 说明 |
|--------|------|------|--------|------|
| id | BIGINT | NO | AUTO_INCREMENT | 主键 |
| user_id | BIGINT | NO | - | 所属用户ID |
| member_id | BIGINT | YES | - | 成员ID（NULL表示全部成员） |
| alert_type | VARCHAR(50) | NO | - | 预警类型 |
| condition_min | DECIMAL(10,2) | YES | - | 阈值下限 |
| condition_max | DECIMAL(10,2) | YES | - | 阈值上限 |
| alert_level | VARCHAR(20) | NO | info | 预警级别 |
| is_active | TINYINT | NO | 1 | 是否启用（0-禁用，1-启用） |
| create_time | DATETIME | NO | CURRENT_TIMESTAMP | 创建时间 |
| update_time | DATETIME | YES | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | 更新时间 |

#### 预警类型

| 类型 | 代码 | 说明 |
|------|------|------|
| 血压预警 | blood_pressure | 血压超出阈值 |
| 心率预警 | heart_rate | 心率超出阈值 |
| 血糖预警 | blood_sugar | 血糖超出阈值 |
| 体温预警 | temperature | 体温超出阈值 |
| 体重预警 | weight | 体重超出阈值 |

#### 预警级别

| 级别 | 代码 | 颜色 |
|------|------|------|
| 信息 | info | 绿色 |
| 警告 | warning | 橙色 |
| 危险 | danger | 红色 |

---

### 5. alert_record（预警记录表）

存储预警历史记录。

#### 字段说明

| 字段名 | 类型 | 可空 | 默认值 | 说明 |
|--------|------|------|--------|------|
| id | BIGINT | NO | AUTO_INCREMENT | 主键 |
| user_id | BIGINT | NO | - | 所属用户ID |
| member_id | BIGINT | NO | - | 成员ID |
| alert_type | VARCHAR(50) | NO | - | 预警类型 |
| alert_value | VARCHAR(100) | NO | - | 触发值 |
| alert_level | VARCHAR(20) | NO | info | 预警级别 |
| is_read | TINYINT | NO | 0 | 是否已读（0-未读，1-已读） |
| is_handled | TINYINT | NO | 0 | 是否已处理（0-未处理，1-已处理） |
| handle_time | DATETIME | YES | - | 处理时间 |
| create_time | DATETIME | NO | CURRENT_TIMESTAMP | 创建时间 |

---

### 6. health_content（健康内容表）

存储健康文章内容。

#### 字段说明

| 字段名 | 类型 | 可空 | 默认值 | 说明 |
|--------|------|------|--------|------|
| id | BIGINT | NO | AUTO_INCREMENT | 主键 |
| title | VARCHAR(200) | NO | - | 内容标题 |
| content_type | VARCHAR(20) | NO | - | 内容类型 |
| content | TEXT | NO | - | 内容详情（Markdown） |
| tags | VARCHAR(500) | YES | - | 标签（逗号分隔） |
| author | VARCHAR(100) | YES | - | 作者 |
| source_url | VARCHAR(500) | YES | - | 来源URL |
| view_count | INT | NO | 0 | 浏览次数 |
| is_published | TINYINT | NO | 1 | 是否发布 |
| create_time | DATETIME | NO | CURRENT_TIMESTAMP | 创建时间 |
| update_time | DATETIME | YES | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | 更新时间 |

---

## 🔧 数据库维护命令

### 查询表数据

```sql
-- 查看用户数据
SELECT id, phone, nickname, status FROM user;

-- 查看家庭成员
SELECT id, name, relation, gender FROM family_member;

-- 查看健康数据（最新10条）
SELECT id, member_id, data_type, value1, value2, unit, measure_time
FROM health_data
ORDER BY create_time DESC
LIMIT 10;

-- 统计各类型数据量
SELECT data_type, COUNT(*) as count
FROM health_data
GROUP BY data_type;
```

### 清空测试数据

```sql
-- 清空健康数据
DELETE FROM health_data WHERE id > 0;

-- 清空家庭成员
DELETE FROM family_member WHERE id > 0;

-- 清空预警记录
DELETE FROM alert_record WHERE id > 0;

-- 重置自增ID
ALTER TABLE health_data AUTO_INCREMENT = 1;
ALTER TABLE family_member AUTO_INCREMENT = 1;
ALTER TABLE alert_record AUTO_INCREMENT = 1;
```

### 备份数据库

```bash
# 备份整个数据库
mysqldump -u health_app -pHealthApp2024! health_center_db > backup_$(date +%Y%m%d).sql

# 恢复数据库
mysql -u health_app -pHealthApp2024! health_center_db < backup_20260205.sql
```

---

## 📊 数据库统计

| 表名 | 记录数 | 说明 |
|------|--------|------|
| user | 1+ | 已注册用户 |
| family_member | 1+ | 家庭成员 |
| health_data | 3+ | 健康数据记录 |
| alert_rule | 0 | 预警规则 |
| alert_record | 0 | 预警记录 |
| health_content | 0 | 健康内容 |

---

*远程数据库结构文档，如有表结构变更请及时更新*
