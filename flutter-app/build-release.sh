#!/bin/bash
# ========================================
# Flutter Android Release APK 打包脚本
# ========================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Flutter Android Release Build Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 步骤 1: 检查环境
echo -e "${YELLOW}[步骤 1/4] 检查环境...${NC}"
echo ""

if ! command -v flutter &> /dev/null; then
    echo -e "${RED}[错误] Flutter 未安装或未添加到 PATH${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Flutter 已安装${NC}"
flutter --version
echo ""

# 步骤 2: 清理旧的构建文件
echo -e "${YELLOW}[步骤 2/4] 清理旧的构建文件...${NC}"
echo ""
flutter clean
if [ $? -ne 0 ]; then
    echo -e "${RED}[错误] 清理失败${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] 清理完成${NC}"
echo ""

# 步骤 3: 获取依赖包
echo -e "${YELLOW}[步骤 3/4] 获取依赖包...${NC}"
echo ""
flutter pub get
if [ $? -ne 0 ]; then
    echo -e "${RED}[错误] 获取依赖失败${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] 依赖获取完成${NC}"
echo ""

# 步骤 4: 构建 Release APK
echo -e "${YELLOW}[步骤 4/4] 构建 Release APK...${NC}"
echo ""
echo "正在构建 APK，请稍候..."
echo ""

# 构建 APK（分为 arm64-v8a, armeabi-v7a, 和 universal）
echo -e "${YELLOW}[1/3] 构建 arm64-v8a 架构 APK...${NC}"
flutter build apk --release --target-platform android-arm64
if [ $? -ne 0 ]; then
    echo -e "${RED}[错误] 构建失败${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] arm64-v8a APK 构建完成${NC}"
echo ""

echo -e "${YELLOW}[2/3] 构建 armeabi-v7a 架构 APK...${NC}"
flutter build apk --release --target-platform android-arm
if [ $? -ne 0 ]; then
    echo -e "${RED}[错误] 构建失败${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] armeabi-v7a APK 构建完成${NC}"
echo ""

echo -e "${YELLOW}[3/3] 构建 universal APK（包含所有架构）...${NC}"
flutter build apk --release
if [ $? -ne 0 ]; then
    echo -e "${RED}[错误] 构建失败${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Universal APK 构建完成${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} 构建完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "APK 文件位置："
echo "  - ARM64: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
echo "  - ARM32: build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"
echo "  - 通用版: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "提示：通用版APK体积较大但兼容性更好，ARM64版本体积最小性能最好"
echo ""

# 询问是否打开输出目录（仅限 macOS）
if [[ "$OSTYPE" == "darwin"* ]]; then
    read -p "是否打开输出目录？(Y/N): " opendir
    if [[ "$opendir" =~ ^[Yy]$ ]]; then
        open build/app/outputs/flutter-apk
    fi
fi
