# 云服务器部署 - 超详细操作手册

> 目标：将后端部署到云服务器，实现APP远程读取健康数据
> 预计时间：1-2小时
> 适用人群：有云服务器但不知道怎么部署的新手

---

## 📋 准备工作

### 开始前请准备好

1. **云服务器** - 阿里云/腾讯云/华为云等
2. **服务器密码** - 购买时设置的root密码
3. **电脑** - Windows/Mac/Linux都可以
4. **手机+数据线** - 用于安装APK测试

### 需要下载的工具

| 工具 | 用途 | 下载地址 |
|------|------|----------|
| **FinalShell** | SSH工具，服务器管理（推荐） | http://www.hostbuf.com/ |
| **PuTTY** | SSH工具（备选） | https://www.putty.org/ |
| **FileZilla** | 文件上传工具（备选） | https://filezilla-project.org/ |

---

## 第一部分：购买云服务器

### 1.1 阿里云购买（推荐）

#### 步骤1：注册/登录阿里云

```
1. 打开浏览器，访问：https://www.aliyun.com/
2. 点击右上角"注册"或"登录"
3. 完成实名认证（需要身份证）
```

#### 步骤2：进入ECS购买页面

```
1. 登录后，搜索"ECS"或点击"产品" → "弹性计算" → "云服务器 ECS"
2. 点击"立即购买"或"创建实例"
```

#### 步骤3：选择配置

**选择以下配置**：

| 配置项 | 选择 | 说明 |
|--------|------|------|
| **付费模式** | 包年包月 | 最省钱 |
| **地域** | 华东1/华北2/华南1 | 离你最近 |
| **实例规格** | 1核2GB入门配置 | 最便宜，够用 |
| **镜像类型** | 系统镜像 | |
| **操作系统** | Ubuntu 22.04 64位 | 推荐 |
| **存储** | 40GB ESSD | 默认即可 |
| **带宽** | 1Mbps | 按量付费最省钱 |
| **购买数量** | 1台 | |
| **购买时长** | 1年或3年 | 3年最划算 |

#### 步骤4：设置密码

```
1. 在"身份认证"部分
2. 选择"自定义密码"
3. 输入密码并确认（记住这个密码！）
4. 格式要求：包含大小写字母+数字+符号，如：Abc@123456
```

#### 步骤5：确认订单

```
1. 点击"确认订单"
2. 查看配置和价格
3. 点击"服务协议"前的复选框
4. 点击"立即购买"
5. 支付（支付宝/微信/网银）
```

#### 步骤6：等待创建完成

```
1. 在"控制台" → "ECS" → "实例"查看
2. 状态变为"运行中"表示创建成功
3. 记下服务器的"公网IP地址"（如：47.98.123.45）
```

---

### 1.2 腾讯云购买（备选）

```
1. 访问：https://cloud.tencent.com/
2. 注册/登录
3. 产品 → 计算 → 云服务器
4. 新建实例
5. 配置类似阿里云
6. 购买
```

---

## 第二部分：配置安全组（非常重要！）

### 2.1 什么是安全组

安全组是虚拟防火墙，控制哪些端口可以访问服务器。如果不配置，外部无法访问你的8080端口！

### 2.2 阿里云配置安全组

#### 步骤1：进入安全组配置

```
1. 登录阿里云控制台
2. 点击"云服务器 ECS"
3. 在左侧找到"实例"
4. 找到你刚购买的服务器，点击"实例ID"
5. 在左侧导航栏找到"安全组"
6. 点击"配置规则"
```

#### 步骤2：添加入方向规则

点击"手动添加"，添加以下规则：

| 规则类型 | 协议类型 | 端口范围 | 授权对象 | 描述 |
|----------|----------|----------|----------|------|
| 入方向 | TCP | 22/22 | 0.0.0.0/0 | SSH远程连接 |
| 入方向 | TCP | 8080/8080 | 0.0.0.0/0 | 后端API服务（必需！） |
| 入方向 | TCP | 80/80 | 0.0.0.0/0 | HTTP（可选） |

**详细操作**：

```
1. 点击"快速添加"或"手动添加"
2. 选择"自定义TCP"
3. 端口填写：22
4. 授权对象填写：0.0.0.0/0
5. 点击"保存"
6. 重复以上步骤，添加8080端口
```

