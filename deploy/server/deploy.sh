#!/bin/bash
# ============================================================================
# 家庭健康中心APP - 云服务器一键部署脚本
# 适用于: Ubuntu 20.04/22.04, Debian 10+
# 执行方式: bash deploy.sh
# ============================================================================

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root用户执行此脚本"
        exit 1
    fi
}

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        log_info "检测到操作系统: $OS $OS_VERSION"
    else
        log_error "无法检测操作系统类型"
        exit 1
    fi
}

# 更新系统
update_system() {
    log_info "更新系统软件包..."
    apt update && apt upgrade -y
}

# 安装Java 17
install_java() {
    if command -v java &> /dev/null; then
        log_info "Java已安装: $(java -version 2>&1 | head -n 1)"
    else
        log_info "安装Java 17..."
        apt install -y openjdk-17-jdk
        log_info "Java安装完成: $(java -version 2>&1 | head -n 1)"
    fi
}

# 安装MySQL
install_mysql() {
    if command -v mysql &> /dev/null; then
        log_info "MySQL已安装"
    else
        log_info "安装MySQL..."
        apt install -y mysql-server
        systemctl start mysql
        systemctl enable mysql
        log_info "MySQL安装完成"
    fi
}

# 配置数据库
setup_database() {
    log_info "配置数据库..."

    # 数据库配置
    DB_NAME="health_center_db"
    DB_USER="health_app"
    DB_PASS="HealthApp2024!"

    # 创建数据库和用户
    mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

    log_info "数据库配置完成: ${DB_NAME}"

    # 导入表结构
    if [ -f "/opt/health-center/schema.sql" ]; then
        log_info "导入数据库表结构..."
        mysql -u root ${DB_NAME} < /opt/health-center/schema.sql
        log_info "数据库表结构导入完成"
    else
        log_warn "未找到schema.sql文件，请手动导入数据库结构"
    fi
}

# 创建应用目录
create_app_dir() {
    log_info "创建应用目录..."
    mkdir -p /opt/health-center
    mkdir -p /opt/health-center/logs
    mkdir -p /opt/health-center/uploads
    chmod -R 755 /opt/health-center
}

# 部署应用
deploy_app() {
    log_info "部署应用..."

    # 检查JAR包
    if [ ! -f "/opt/health-center/backend.jar" ]; then
        log_warn "未找到backend.jar，请将编译好的JAR包上传到 /opt/health-center/backend.jar"
        log_info "您可以使用以下命令上传:"
        log_info "  scp spring-boot-backend/target/*.jar root@YOUR_SERVER_IP:/opt/health-center/backend.jar"
        return
    fi

    # 复制配置文件
    if [ -f "/opt/health-center/application-prod.yml" ]; then
        log_info "配置文件已就位"
    else
        log_warn "未找到application-prod.yml配置文件"
    fi
}

# 配置systemd服务
setup_systemd() {
    log_info "配置systemd服务..."

    cat > /etc/systemd/system/health-app.service <<'EOF'
[Unit]
Description=Health Center Backend Service
After=network.target mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/health-center
ExecStart=/usr/bin/java -jar /opt/health-center/backend.jar --spring.profiles.active=prod
Restart=always
RestartSec=10
StandardOutput=append:/opt/health-center/logs/console.log
StandardError=append:/opt/health-center/logs/error.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable health-app
    log_info "systemd服务配置完成"
}

# 配置防火墙
setup_firewall() {
    log_info "配置防火墙..."

    if command -v ufw &> /dev/null; then
        ufw allow 22/tcp comment 'SSH'
        ufw allow 8080/tcp comment 'Health API'
        ufw --force enable
        log_info "防火墙配置完成"
    else
        log_warn "未检测到ufw防火墙，跳过配置"
    fi
}

# 启动服务
start_service() {
    log_info "启动健康中心服务..."
    systemctl start health-app
    sleep 3

    if systemctl is-active --quiet health-app; then
        log_info "服务启动成功!"
        systemctl status health-app --no-pager
    else
        log_error "服务启动失败，请查看日志:"
        log_info "  journalctl -u health-app -n 50"
        log_info "  tail -f /opt/health-center/logs/console.log"
    fi
}

# 显示部署信息
show_info() {
    log_info "=========================================="
    log_info "部署完成!"
    log_info "=========================================="
    log_info "服务管理命令:"
    log_info "  启动服务: systemctl start health-app"
    log_info "  停止服务: systemctl stop health-app"
    log_info "  重启服务: systemctl restart health-app"
    log_info "  查看状态: systemctl status health-app"
    log_info "  查看日志: journalctl -u health-app -f"
    log_info ""
    log_info "API测试:"
    log_info "  curl http://localhost:8080/api/health-data"
    log_info ""
    log_info "数据库信息:"
    log_info "  数据库名: health_center_db"
    log_info "  用户名: health_app"
    log_info "  密码: HealthApp2024!"
    log_info "=========================================="
}

# 主函数
main() {
    log_info "开始部署家庭健康中心后端服务..."
    log_info "=========================================="

    check_root
    detect_os
    update_system
    install_java
    install_mysql
    create_app_dir
    setup_database
    deploy_app
    setup_systemd
    setup_firewall
    start_service
    show_info
}

# 执行主函数
main
