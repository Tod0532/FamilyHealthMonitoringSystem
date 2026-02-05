# 阿里云后端API测试指南

> 最后更新时间：2026-02-05
> 后端版本：health-center-backend 1.0.0
> 服务器IP：139.129.108.119:8080

---

## 📋 目录

1. [服务信息](#1-服务信息)
2. [数据库连接信息](#2-数据库连接信息)
3. [测试账号](#3-测试账号)
4. [API接口列表](#4-api接口列表)
5. [测试示例](#5-测试示例)
6. [调试命令](#6-调试命令)

---

## 1. 服务信息

### 1.1 服务器详情

| 项目 | 信息 |
|------|------|
| **云服务商** | 阿里云 |
| **实例ID** | `iZm5e3qyj775jrq7zkm7keZ` |
| **公网IP** | `139.129.108.119` |
| **内网IP** | `172.20.252.13` |
| **操作系统** | Ubuntu 22.04 LTS |

### 1.2 后端服务配置

| 项目 | 信息 |
|------|------|
| **服务名称** | health-app.service |
| **运行端口** | 8080 |
| **Java版本** | OpenJDK 17.0.18 |
| **框架** | Spring Boot 2.7.18 |
| **服务状态** | ✅ 运行中 |

### 1.3 SSH连接（已配置免密）

```bash
# 使用别名连接
ssh aliyun

# 查看服务状态
ssh aliyun "systemctl status health-app"

# 重启服务
ssh aliyun "systemctl restart health-app"

# 查看服务日志
ssh aliyun "journalctl -u health-app -f"
```

---

## 2. 数据库连接信息

### 2.1 MySQL数据库

| 项目 | 信息 |
|------|------|
| **数据库类型** | MySQL 8.0.45 |
| **数据库名** | `health_center_db` |
| **字符集** | utf8mb4 |

### 2.2 数据库账号密码

| 用户类型 | 用户名 | 密码 | 主机 | 说明 |
|----------|--------|------|------|------|
| **管理员** | root | (空密码) | localhost | 服务器本地登录 |
| **应用用户** | health_app | HealthApp2024! | localhost | 后端应用连接 |

### 2.3 连接命令

```bash
# 本地连接（需要SSH到服务器）
ssh aliyun

# 使用root用户连接
mysql -u root health_center_db

# 使用health_app用户连接
mysql -u health_app -pHealthApp2024! health_center_db
```

### 2.4 数据库表结构

#### 当前部署的表

| 表名 | 说明 | 记录数 |
|------|------|--------|
| user | 用户表 | 1+ |
| family_member | 家庭成员表 | 1+ |
| health_data | 健康数据表 | 3+ |
| alert_rule | 预警规则表 | 0 |
| alert_record | 预警记录表 | 0 |
| health_content | 健康内容表 | 0 |

#### user表结构

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT | 主键 |
| phone | VARCHAR(20) | 手机号（唯一） |
| password | VARCHAR(255) | BCrypt加密密码 |
| nickname | VARCHAR(50) | 昵称 |
| avatar | VARCHAR(500) | 头像URL |
| gender | VARCHAR(10) | 性别（male/female） |
| birthday | DATE | 出生日期 |
| status | TINYINT | 状态（0-禁用，1-正常） |
| last_login_time | DATETIME | 最后登录时间 |
| last_login_ip | VARCHAR(50) | 最后登录IP |
| create_time | DATETIME | 创建时间 |
| update_time | DATETIME | 更新时间 |
| deleted | TINYINT | 逻辑删除标记 |

#### family_member表结构

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT | 主键 |
| user_id | BIGINT | 所属用户ID |
| name | VARCHAR(50) | 成员姓名 |
| relation | VARCHAR(20) | 关系（father/mother/spouse/child/other） |
| role | VARCHAR(20) | 角色（admin/member/guest） |
| gender | VARCHAR(10) | 性别 |
| birthday | DATE | 出生日期 |
| phone | VARCHAR(20) | 联系电话 |
| avatar | VARCHAR(500) | 头像 |
| notes | TEXT | 备注 |
| sort_order | INT | 排序 |
| create_time | DATETIME | 创建时间 |
| update_time | DATETIME | 更新时间 |
| deleted | TINYINT | 逻辑删除 |

#### health_data表结构

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT | 主键 |
| user_id | BIGINT | 所属用户ID |
| member_id | BIGINT | 成员ID |
| data_type | VARCHAR(20) | 数据类型 |
| value1 | DECIMAL(10,2) | 数据值1（收缩压/心率/血糖） |
| value2 | DECIMAL(10,2) | 数据值2（舒张压） |
| value3 | DECIMAL(10,2) | 数据值3（睡眠时长） |
| unit | VARCHAR(20) | 单位 |
| measure_time | DATETIME | 测量时间 |
| data_source | VARCHAR(20) | 来源（manual/device） |
| device_name | VARCHAR(100) | 设备名称 |
| notes | TEXT | 备注 |
| create_time | DATETIME | 创建时间 |
| update_time | DATETIME | 更新时间 |
| deleted | TINYINT | 逻辑删除 |

---

## 3. 测试账号

### 3.1 默认测试账号

| 项目 | 值 | 说明 |
|------|-----|------|
| 手机号 | **13800138000** | 已注册用户 |
| 密码 | **abc123456** | 符合规则（字母+数字） |
| 昵称 | TestUser | 自动生成 |

### 3.2 注册新用户

```bash
curl -X POST "http://139.129.108.119:8080/api/auth/register" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{
    "phone": "13900000000",
    "password": "abc123456",
    "confirmPassword": "abc123456",
    "smsCode": "123456",
    "nickname": "TestUser"
  }'
```

**密码规则**：必须包含字母和数字，长度6-20位

---

## 4. API接口列表

### 4.1 认证接口

| 接口 | 方法 | 说明 | 认证 |
|------|------|------|------|
| /api/auth/register | POST | 用户注册 | ❌ |
| /api/auth/login | POST | 用户登录 | ❌ |
| /api/auth/logout | POST | 用户登出 | ✅ |
| /api/auth/change-password | POST | 修改密码 | ✅ |
| /api/auth/refresh | POST | 刷新令牌 | ❌ |

### 4.2 用户接口

| 接口 | 方法 | 说明 | 认证 |
|------|------|------|------|
| /api/user/info | GET | 获取用户信息 | ✅ |
| /api/user/update | PUT | 更新用户信息 | ✅ |

### 4.3 家庭成员接口

| 接口 | 方法 | 说明 | 认证 |
|------|------|------|------|
| /api/members | GET | 获取成员列表 | ✅ |
| /api/members | POST | 添加成员 | ✅ |
| /api/members/{id} | PUT | 更新成员 | ✅ |
| /api/members/{id} | DELETE | 删除成员 | ✅ |

### 4.4 健康数据接口

| 接口 | 方法 | 说明 | 认证 |
|------|------|------|------|
| /api/health-data | GET | 获取健康数据列表 | ✅ |
| /api/health-data | POST | 添加健康数据 | ✅ |
| /api/health-data/{id} | PUT | 更新健康数据 | ✅ |
| /api/health-data/{id} | DELETE | 删除健康数据 | ✅ |

### 4.5 预警接口

| 接口 | 方法 | 说明 | 认证 |
|------|------|------|------|
| /api/alerts | GET | 获取预警记录 | ✅ |
| /api/alert-rules | GET | 获取预警规则 | ✅ |
| /api/alert-rules | POST | 添加预警规则 | ✅ |

---

## 5. 测试示例

### 5.1 用户注册

```bash
curl -X POST "http://139.129.108.119:8080/api/auth/register" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{
    "phone": "13900000000",
    "password": "abc123456",
    "confirmPassword": "abc123456",
    "smsCode": "123456",
    "nickname": "TestUser"
  }'
```

**响应**：
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "accessToken": "eyJhbGciOiJIUzM4NCJ9...",
    "refreshToken": "eyJhbGciOiJIUzM4NCJ9...",
    "tokenType": "Bearer",
    "expiresIn": 604800,
    "userInfo": {
      "id": 2019307347694460930,
      "phone": "13800138000",
      "nickname": "TestUser"
    }
  }
}
```

### 5.2 用户登录

```bash
curl -X POST "http://139.129.108.119:8080/api/auth/login" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{
    "phone": "13800138000",
    "password": "abc123456"
  }'
```

### 5.3 获取家庭成员列表（需要Token）

```bash
TOKEN="your_access_token_here"

curl -X GET "http://139.129.108.119:8080/api/members" \
  -H "Authorization: Bearer $TOKEN"
```

**响应**：
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "id": 2019307748401487874,
      "name": "Father",
      "relation": "father",
      "role": "member"
    }
  ]
}
```

### 5.4 添加家庭成员

```bash
curl -X POST "http://139.129.108.119:8080/api/members" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Mother",
    "relation": "mother",
    "gender": "female"
  }'
```

### 5.5 添加健康数据

```bash
curl -X POST "http://139.129.108.119:8080/api/health-data" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "memberId": "2019307748401487874",
    "dataType": "blood_pressure",
    "value1": 120,
    "value2": 80,
    "unit": "mmHg"
  }'
```

**响应**：
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": 2019307891787964418,
    "memberId": 2019307748401487874,
    "memberName": "Father",
    "dataType": "blood_pressure",
    "dataTypeLabel": "血压",
    "value1": 120.00,
    "value2": 80.00,
    "unit": "mmHg",
    "displayValue": "120/80 mmHg",
    "measureTime": "2026-02-05T15:11:33",
    "dataSource": "manual"
  }
}
```

### 5.6 获取健康数据列表

```bash
curl -X GET "http://139.129.108.119:8080/api/health-data" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 6. 调试命令

### 6.1 服务管理

```bash
# SSH连接服务器
ssh aliyun

# 查看服务状态
systemctl status health-app

# 启动服务
systemctl start health-app

# 停止服务
systemctl stop health-app

# 重启服务
systemctl restart health-app

# 查看服务日志（实时）
journalctl -u health-app -f

# 查看最近50行日志
journalctl -u health-app -n 50

# 查看应用日志
tail -f /opt/health-center/logs/console.log
```

### 6.2 数据库操作

```bash
# 连接数据库
mysql -u health_app -pHealthApp2024! health_center_db

# 查看所有表
SHOW TABLES;

# 查看用户数据
SELECT id, phone, nickname, status FROM user;

# 查看家庭成员
SELECT * FROM family_member;

# 查看健康数据
SELECT * FROM health_data ORDER BY create_time DESC LIMIT 10;

# 清空测试数据
DELETE FROM health_data WHERE id > 0;
DELETE FROM family_member WHERE id > 0;
DELETE FROM user WHERE id > 0;
```

### 6.3 端口检查

```bash
# 检查8080端口是否监听
netstat -tlnp | grep 8080

# 测试API健康检查
curl http://139.129.108.119:8080/api/test

# 测试登录接口
curl -X POST http://139.129.108.119:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","password":"abc123456"}'
```

---

## 7. 常见问题

### 7.1 登录失败

**问题**：密码错误

**解决**：
1. 确认使用测试账号 13800138000 / abc123456
2. 密码必须包含字母和数字
3. 检查用户是否已注册

### 7.2 Token过期

**问题**：403 Forbidden

**解决**：
```bash
# 重新登录获取新Token
curl -X POST "http://139.129.108.119:8080/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","password":"abc123456"}'
```

### 7.3 服务无法访问

**问题**：连接超时

**解决**：
```bash
# 检查服务状态
ssh aliyun "systemctl status health-app"

# 检查端口监听
ssh aliyun "netstat -tlnp | grep 8080"

# 重启服务
ssh aliyun "systemctl restart health-app"
```

---

*API测试指南，如有接口变更请及时更新*