#### 步骤3：确认规则

在安全组规则列表中应该能看到：

```
✓ TCP 22 0.0.0.0/0
✓ TCP 8080 0.0.0.0/0
```

### 2.3 腾讯云配置安全组

```
1. 控制台 → 云服务器
2. 找到你的服务器
3. 点击"更多" → "安全组" → "配置安全组"
4. 添加入站规则：22、8080
```

---

## 第三部分：连接服务器

### 3.1 下载SSH工具（推荐FinalShell）

**为什么推荐FinalShell**：
- 免费且功能强大
- 自带文件传输
- 中文界面，易上手
- 支持SFTP文件上传

#### 下载步骤：

```
1. 访问：http://www.hostbuf.com/
2. 点击"下载"
3. 选择"FinalShell-xxx.exe"（Windows版）
4. 安装（一直点下一步即可）
```

### 3.2 连接服务器

#### 步骤1：打开FinalShell

```
1. 启动FinalShell
2. 点击"SSH连接器"
```

#### 步骤2：填写连接信息

| 选项 | 填写内容 | 示例 |
|------|----------|------|
| **名称** | 随便起个名字 | 我的服务器 |
| **主机** | 你的服务器公网IP | 47.98.123.45 |
| **端口** | 22 | 22 |
| **用户名** | root | root |
| **密码** | 购买时设置的密码 | Abc@123456 |

#### 步骤3：连接

```
1. 点击"确定"
2. 首次连接会提示"保存密钥"，点击"是"
3. 输入密码（不会显示），按回车
4. 连接成功的标志：看到黑底白字的命令行界面
```

#### 连接成功后你会看到：

```
Welcome to Ubuntu 22.04.3 LTS (GNU/Linux 5.15.0-1017-generic x86_64)
 * Documentation:  https://help.ubuntu.com/
 * Management:     https://landscape.canonical.com/getpubkey?pubkey=[system]
Last login: xxx
root@iZj6cxxxxxxx:~#
```

---

## 第四部分：服务器环境配置

### 4.1 更新系统

复制以下命令，粘贴到FinalShell中，按回车执行：

```bash
apt update && apt upgrade -y
```

**说明**：这一步会更新软件包列表，需要等待1-3分钟。

**完成的标志**：出现类似 `[OK] xxx upgraded` 的提示。

### 4.2 安装Java 17

```bash
apt install -y openjdk-17-jdk
```

**说明**：后端需要Java 17运行。

**验证安装**：

```bash
java -version
```

**成功标志**：显示 `openjdk version "17.x.x"`

### 4.3 安装Maven（可选，用于编译）

如果已经上传编译好的JAR包，可以跳过这一步。

```bash
# 下载Maven
cd /opt
wget https://dlcdn.apache.org/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz

# 解压
tar -xzf apache-maven-3.9.6-bin.tar.gz
mv apache-maven-3.9.6 maven

# 设置环境变量
echo 'export M2_HOME=/opt/maven' >> /etc/profile
echo 'export PATH=$M2_HOME/bin:$PATH' >> /etc/profile
source /etc/profile

# 验证
mvn -version
```

### 4.4 安装MySQL

#### 步骤1：安装MySQL服务器

```bash
apt install -y mysql-server
```

#### 步骤2：启动MySQL

```bash
systemctl start mysql
systemctl enable mysql
```

#### 步骤3：设置MySQL root密码

```bash
mysql_secure_installation
```

**操作说明**：

```
1. 提示"VALIDATE PASSWORD COMPONENT"
   → 输入：y

2. 提示设置root密码
   → 输入新密码（记住！）
   → 重复输入

3. 提示删除匿名用户
   → 输入：y

4. 提示禁止root远程登录
   → 输入：n（方便调试）

5. 提示删除test数据库
   → 输入：y

6. 提示重新加载权限表
   → 输入：y
```

### 4.5 创建数据库

```bash
# 登录MySQL
mysql -u root -p
# 输入刚才设置的密码
```

进入MySQL后，复制以下内容（全部复制，一起粘贴）：

