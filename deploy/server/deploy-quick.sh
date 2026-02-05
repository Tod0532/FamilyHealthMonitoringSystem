#!/bin/bash
# ============================================================================
# 快速部署脚本 - 仅用于已配置好环境的场景
# ============================================================================

set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}[INFO]${NC} 快速部署健康中心后端..."

# 创建目录
mkdir -p /opt/health-center/{logs,uploads}

# 检查JAR包
if [ ! -f "/opt/health-center/backend.jar" ]; then
    echo "请先将编译好的JAR包上传到: /opt/health-center/backend.jar"
    exit 1
fi

# 导入数据库（如果还没导入）
if [ -f "/opt/health-center/schema.sql" ]; then
    echo "导入数据库表结构..."
    mysql -u root health_center_db < /opt/health-center/schema.sql 2>/dev/null || echo "数据库可能已初始化"
fi

# 配置systemd服务
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

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable health-app
systemctl restart health-app

echo -e "${GREEN}[INFO]${NC} 服务已启动!"
echo "查看状态: systemctl status health-app"
echo "查看日志: journalctl -u health-app -f"
