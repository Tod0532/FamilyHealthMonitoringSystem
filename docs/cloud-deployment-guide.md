# 云服务器部署指南

> 本文档详细说明如何将家庭健康中心APP后端部署到云服务器，实现远程数据访问。

---

## 📋 目录

1. [服务器选择](#1-服务器选择)
2. [服务器购买](#2-服务器购买)
3. [安全组配置](#3-安全组配置)
4. [服务器环境配置](#4-服务器环境配置)
5. [数据库安装](#5-数据库安装)
6. [后端部署](#6-后端部署)
7. [域名配置](#7-域名配置-可选)
8. [前端配置](#8-前端配置)
9. [测试验证](#9-测试验证)

---

## 1. 服务器选择

### 推荐配置

| 配置项 | 最低配置 | 推荐配置 |
|--------|----------|----------|
| CPU | 1核 | 2核 |
| 内存 | 1GB | 2GB |
| 带宽 | 1Mbps | 3Mbps |
| 系统 | Ubuntu 20.04/22.04 | Ubuntu 22.04 LTS |
| 存储 | 40GB SSD | 40GB SSD |

### 推荐云服务商

| 服务商 | 价格 | 优势 |
|--------|------|------|
| **阿里云** | ~60-100元/月 | 国内速度快，学生优惠 |
| **腾讯云** | ~50-90元/月 | 稳定可靠，有免费额度 |
| **华为云** | ~55-95元/月 | 企业级服务 |
| **轻量应用服务器** | ~50元/月起 | 配置简单，开箱即用 |

---

## 2. 服务器购买

### 2.1 阿里云ECS购买步骤

1. **访问阿里云官网**
   ```
   https://www.aliyun.com/
   ```

2. **进入ECS页面**
   - 产品 → 弹性计算 → 云服务器 ECS

3. **创建实例**
   - 付费模式：包年包月（推荐）
   - 地域：选择离您最近的区域
   - 实例规格：1核2GB或2核4GB
   - 镜像：Ubuntu 22.04 64位
   - 存储：40GB ESSD
   - 网络：专有网络VPC（默认即可）

4. **购买时长**
   - 建议购买1年或3年（有优惠）

### 2.2 额外购买（可选）

| 服务 | 价格 | 说明 |
|------|------|------|
| 域名 | 50-100元/年 | 如需访问自己的域名 |
| SSL证书 | 免费 | Let's Encrypt提供 |
| 数据库RDS | 另计 | 可用自建MySQL |

---

## 3. 安全组配置

### 3.1 什么是安全组

安全组相当于虚拟防火墙，控制服务器的入站/出站流量。

### 3.2 必需开放的端口

| 协议 | 端口 | 说明 | 来源 |
|------|------|------|------|
| TCP | **22** | SSH远程登录 | 0.0.0.0/0 或 你的IP |
| TCP | **80** | HTTP（可选） | 0.0.0.0/0 |
| TCP | **443** | HTTPS（可选） | 0.0.0.0/0 |
| TCP | **8080** | **后端API服务** | 0.0.0.0/0 |
| TCP | **3306** | MySQL（仅内网） | 服务器IP |

### 3.3 配置步骤（阿里云示例）

1. 进入ECS控制台
2. 点击"实例" → 找到你的服务器
3. 点击"更多" → "网络和安全组" → "安全组配置"
4. 添加入方向规则：
   - 端口 22/22，授权对象 0.0.0.0/0
   - 端口 8080/8080，授权对象 0.0.0.0/0

---

## 4. 服务器环境配置

### 4.1 连接服务器

**Windows用户下载SSH工具**：
- PuTTY: https://www.putty.org/
- 或使用 Windows Terminal / PowerShell

```powershell
# PowerShell 连接命令
ssh root@你的服务器公网IP
```

**首次连接提示**：
```
The authenticity of host 'xxx' can't be established.
Are you sure you want to continue connecting (yes/no)? yes
```

### 4.2 基础环境安装

```bash
# 更新系统
apt update && apt upgrade -y

# 安装必要工具
apt install -y curl wget vim git unzip

# 安装Java 17（后端需要）
apt install -y openjdk-17-jdk

# 验证Java安装
java -version
# 应显示: openjdk version "17.x.x"
```

### 4.3 安装Maven

```bash
# 下载Maven
cd /opt
wget https://dlcdn.apache.org/maven/maven-3/3.9.5/binaries/apache-maven-3.9.5-bin.tar.gz

# 解压
tar -xzf apache-maven-3.9.5-bin.tar.gz

# 重命名
mv apache-maven-3.9.5 maven

# 设置环境变量
echo 'export M2_HOME=/opt/maven' >> /etc/profile
echo 'export PATH=$M2_HOME/bin:$PATH' >> /etc/profile
source /etc/profile

# 验证
mvn -version
```

---

## 5. 数据库安装

### 方案A：使用MySQL（推荐）

```bash
# 1. 安装MySQL
apt install -y mysql-server

# 2. 启动MySQL服务
systemctl start mysql
systemctl enable mysql

# 3. 安全配置
mysql_secure_installation
# 按提示设置root密码

# 4. 创建数据库和用户
mysql -u root -p
```

```sql
-- 在MySQL命令行中执行
CREATE DATABASE health_center_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建应用用户
CREATE USER 'health_app'@'localhost' IDENTIFIED BY 'YourStrongPassword123!';

-- 授权
GRANT ALL PRIVILEGES ON health_center_db.* TO 'health_app'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

```bash
# 5. 导入表结构
# 将项目的 schema.sql 上传到服务器
mysql -u root -p health_center_db < /root/schema.sql
```

### 方案B：使用内嵌H2（简单，无需安装MySQL）

修改 `application.yml` 使用H2内存数据库，适合开发测试。

---

## 6. 后端部署

### 6.1 上传代码到服务器

**方式一：使用Git（推荐）**

```bash
# 安装Git
apt install -y git

# 克隆代码（如果代码在GitHub/Gitee）
cd /opt
git clone 你的代码仓库地址
cd ReadHealthInfo/spring-boot-backend
```

**方式二：使用SCP上传**

```powershell
# 在Windows PowerShell中执行
scp -r D:\ReadHealthInfo\spring-boot-backend root@你的服务器IP:/opt/
```

### 6.2 修改配置文件

```bash
cd /opt/ReadHealthInfo/spring-boot-backend
vi src/main/resources/application.yml
```

修改数据库配置：

```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/health_center_db?useSSL=false&serverTimezone=Asia/Shanghai
    username: health_app
    password: YourStrongPassword123!

server:
  port: 8080

app:
  cors:
    allowed-origins: '*'  # 生产环境建议指定具体域名
```

### 6.3 编译打包

```bash
# 清理并打包
mvn clean package -DskipTests

# 生成的JAR包位置
ls -lh target/*.jar
```

### 6.4 启动服务

```bash
# 方式一：直接运行
java -jar target/backend-1.0.0.jar

# 方式二：后台运行
nohup java -jar target/backend-1.0.0.jar > app.log 2>&1 &

# 方式三：使用systemd服务（推荐）
vi /etc/systemd/system/health-app.service
```

写入以下内容：

```ini
[Unit]
Description=Health Center Backend Service
After=network.target mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ReadHealthInfo/spring-boot-backend
ExecStart=/usr/bin/java -jar /opt/ReadHealthInfo/spring-boot-backend/target/backend-1.0.0.jar
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

启动服务：

```bash
# 重载systemd配置
systemctl daemon-reload

# 启动服务
systemctl start health-app

# 开机自启
systemctl enable health-app

# 查看状态
systemctl status health-app

# 查看日志
journalctl -u health-app -f
```

### 6.5 验证服务启动

```bash
# 检查端口监听
netstat -tlnp | grep 8080

# 测试API
curl http://localhost:8080/api/health-data
```

---

## 7. 域名配置（可选）

### 7.1 购买域名

| 服务商 | 价格 |
|--------|------|
| 阿里云 | 约50-100元/年 |
| 腾讯云 | 约50-100元/年 |
| Namecheap | 约50元/年 |

### 7.2 配置DNS解析

1. 进入域名服务商的DNS控制台
2. 添加A记录：
   - 主机记录：`@` 或 `api`
   - 记录值：你的服务器公网IP
   - TTL：600

### 7.3 配置反向代理（Nginx）

```bash
# 安装Nginx
apt install -y nginx

# 配置文件
vi /etc/nginx/sites-available/health-api
```

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;  # 改为你的域名

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# 启用配置
ln -s /etc/nginx/sites-available/health-api /etc/nginx/sites-enabled/

# 测试配置
nginx -t

# 重载Nginx
systemctl reload nginx
```

---

## 8. 前端配置

### 8.1 修改API地址

编辑 `flutter-app/lib/main.dart`：

```dart
class AppConstants {
  static const String baseUrl = 'http://你的服务器IP:8080';
  // 如果有域名: static const String baseUrl = 'https://api.yourdomain.com';
}
```

### 8.2 重新编译APK

```powershell
# 指定API地址编译
cd D:\ReadHealthInfo\flutter-app

# 使用服务器IP
flutter build apk --dart-define=BASE_URL=http://你的服务器IP:8080

# 或使用域名
flutter build apk --dart-define=BASE_URL=https://api.yourdomain.com
```

### 8.3 安装测试

```powershell
# 安装新APK
C:\Users\m\AppData\Local\Android\Sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-debug.apk
```

---

## 9. 测试验证

### 9.1 后端API测试

```bash
# 1. 测试健康数据接口（需要先登录获取Token）
curl -X GET http://你的服务器IP:8080/api/health-data

# 2. 查看后端日志
tail -f /opt/ReadHealthInfo/spring-boot-backend/logs/health-center.log
```

### 9.2 前端APP测试

1. 打开APP，点击"体验模式"进入
2. 登录或注册账号
3. 进入"健康"Tab
4. 点击"刷新"按钮
5. 应该能看到从服务器获取的数据

### 9.3 常见问题排查

| 问题 | 解决方案 |
|------|----------|
| 无法连接服务器 | 检查安全组8080端口是否开放 |
| 连接超时 | 检查服务器防火墙：`ufw allow 8080` |
| 数据为空 | 检查数据库是否有数据，手动添加测试数据 |
| 401错误 | 检查JWT配置，确认登录接口正常 |

---

## 10. 安全加固（重要）

```bash
# 1. 配置防火墙
ufw enable
ufw allow ssh
ufw allow 8080
ufw allow 80
ufw allow 443

# 2. 禁止root远程SSH（推荐）
vi /etc/ssh/sshd_config
# 修改: PermitRootLogin no
systemctl restart sshd

# 3. 定期备份数据库
# 添加到crontab
crontab -e
# 每天凌晨2点备份
0 2 * * * mysqldump -u root -p密码 health_center_db > /backup/db_$(date +\%Y\%m\%d).sql
```

---

## 📝 快速检查清单

部署完成后请确认：

- [ ] 服务器已购买并能SSH连接
- [ ] 安全组已开放8080端口
- [ ] Java 17已安装
- [ ] MySQL已安装并创建数据库
- [ ] 后端JAR包已上传并启动
- [ ] curl http://服务器IP:8080/api/health-data 有返回
- [ ] 前端APK已更新API地址
- [ ] APP能正常显示远程健康数据

---

*部署过程中遇到问题，请查看日志或联系技术支持*