```sql
-- 创建数据库
CREATE DATABASE health_center_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建应用用户
CREATE USER 'health_app'@'localhost' IDENTIFIED BY 'Health@123456';

-- 授权
GRANT ALL PRIVILEGES ON health_center_db.* TO 'health_app'@'localhost';

-- 刷新权限
FLUSH PRIVILEGES;

-- 退出MySQL
EXIT;
```

**输入方式**：
```
在MySQL命令行中：
1. 粘贴上面所有内容
2. 或者逐行输入，每行后按回车
```

### 4.6 导入表结构

**方法一：使用FinalShell的文件上传功能**

```
1. 在FinalShell左侧，找到"文件"图标
2. 导航到 /root 目录
3. 点击"上传"
4. 选择项目中的 D:\ReadHealthInfo\database\schema.sql 文件
5. 上传完成后：
```

```bash
# 导入表结构
mysql -u root -p health_center_db < /root/schema.sql
# 输入MySQL密码

# 验证导入
mysql -u root -p health_center_db
# 输入密码后输入：SHOW TABLES;
# 应该看到8个表
EXIT;
```

---

## 第五部分：上传并部署后端代码

### 5.1 上传代码到服务器

**方法一：使用Git（推荐，如果代码在GitHub）**

```bash
# 安装Git
apt install -y git

# 进入工作目录
cd /opt

# 克隆代码（替换为你的仓库地址）
git clone https://gitee.com/xxx/ReadHealthInfo.git
cd ReadHealthInfo/spring-boot-backend
```

**方法二：使用FinalShell直接上传**

```
1. 在FinalShell中导航到 /opt 目录
   cd /opt

2. 点击"新建目录"按钮，创建项目目录
   mkdir ReadHealthInfo
   cd ReadHealthInfo

3. 进入 spring-boot-backend 目录
   （如果目录不存在，点击"新建文件夹"创建）

4. 点击"上传"图标
5. 选择以下文件/文件夹上传：
   - spring-boot-backend 下的所有文件
   - 或者直接上传整个spring-boot-backend文件夹
```

**方法三：打包后上传JAR（最简单）**

1. 在本地Windows电脑上，进入项目目录：

```powershell
cd D:\ReadHealthInfo\spring-boot-backend
```

2. 确保本地有Maven和Java，然后打包：

```powershell
mvn clean package -DskipTests
```

3. 打包完成后，在FinalShell中：

```
1. 创建目录：mkdir -p /opt/health-app
2. 上传文件：
   - 将 D:\ReadHealthInfo\spring-boot-backend\target\backend-1.0.0.jar
   - 上传到服务器的 /opt/health-app/
```

### 5.2 修改配置文件

```bash
# 进入项目目录
cd /opt/ReadHealthInfo/spring-boot-backend

# 编辑配置文件
vi src/main/resources/application.yml
```

**vi编辑器使用**：

```
1. 按 'i' 进入编辑模式
2. 使用方向键移动光标
3. 修改内容
4. 按 'Esc' 退出编辑模式
5. 输入 ':wq' 保存并退出
```

**需要修改的内容**：

找到 `spring.datasource` 部分，修改为：

```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/health_center_db?useSSL=false&serverTimezone=Asia/Shanghai
    username: health_app
    password: Health@123456
```

找到 `app.cors` 部分，确保允许跨域：

```yaml
app:
  cors:
    allowed-origins: '*'  # 或者具体域名
```

### 5.3 配置应用使用外部MySQL

确保配置文件中没有使用H2内存数据库（application-dev.yml）。

修改主配置文件确保使用MySQL：

```bash
# 检查 application.yml
grep -A 5 "spring.profiles.active" src/main/resources/application.yml
```

应该显示 `active: dev`。

如果是 `active: dev`，我们需要检查 `application-dev.yml` 是否配置了MySQL。

```bash
# 查看dev配置
cat src/main/resources/application-dev.yml
```

如果有H2配置，我们改为MySQL。或者直接在主配置中覆盖：

```bash
# 备份原配置
cp src/main/resources/application.yml src/main/resources/application.yml.bak

# 修改主配置，直接使用MySQL
```

### 5.4 重新打包（如果在服务器上编译）

```bash
cd /opt/ReadHealthInfo/spring-boot-backend

# 清理并打包
mvn clean package -DskipTests

# 等待完成（可能需要5-10分钟）
# 完成后会显示：BUILD SUCCESS
```

