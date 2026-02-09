@echo off
REM ========================================
REM Flutter Android Release APK 打包脚本
REM ========================================

echo ========================================
echo  Flutter Android Release Build Script
REM ========================================
echo.

REM 设置颜色
color 0A

echo [步骤 1/4] 检查环境...
echo.

REM 检查 Flutter 是否安装
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] Flutter 未安装或未添加到 PATH
    pause
    exit /b 1
)

echo [OK] Flutter 已安装
flutter --version
echo.

echo [步骤 2/4] 清理旧的构建文件...
echo.
call flutter clean
if %errorlevel% neq 0 (
    echo [错误] 清理失败
    pause
    exit /b 1
)
echo [OK] 清理完成
echo.

echo [步骤 3/4] 获取依赖包...
echo.
call flutter pub get
if %errorlevel% neq 0 (
    echo [错误] 获取依赖失败
    pause
    exit /b 1
)
echo [OK] 依赖获取完成
echo.

echo [步骤 4/4] 构建 Release APK...
echo.
echo 正在构建 APK，请稍候...
echo.

REM 构建 APK（分为 arm64-v8a, armeabi-v7a, 和 universal）
echo [1/3] 构建 arm64-v8a 架构 APK...
call flutter build apk --release --target-platform android-arm64
if %errorlevel% neq 0 (
    echo [错误] 构建失败
    pause
    exit /b 1
)
echo [OK] arm64-v8a APK 构建完成
echo.

echo [2/3] 构建 armeabi-v7a 架构 APK...
call flutter build apk --release --target-platform android-arm
if %errorlevel% neq 0 (
    echo [错误] 构建失败
    pause
    exit /b 1
)
echo [OK] armeabi-v7a APK 构建完成
echo.

echo [3/3] 构建 universal APK（包含所有架构）...
call flutter build apk --release
if %errorlevel% neq 0 (
    echo [错误] 构建失败
    pause
    exit /b 1
)
echo [OK] Universal APK 构建完成
echo.

echo ========================================
echo  构建完成！
echo ========================================
echo.
echo APK 文件位置：
echo   - ARM64: build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
echo   - ARM32: build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk
echo   - 通用版: build\app\outputs\flutter-apk\app-release.apk
echo.
echo 提示：通用版APK体积较大但兼容性更好，ARM64版本体积最小性能最好
echo.

REM 询问是否打开输出目录
set /p opendir="是否打开输出目录？(Y/N): "
if /i "%opendir%"=="Y" (
    explorer build\app\outputs\flutter-apk
)

pause
