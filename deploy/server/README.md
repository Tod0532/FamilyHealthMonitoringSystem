# 家庭健康中心APP - 云服务器部署包

本目录包含云服务器部署所需的全部配置文件和脚本。

## 文件说明

| 文件 | 说明 |
|------|------|
| `deploy.sh` | 完整一键部署脚本（包含环境安装） |
| `deploy-quick.sh` | 快速部署脚本（适用于已有环境） |
| `application-prod.yml` | 生产环境配置文件 |
| `health-app.service` | systemd服务配置文件 |
| `schema.sql` | 数据库表结构（需从项目根目录复制） |

---

## 快速部署指南

### 方式一：完整部署（首次）

**1. 连接服务器**
```bash
ssh root@172.20.252.13
```

**2. 上传部署文件**
```bash
# 在本地Windows PowerShell执行
scp -r D:\ReadHealthInfo\deploy\server root@172.20.252.13:/tmp/deploy
scp D:\ReadHealthInfo\database\schema.sql root@172.20.252.13:/tmp/deploy
```

**3. 上传后端JAR包**
```bash
# 先在本地编译后端（如果还没编译）
cd D:\ReadHealthInfo\spring-boot-backend
mvn clean package -DskipTests

# 上传JAR包
scp target/backend-1.0.0.jar root@172.20.252.13:/opt/health-center/backend.jar
```

**4. 在服务器上执行部署**
```bash
# 进入部署目录
cd /tmp/deploy

# 复制文件到目标位置
mkdir -p /opt/health-center
cp schema.sql /opt/health-center/
cp application-prod.yml /opt/health-center/

# 执行部署脚本
chmod +x deploy.sh
bash deploy.sh
```

### 方式二：快速部署（已有Java+MySQL环境）

```bash
# 1. 上传文件
scp target/backend-1.0.0.jar root@172.20.252.13:/opt/health-center/backend.jar
scp D:\ReadHealthInfo\deploy\server\deploy-quick.sh root@172.20.252.13:/tmp/

# 2. 在服务器执行
ssh root@172.20.252.13
bash /tmp/deploy-quick.sh
```

---

## 部署完成后

### 测试API
```bash
# 在服务器上测试
curl http://localhost:8080/api/health-data

# 在本地测试
curl http://172.20.252.13:8080/api/health-data
```

### 服务管理
```bash
# 查看状态
systemctl status health-app

# 启动服务
systemctl start health-app

# 停止服务
systemctl stop health-app

# 重启服务
systemctl restart health-app

# 查看日志
journalctl -u health-app -f
tail -f /opt/health-center/logs/console.log
```

---

## 安全组配置

**重要！** 确保云服务器安全组已开放以下端口：

| 端口 | 说明 |
|------|------|
| 22 | SSH |
| 8080 | 后端API服务 |

---

## 数据库信息

```
数据库名: health_center_db
用户名: health_app
密码: HealthApp2024!
```

如需修改密码，请同步修改 `application-prod.yml` 中的配置。

---

## 常见问题

### 1. 服务启动失败
```bash
# 查看详细日志
journalctl -u health-app -n 100 --no-pager
```

### 2. 数据库连接失败
```bash
# 检查MySQL状态
systemctl status mysql

# 检查数据库是否存在
mysql -u root -e "SHOW DATABASES;"
```

### 3. 端口无法访问
```bash
# 检查服务是否监听
netstat -tlnp | grep 8080

# 检查防火墙
ufw status
```