**如果打包失败**，常见问题：

```
问题1：Maven命令不存在
解决：使用前面上传的本地JAR包，跳过服务器打包

问题2：内存不足
解决：创建swap空间
dd if=/dev/zero of=/swapfile bs=1M count=1024
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
```

### 5.5 启动后端服务

**使用本地打包的JAR（最简单）**：

```bash
# 创建应用目录
mkdir -p /opt/health-app

# 如果JAR已上传，直接启动
cd /opt/health-app

# 后台启动
nohup java -jar backend-1.0.0.jar > app.log 2>&1 &

# 查看日志确认启动
tail -f app.log
```

**按 Ctrl+C 退出日志查看，服务继续运行。**

**使用服务器编译的JAR**：

```bash
cd /opt/ReadHealthInfo/spring-boot-backend

# 后台启动
nohup java -jar target/backend-1.0.0.jar > app.log 2>&1 &

# 查看日志
tail -f app.log
```

**启动成功的标志**：

```
看到类似以下内容表示启动成功：
- Started HealthCenterApplication in xx.xxx seconds
- Tomcat started on port(s): 8080 (http)
- JVM running for ...
```

### 5.6 验证服务

```bash
# 检查端口监听
netstat -tlnp | grep 8080
# 应该显示：tcp  0  0.0.0.0:8080  LISTEN  xxxxx/java

# 测试API（需要先有用户数据）
curl http://localhost:8080/api/health-data
```

---

## 第六部分：配置为系统服务（开机自启）

### 6.1 创建systemd服务文件

```bash
vi /etc/systemd/system/health-app.service
```

**粘贴以下内容**（按 'i' 进入编辑模式，粘贴后按 Esc，输入 ':wq' 保存）：

```ini
[Unit]
Description=Health Center Backend Service
After=network.target mysql.service
Requires=mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/health-app
ExecStart=/usr/bin/java -jar /opt/health-app/backend-1.0.0.jar
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=health-app

[Install]
WantedBy=multi-user.target
```

### 6.2 启动服务

```bash
# 重载systemd配置
systemctl daemon-reload

# 启动服务
systemctl start health-app

# 设置开机自启
systemctl enable health-app

# 查看状态
systemctl status health-app
```

**状态说明**：

```
● health-app.service - Health Center Backend Service
   Loaded: loaded (/etc/systemd/system/health-app.service; enabled)
   Active: active (running) since xxx  ← active (running)表示运行中
```

### 6.3 服务管理命令

```bash
# 启动服务
systemctl start health-app

# 停止服务
systemctl stop health-app

# 重启服务
systemctl restart health-app

# 查看状态
systemctl status health-app

# 查看实时日志
journalctl -u health-app -f

# 查看最近100行日志
journalctl -u health-app -n 100
```

---

## 第七部分：前端配置与测试

### 7.1 修改前端API地址

#### 步骤1：打开项目文件

用记事本或VSCode打开：

```
D:\ReadHealthInfo\flutter-app\lib\main.dart
```

#### 步骤2：找到API配置

找到 `AppConstants` 类，大约在第195行左右：

```dart
class AppConstants {
  // API 配置
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
```

#### 步骤3：修改默认地址

将 defaultValue 改为你的服务器地址：

```dart
defaultValue: 'http://你的服务器公网IP:8080',
// 例如：defaultValue: 'http://47.98.123.45:8080',
```

**保存文件。**

### 7.2 重新编译APK

#### 步骤1：打开命令行

在 `D:\ReadHealthInfo\flutter-app` 目录下打开PowerShell或CMD。

#### 步骤2：编译

```powershell
# 清理旧编译
flutter clean

# 获取依赖
flutter pub get

# 编译Debug APK
flutter build apk --debug
```

**编译成功标志**：

```
Running Gradle task 'assembleDebug'...
√ Built build\app\outputs\flutter-apk\app-debug.apk
```

**编译时间**：首次2-3分钟，后续10-20秒。

### 7.3 安装到手机测试

#### 步骤1：手机连接电脑

```
1. 用USB数据线连接手机和电脑
2. 手机开启"开发者选项"和"USB调试"
```

#### 步骤2：安装APK

