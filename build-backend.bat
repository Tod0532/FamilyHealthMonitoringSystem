@echo off
chcp 65001 >nul
echo ========================================
echo 正在编译后端...
echo ========================================
cd /d D:\ReadHealthInfo\spring-boot-backend
D:\apache-maven-3.9.0\bin\mvn.cmd clean package -DskipTests

if %errorlevel% equ 0 (
    echo ========================================
    echo 编译成功！
    echo ========================================
    echo.
    echo 按任意键启动后端服务...
    pause >nul

    echo 正在停止旧的 Java 进程...
    taskkill /F /IM java.exe >nul 2>&1

    echo 正在启动后端服务...
    start java -jar target\health-center-backend-1.0.0.jar --spring.profiles.active=dev

    echo 后端服务已启动！
    timeout /t 3 >nul
    echo.
    echo 测试服务状态...
    curl -s http://localhost:8080/actuator/health || echo 请检查日志
) else (
    echo ========================================
    echo 编译失败！请检查错误信息
    echo ========================================
    pause
)
