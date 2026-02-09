@echo off
REM ========================================
REM Flutter Android App Bundle 打包脚本
REM 用于上传到 Google Play Store
REM ========================================

echo ========================================
echo  Flutter Android App Bundle Build Script
echo ========================================
echo.

color 0B

echo [步骤 1/4] 检查环境...
echo.

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

echo [步骤 4/4] 构建 App Bundle (AAB)...
echo.
echo 正在构建 AAB，请稍候...
echo.

REM 构建 App Bundle
call flutter build appbundle --release
if %errorlevel% neq 0 (
    echo [错误] 构建失败
    pause
    exit /b 1
)
echo [OK] App Bundle 构建完成
echo.

echo ========================================
echo  构建完成！
echo ========================================
echo.
echo AAB 文件位置：
echo   build\app\outputs\bundle\release\app-release.aab
echo.
echo 此文件用于上传到 Google Play Store
echo.

REM 询问是否打开输出目录
set /p opendir="是否打开输出目录？(Y/N): "
if /i "%opendir%"=="Y" (
    explorer build\app\outputs\bundle\release
)

pause