```powershell
# 安装
adb devices  # 查看连接的设备
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

**Success 表示安装成功。**

#### 步骤3：启动应用

```powershell
adb shell monkey -p com.healthcenter.health_center_app -c android.intent.category.LAUNCHER 1
```

或者直接在手机上点击APP图标。

### 7.4 测试远程访问

#### 测试步骤：

```
1. 打开APP
2. 点击"体验模式"进入
3. 或者注册/登录一个账号
4. 点击底部第3个Tab"健康"（心形图标）
5. 点击右上角"刷新"按钮
6. 应该能看到加载动画，然后显示健康数据
```

#### 成功的标志：

```
✓ 刷新按钮显示加载动画（转圈）
✓ 没有降级到模拟数据
✓ 服务器日志中有API请求记录
```

---

## 第八部分：添加测试数据（可选）

如果数据库是空的，需要添加测试数据：

### 8.1 添加用户

```bash
# 连接数据库
mysql -u root -p health_center_db
# 输入密码
```

```sql
-- 添加测试用户
INSERT INTO user (username, password, phone, nickname, gender, created_at, updated_at)
VALUES
('13800138000', '$2a$10$xxxxxxxxxxxxx', '13800138000', '测试用户', 1, NOW(), NOW());
-- 注意：密码需要用BCrypt加密，实际使用时通过注册接口添加
```

### 8.2 添加家庭成员

```sql
-- 添加家庭成员（假设用户ID为1）
INSERT INTO family_member (user_id, name, relation, role, gender, created_at, updated_at)
VALUES
(1, '张三', 'father', 'admin', 1, NOW(), NOW()),
(1, '李四', 'mother', 'admin', 2, NOW(), NOW());
```

### 8.3 添加健康数据

```sql
-- 添加血压数据
INSERT INTO health_data (user_id, member_id, data_type, value1, value2, level, measure_time, data_source, created_at, updated_at)
VALUES
(1, 1, 'blood_pressure', 125, 82, 'normal', NOW(), 'manual', NOW(), NOW()),
(1, 1, 'blood_pressure', 118, 78, 'normal', DATE_SUB(NOW(), INTERVAL 1 DAY), 'manual', NOW(), NOW()),
(1, 2, 'blood_pressure', 135, 88, 'warning', NOW(), 'manual', NOW(), NOW());

-- 添加血糖数据
INSERT INTO health_data (user_id, member_id, data_type, value1, level, measure_time, data_source, created_at, updated_at)
VALUES
(1, 1, 'blood_sugar', 6.2, 'normal', NOW(), 'manual', NOW(), NOW()),
(1, 1, 'blood_sugar', 7.8, 'warning', DATE_SUB(NOW(), INTERVAL 6 HOUR), 'manual', NOW(), NOW());
```

---

## 第九部分：故障排查

### 9.1 无法连接服务器

**检查清单**：

```
1. 服务器是否运行中？
   → 登录阿里云控制台查看ECS实例状态

2. 安全组是否配置？
   → 检查22、8080端口是否开放

3. 密码是否正确？
   → 重新尝试连接，复制粘贴密码避免错误

4. 服务器IP是否正确？
   → 复制公网IP，不要用内网IP
```

### 9.2 服务启动失败

```bash
# 查看错误日志
tail -100 /opt/health-app/app.log

# 或使用systemd查看日志
journalctl -u health-app -n 100 --no-pager
```

**常见错误**：

```
错误1：Connection refused
原因：MySQL未启动
解决：systemctl start mysql

错误2：Access denied for user
原因：数据库密码错误
解决：修改application.yml中的数据库密码

错误3：Address already in use
原因：8080端口被占用
解决：kill -9 $(lsof -t -i:8080)
```

### 9.3 APP无法获取数据

```bash
# 1. 检查服务是否运行
curl http://localhost:8080/api/health-data

# 2. 检查数据库
mysql -u root -p
USE health_center_db;
SELECT COUNT(*) FROM health_data;

# 3. 查看服务器日志
tail -f /opt/health-app/app.log
```

### 9.4 防火墙问题

```bash
# 检查防火墙
ufw status

# 如果是inactive，需要开放端口
ufw allow 8080
ufw allow 22
ufw enable

