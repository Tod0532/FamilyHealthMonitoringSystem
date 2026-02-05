# 阿里云服务器部署指南

> 家庭健康中心APP - 后端服务阿里云部署完整指南

---

## 📋 目录

1. [服务器信息](#1-服务器信息)
2. [通讯方式](#2-通讯方式)
3. [服务器环境](#3-服务器环境)
4. [数据库部署](#4-数据库部署)
5. [后端程序部署](#5-后端程序部署)
6. [服务管理](#6-服务管理)
7. [安全组配置](#7-安全组配置)
8. [API接口测试](#8-api接口测试)
9. [常见问题](#9-常见问题)

---

## 1. 服务器信息

### 1.1 服务器详情

| 项目 | 信息 |
|------|------|
| **云服务商** | 阿里云 |
| **产品类型** | ECS云服务器 |
| **实例ID** | `iZm5e3qyj775jrq7zkm7keZ` |
| **公网IP** | `139.129.108.119` |
| **内网IP** | `172.20.252.13` |
| **操作系统** | Ubuntu 22.04 LTS |
| **内核版本** | Linux 5.15.0-164-generic |
| **架构** | x86_64 |

### 1.2 登录凭据

| 项目 | 信息 |
|------|------|
| **用户名** | root |
| **密码** | ALJTjt7067290@ |
| **SSH端口** | 22 |

---

## 2. 通讯方式

### 2.1 SSH远程连接

**使用Windows PowerShell或CMD连接**：
```bash
ssh root@139.129.108.119
```

**使用FinalShell连接**：
- 主机：`139.129.108.119`
- 用户名：`root`
- 密码：`ALJTjt7067290@`
- 端口：`22`

**跳过主机密钥检查**（首次连接）：
```bash
ssh -o StrictHostKeyChecking=no root@139.129.108.119
```

### 2.2 执行远程命令

```bash
# 单行命令
ssh root@139.129.108.119 "systemctl status health-app"

# 多行命令
ssh root@139.129.108.119 "
systemctl status health-app
netstat -tlnp | grep 8080
"
```

### 2.3 SSH免密登录配置 ✅ 已配置

> **重要**：免密登录已于 2026-02-05 配置完成，以后连接服务器无需再输入密码！

**本地SSH配置文件位置**：`~/.ssh/config`

**配置内容**：
```
Host aliyun
    HostName 139.129.108.119
    User root
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
```

**使用别名连接（推荐）**：
```bash
ssh aliyun
```

**使用IP连接**：
```bash
ssh root@139.129.108.119
```

**常用免密命令**：
| 操作 | 命令 |
|------|------|
| 连接服务器 | `ssh aliyun` |
| 查看服务状态 | `ssh aliyun "systemctl status health-app"` |
| 重启服务 | `ssh aliyun "systemctl restart health-app"` |
| 查看日志 | `ssh aliyun "tail -f /opt/health-center/logs/console.log"` |
| 执行多行命令 | `ssh aliyun "uptime && df -h"` |
| 上传文件 | `scp local.file aliyun:/opt/health-center/` |
| 下载文件 | `scp aliyun:/opt/health-center/file.txt .`` |
| 上传目录 | `scp -r local_dir aliyun:/opt/health-center/`` |

**SSH密钥信息**：
- 密钥类型：ED25519
- 私钥路径：`~/.ssh/id_ed25519`
- 公钥路径：`~/.ssh/id_ed25519.pub`
- 密钥注释：`health-center@aliyun`
- 配置时间：2026-02-05

### 2.4 文件传输

**从本地上传到服务器**：
```bash
scp local.file root@139.129.108.119:/opt/health-center/
```

**从服务器下载到本地**：
```bash
scp root@139.129.108.119:/opt/health-center/file.txt ./
```

**上传整个目录**：
```bash
scp -r local_dir root@139.129.108.119:/opt/health-center/
```

---

## 3. 服务器环境

### 3.1 已安装软件

| 软件 | 版本 | 安装路径 | 验证命令 |
|------|------|----------|----------|
| Java | OpenJDK 17.0.18 | /usr/lib/jvm/java-17-openjdk-amd64 | `java -version` |
| MySQL | 8.0.45 | /usr/bin/mysql | `mysql --version` |
| Maven | 3.6.3 | /usr/share/maven | `mvn -version` |

### 3.2 环境变量

```bash
# JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Maven
export M2_HOME=/usr/share/maven

# PATH
export PATH=$JAVA_HOME/bin:$M2_HOME/bin:$PATH
```

### 3.3 安装新软件（如需要）

```bash
# 更新软件包列表
apt update

# 安装软件
apt install -y <package_name>

# 示例：安装vim
apt install -y vim
```

---

## 4. 数据库部署

### 4.1 MySQL服务管理

```bash
# 启动MySQL
systemctl start mysql

# 停止MySQL
systemctl stop mysql

# 重启MySQL
systemctl restart mysql

# 查看状态
systemctl status mysql

# 开机自启
systemctl enable mysql
```

### 4.2 数据库配置

**当前数据库信息**：

| 项目 | 值 |
|------|-----|
| 数据库名 | `health_center_db` |
| 字符集 | utf8mb4 |
| 排序规则 | utf8mb4_unicode_ci |
| 主机 | localhost |
| 端口 | 3306 |

**数据库账号密码**：

| 用户类型 | 用户名 | 密码 | 主机 | 说明 |
|----------|--------|------|------|------|
| **管理员** | root | (空密码) | localhost | 服务器本地登录 |
| **应用用户** | health_app | HealthApp2024! | localhost | 后端应用连接 |

> **详细表结构**：请参考 [远程数据库结构](./database-remote.md) 获取完整的表结构说明

### 4.3 数据库操作

**方式一：使用root用户登录（无密码）**
```bash
mysql -u root health_center_db
```

**方式二：使用health_app用户登录**
```bash
mysql -u health_app -pHealthApp2024! health_center_db
```

**方式三：通过SSH远程连接后登录**
```bash
# 先SSH到服务器
ssh aliyun

# 再连接数据库
mysql -u health_app -pHealthApp2024! health_center_db
```

**常用SQL命令**：
```sql
-- 查看所有数据库
SHOW DATABASES;

-- 切换数据库
USE health_center_db;

-- 查看所有表
SHOW TABLES;

-- 查看表结构
DESCRIBE table_name;

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

### 4.4 数据库创建（如需要重新创建）

```sql
-- 创建数据库
CREATE DATABASE IF NOT EXISTS health_center_db
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

-- 创建用户
CREATE USER IF NOT EXISTS 'health_app'@'localhost'
IDENTIFIED BY 'HealthApp2024!';

-- 授权
GRANT ALL PRIVILEGES ON health_center_db.*
TO 'health_app'@'localhost';

-- 刷新权限
FLUSH PRIVILEGES;
```

### 4.5 导入数据库结构

```bash
# 方式一：从本地SQL文件导入
mysql -u root -p health_center_db < /path/to/schema.sql

# 方式二：从服务器本地文件
mysql -u root health_center_db < /opt/health-center/schema.sql
```

### 4.6 数据库备份

```bash
# 备份数据库
mysqldump -u root -p health_center_db > backup_$(date +%Y%m%d).sql

# 恢复数据库
mysql -u root -p health_center_db < backup_20260204.sql
```

---

## 5. 后端程序部署

### 5.1 项目目录结构

```
/opt/health-center/
├── src/                          # 源代码目录
│   └── main/
│       ├── java/com/health/
│       │   ├── HealthApplication.java    # 主启动类
│       │   └── controller/
│       │       └── HealthController.java # 控制器
│       └── resources/
│           └── application.yml           # 配置文件
├── target/                       # 编译输出目录
│   └── health-center-1.0.0.jar   # 可运行JAR包
├── logs/                        # 日志目录
│   ├── console.log              # 控制台日志
│   └── error.log                # 错误日志
├── uploads/                     # 文件上传目录
├── pom.xml                      # Maven配置文件
└── health-center-1.0.0.jar      # JAR包软链接（可选）
```

### 5.2 应用配置文件

**application.yml**：
```yaml
server:
  port: 8080

spring:
  application:
    name: health-center
```

### 5.3 编译打包

```bash
# 进入项目目录
cd /opt/health-center

# 清理并打包
mvn clean package -DskipTests

# 查看生成的JAR包
ls -lh target/*.jar
```

### 5.4 systemd服务配置

**服务文件位置**：`/etc/systemd/system/health-app.service`

**服务配置内容**：
```ini
[Unit]
Description=Health Center Backend Service
After=network.target mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/health-center
ExecStart=/usr/bin/java -jar /opt/health-center/target/health-center-1.0.0.jar
Restart=always
RestartSec=10
StandardOutput=append:/opt/health-center/logs/console.log
StandardError=append:/opt/health-center/logs/error.log

[Install]
WantedBy=multi-user.target
```

### 5.5 手动启动（不使用systemd）

```bash
# 进入项目目录
cd /opt/health-center

# 直接运行
java -jar target/health-center-1.0.0.jar

# 后台运行
nohup java -jar target/health-center-1.0.0.jar > logs/app.log 2>&1 &

# 查看进程
ps aux | grep health-center

# 停止进程
kill <pid>
```

---

## 6. 服务管理

### 6.1 systemd命令

```bash
# 启动服务
systemctl start health-app

# 停止服务
systemctl stop health-app

# 重启服务
systemctl restart health-app

# 查看状态
systemctl status health-app

# 开机自启
systemctl enable health-app

# 取消自启
systemctl disable health-app

# 查看服务日志
journalctl -u health-app -f

# 查看最近100行日志
journalctl -u health-app -n 100
```

### 6.2 日志查看

```bash
# systemd日志
journalctl -u health-app -f

# 应用日志
tail -f /opt/health-center/logs/console.log

# 错误日志
tail -f /opt/health-center/logs/error.log

# 查看最近100行
tail -n 100 /opt/health-center/logs/console.log
```

### 6.3 端口检查

```bash
# 检查端口监听
netstat -tlnp | grep 8080

# 或使用ss命令
ss -tlnp | grep 8080

# 检查进程
ps aux | grep java
```

---

## 7. 安全组配置

### 7.1 什么是安全组

安全组是阿里云提供的虚拟防火墙，用于控制服务器的入站和出站流量。

### 7.2 需要开放的端口

| 协议 | 端口 | 说明 | 来源 |
|------|------|------|------|
| TCP | 22 | SSH远程登录 | 0.0.0.0/0 |
| TCP | 8080 | 后端API服务 | 0.0.0.0/0 |
| TCP | 3306 | MySQL（仅内网） | 服务器IP |

### 7.3 配置步骤

1. **登录阿里云控制台**
   ```
   https://ecs.console.aliyun.com/
   ```

2. **进入安全组配置**
   - 找到实例 `iZm5e3qyj775jrq7zkm7keZ`
   - 点击"安全组"标签
   - 点击"配置规则"

3. **添加入方向规则**
   - 点击"手动添加"
   - 填写规则：
     - 规则方向：入方向
     - 授权策略：允许
     - 协议类型：自定义TCP
     - 端口范围：8080/8080
     - 授权对象：0.0.0.0/0
     - 优先级：1
     - 描述：健康中心后端API

4. **保存规则**

### 7.4 验证配置

```bash
# 从外部测试（需要在本地执行）
curl http://139.129.108.119:8080/api/test
```

---

## 8. API接口测试

> **详细测试指南**：请参考 [API测试指南](./api-test-guide.md) 获取完整的API接口文档和测试示例
> **数据库结构**：请参考 [远程数据库结构](./database-remote.md) 获取数据库表结构说明

### 8.1 测试账号

| 项目 | 值 | 说明 |
|------|-----|------|
| 手机号 | **13800138000** | 已注册测试账号 |
| 密码 | **abc123456** | 符合规则（字母+数字） |
| 昵称 | TestUser | 自动生成 |
| 用户ID | 2019307347694460930 | 系统分配 |

### 8.2 完整接口列表

| 接口路径 | 方法 | 说明 | 认证 |
|----------|------|------|------|
| `/api/auth/register` | POST | 用户注册 | ❌ |
| `/api/auth/login` | POST | 用户登录 | ❌ |
| `/api/auth/logout` | POST | 用户登出 | ✅ |
| `/api/auth/change-password` | POST | 修改密码 | ✅ |
| `/api/auth/refresh` | POST | 刷新令牌 | ❌ |
| `/api/user/info` | GET | 获取用户信息 | ✅ |
| `/api/user/update` | PUT | 更新用户信息 | ✅ |
| `/api/members` | GET | 获取成员列表 | ✅ |
| `/api/members` | POST | 添加成员 | ✅ |
| `/api/members/{id}` | PUT | 更新成员 | ✅ |
| `/api/members/{id}` | DELETE | 删除成员 | ✅ |
| `/api/health-data` | GET | 获取健康数据列表 | ✅ |
| `/api/health-data` | POST | 添加健康数据 | ✅ |
| `/api/health-data/{id}` | PUT | 更新健康数据 | ✅ |
| `/api/health-data/{id}` | DELETE | 删除健康数据 | ✅ |
| `/api/alerts` | GET | 获取预警记录 | ✅ |
| `/api/alert-rules` | GET | 获取预警规则 | ✅ |
| `/api/alert-rules` | POST | 添加预警规则 | ✅ |

### 8.3 测试结果（2026-02-05）

| 接口 | 方法 | 状态 | 说明 |
|------|------|------|------|
| 用户注册 | POST | ✅ 通过 | 成功创建用户并返回Token |
| 用户登录 | POST | ✅ 通过 | 成功返回JWT Token |
| 获取家庭成员 | GET | ✅ 通过 | 正确返回成员列表 |
| 添加家庭成员 | POST | ✅ 通过 | 成功添加成员 |
| 添加健康数据 | POST | ✅ 通过 | 成功添加血压/心率数据 |
| 获取健康数据 | GET | ✅ 通过 | 正确返回健康数据列表 |

### 8.4 快速测试命令

**用户登录（获取Token）**：
```bash
curl -X POST "http://139.129.108.119:8080/api/auth/login" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{
    "phone": "13800138000",
    "password": "abc123456"
  }'
```

**响应示例**：
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

**使用Token获取家庭成员列表**：
```bash
TOKEN="your_access_token_here"

curl -X GET "http://139.129.108.119:8080/api/members" \
  -H "Authorization: Bearer $TOKEN"
```

### 8.5 依赖服务状态

| 服务 | 状态 | 版本 | 说明 |
|------|------|------|------|
| MySQL | ✅ 运行中 | 8.0.45 | 数据存储 |
| Redis | ✅ 运行中 | 7.0.15 | 缓存/会话 |
| RabbitMQ | ⚠️ 已禁用 | - | 消息队列（当前不需要） |

### 8.6 JWT配置

| 项目 | 值 |
|------|-----|
| 密钥 | health-center-secret-key-2024-very-long-key-32-chars |
| 算法 | HS384 |
| 有效期 | 604800秒（7天） |

---

## 9. 常见问题

### 9.1 服务无法启动

**检查日志**：
```bash
journalctl -u health-app -n 50
```

**常见原因**：
- 端口被占用：`netstat -tlnp | grep 8080`
- Java版本不匹配：`java -version`
- 配置文件错误：检查 `application.yml`

### 9.2 无法远程连接

**检查项**：
```bash
# 1. 服务是否运行
systemctl status health-app

# 2. 端口是否监听
netstat -tlnp | grep 8080

# 3. 防火墙状态
ufw status

# 4. 安全组配置
# 需在阿里云控制台检查
```

### 9.3 数据库连接失败

**检查项**：
```bash
# 1. MySQL是否运行
systemctl status mysql

# 2. 数据库是否存在
mysql -u root -e "SHOW DATABASES;"

# 3. 用户权限
mysql -u root -e "SELECT user, host FROM mysql.user;"
```

### 9.4 内存不足

**查看内存使用**：
```bash
free -h
```

**清理缓存**：
```bash
sync; echo 3 > /proc/sys/vm/drop_caches
```

### 9.5 磁盘空间不足

**查看磁盘使用**：
```bash
df -h
```

**清理日志**：
```bash
# 清空应用日志
echo > /opt/health-center/logs/console.log
echo > /opt/health-center/logs/error.log

# 清空systemd日志
journalctl --vacuum-time=7d
```

---

## 10. 快速参考

### 10.1 常用命令速查

```bash
# SSH连接
ssh root@139.129.108.119

# 服务管理
systemctl start|stop|restart|status health-app

# 查看日志
journalctl -u health-app -f
tail -f /opt/health-center/logs/console.log

# 检查端口
netstat -tlnp | grep 8080

# 重新部署
cd /opt/health-center && mvn clean package -DskipTests
systemctl restart health-app
```

### 10.2 重要路径

| 路径 | 说明 |
|------|------|
| `/opt/health-center/` | 项目根目录 |
| `/opt/health-center/target/*.jar` | 编译后的JAR包 |
| `/opt/health-center/logs/` | 应用日志目录 |
| `/etc/systemd/system/health-app.service` | systemd服务配置 |
| `/var/log/mysql/` | MySQL日志目录 |

### 10.3 重要信息

| 项目 | 值 |
|------|-----|
| 服务器IP | 139.129.108.119 |
| SSH端口 | 22 |
| 应用端口 | 8080 |
| 数据库名 | health_center_db |
| 数据库用户 | health_app |
| 数据库密码 | HealthApp2024! |

---

## 11. 更新日志

| 日期 | 操作 | 说明 |
|------|------|------|
| 2026-02-04 | 初始部署 | 创建简化版后端服务 |
| 2026-02-04 | 服务配置 | systemd服务配置完成 |
| 2026-02-04 | 防火墙配置 | ufw开放8080端口 |
| 2026-02-05 | SSH免密配置 | 配置ED25519密钥免密登录，添加aliyun别名 |
| 2026-02-05 | Redis安装 | 安装并启用Redis缓存服务 |
| 2026-02-05 | RabbitMQ禁用 | 禁用RabbitMQ自动配置（当前不需要） |
| 2026-02-05 | 数据库修复 | 修复user、family_member、health_data表结构 |
| 2026-02-05 | 配置文件修复 | 修复application-dev.yml，从H2切换到MySQL |
| 2026-02-05 | JWT密钥修复 | 更新JWT密钥长度（≥32字符） |
| 2026-02-05 | 验证码优化 | 移除短信验证码必填限制（开发环境） |
| 2026-02-05 | API测试完成 | 所有接口测试通过，创建测试账号 |
| 2026-02-05 | 文档更新 | 创建api-test-guide.md和database-remote.md |

---

*最后更新时间：2026-02-05 晚 - API测试完成并更新文档*