# 如果是active，检查规则
ufw status numbered
```

---

## 第十部分：安全加固（重要！）

### 10.1 修改SSH端口（防止被扫描攻击）

```bash
# 备份SSH配置
cp /etc/ssh/sshd_config /etc/ssh_config.bak

# 编辑配置
vi /etc/ssh/sshd_config

# 修改以下内容：
Port 22222                    # 改为其他端口
PermitRootLogin no           # 禁止root直接登录
PasswordAuthentication yes   # 如果有密钥可设为no

# 重启SSH服务
systemctl restart sshd
```

**注意**：修改后需要：

```
1. 在安全组中添加新端口22222
2. 下次连接用：ssh -p 22222 root@你的IP
```

### 10.2 配置防火墙

```bash
# 启用防火墙
ufw enable

# 允许SSH
ufw allow 22/tcp

# 允许HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# 允许后端API
ufw allow 8080/tcp

# 查看状态
ufw status verbose
```

### 10.3 设置数据库自动备份

```bash
# 创建备份目录
mkdir -p /backup

# 创建备份脚本
vi /usr/local/bin/backup_db.sh
```

**粘贴以下内容**：

```bash
#!/bin/bash
BACKUP_DIR="/backup"
DB_USER="root"
DB_PASS="你的密码"
DB_NAME="health_center_db"
DATE=$(date +%Y%m%d_%H%M%S)

# 备份数据库
mysqldump -u$DB_USER -p$DB_PASS $DB_NAME | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# 删除7天前的备份
find $BACKUP_DIR -name "db_*.sql.gz" -mtime +7 -delete
```

```bash
# 添加执行权限
chmod +x /usr/local/bin/backup_db.sh

# 添加到crontab（每天凌晨2点备份）
crontab -e
```

**在文件末尾添加**：

```
0 2 * * * /usr/local/bin/backup_db.sh
```

### 10.4 安装Fail2ban防暴力破解

```bash
# 安装Fail2ban
apt install -y fail2ban

# 启动服务
systemctl start fail2ban
systemctl enable fail2ban

# 查看状态
systemctl status fail2ban
```

---

## 第十一部分：域名配置（可选）

### 11.1 购买域名

```
推荐服务商：
- 阿里云万网
- 腾讯云
- GoDaddy
- Namecheap
```

### 11.2 配置DNS解析

```
1. 登录域名管理控制台
2. 找到"DNS解析"或"域名解析"
3. 添加A记录：
   - 主机记录：@
   - 记录类型：A
   - 记录值：你的服务器公网IP
   - TTL：600
4. 等待生效（10分钟-24小时）
```

### 11.3 安装Nginx（HTTPS）

```bash
# 安装Nginx
apt install -y nginx

# 安装Certbot（免费SSL证书）
apt install -y certbot python3-certbot-nginx

# 申请证书
certbot --nginx -d api.yourdomain.com

# 自动配置HTTPS
```

### 11.4 配置反向代理

```bash
# 编辑Nginx配置
vi /etc/nginx/sites-available/default
```

**修改location / 部分**：

```nginx
location / {
    proxy_pass http://localhost:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

```bash
# 测试配置
nginx -t

# 重载Nginx
systemctl reload nginx
```

### 11.5 修改前端使用域名

```dart
defaultValue: 'https://api.yourdomain.com',
```

重新编译APK并安装。

---

## 完成检查清单

部署完成后，请逐项检查：

- [ ] 服务器已购买并正常运行
- [ ] 安全组已开放22、8080端口
- [ ] 可以通过SSH连接服务器
- [ ] Java 17已安装
- [ ] MySQL已安装并创建数据库
- [ ] 数据库表结构已导入
- [ ] 后端JAR包已上传
- [ ] 后端服务正常启动
- [ ] curl http://服务器IP:8080/api/health-data 有返回
- [ ] 前端API地址已修改
- [ ] APP已重新编译并安装
- [ ] APP能正常显示远程健康数据
- [ ] 防火墙已配置
- [ ] 数据库自动备份已设置

---

## 紧急联系

如果遇到问题：

```
1. 查看服务器日志：tail -f /opt/health-app/app.log
2. 查看系统日志：journalctl -xe
3. 重启后端服务：systemctl restart health-app
4. 重启服务器：reboot
```

---

**祝您部署顺利！有任何问题随时联系小弟！**
