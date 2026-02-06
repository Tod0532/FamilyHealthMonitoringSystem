#!/bin/bash

# ================================================
# 家庭功能 API 测试脚本
# ================================================

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 后端服务地址
API_BASE="http://139.129.108.119:8080"

# 测试账号 A (作为家庭创建者/管理员)
PHONE_A="13800138000"
PASSWORD_A="abc123456"

# 测试账号 B (作为家庭加入者)
PHONE_B="13900139000"
PASSWORD_B="xyz123456"

# 打印分隔线
print_separator() {
    echo -e "${BLUE}===============================================${NC}"
}

# 打印步骤
print_step() {
    echo -e "${GREEN}[$1] $2${NC}"
}

# 打印信息
print_info() {
    echo -e "${YELLOW}$1${NC}"
}

# 清理函数
cleanup() {
    print_info "清理临时文件..."
    rm -f response_*.json
}

# ================================================
# 主测试流程
# ================================================

print_separator
print_info "       家庭功能 API 测试脚本"
print_separator
print_info "后端地址: $API_BASE"
print_info "测试账号A: $PHONE_A (管理员)"
print_info "测试账号B: $PHONE_B (成员)"
print_separator
echo ""

# 捕获 Ctrl+C
trap cleanup EXIT

# ============================================
# 第一步：用户A登录
# ============================================
print_step "1" "用户A登录..."
curl -s -X POST "${API_BASE}/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"phone\":\"$PHONE_A\",\"password\":\"$PASSWORD_A\"}" \
  -o response_a_login.json

cat response_a_login.json
echo ""

# 解析Token和用户ID
TOKEN_A=$(cat response_a_login.json | grep -o '"token":"[^"]*"' | cut -d':' -f2 | tr -d '"')
USER_A_ID=$(cat response_a_login.json | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

print_info "Token_A: $TOKEN_A"
print_info "User_A_ID: $USER_A_ID"
echo ""

# ============================================
# 第二步：用户A创建家庭
# ============================================
print_step "2" "用户A创建家庭..."
curl -s -X POST "${API_BASE}/api/family/create" \
  -H "Content-Type: application/json" \
  -H "X-User-Id: $USER_A_ID" \
  -d '{"familyName":"测试家庭"}' \
  -o response_a_create.json

cat response_a_create.json
echo ""

# 解析家庭邀请码
FAMILY_CODE=$(cat response_a_create.json | grep -o '"familyCode":"[^"]*"' | cut -d':' -f2 | tr -d '"')
print_info "家庭邀请码: $FAMILY_CODE"
echo ""

# ============================================
# 第三步：用户A获取家庭信息
# ============================================
print_step "3" "用户A获取家庭信息..."
curl -s -X GET "${API_BASE}/api/family/my" \
  -H "Content-Type: application/json" \
  -H "X-User-Id: $USER_A_ID" \
  -o response_a_my_family.json

cat response_a_my_family.json
echo ""

# ============================================
# 第四步：用户A获取家庭二维码
# ============================================
print_step "4" "用户A获取家庭二维码..."
curl -s -X GET "${API_BASE}/api/family/qrcode" \
  -H "Content-Type: application/json" \
  -H "X-User-Id: $USER_A_ID" \
  -o response_a_qrcode.json

cat response_a_qrcode.json
echo ""

# ============================================
# 第五步：解析邀请码（无需登录）
# ============================================
print_step "5" "解析邀请码（预览家庭信息）..."
curl -s -X GET "${API_BASE}/api/family/info/$FAMILY_CODE" \
  -H "Content-Type: application/json" \
  -o response_parse_code.json

cat response_parse_code.json
echo ""

# ============================================
# 第六步：用户B登录
# ============================================
print_step "6" "用户B登录..."
curl -s -X POST "${API_BASE}/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"phone\":\"$PHONE_B\",\"password\":\"$PASSWORD_B\"}" \
  -o response_b_login.json

cat response_b_login.json
echo ""

# 解析用户B的ID
USER_B_ID=$(cat response_b_login.json | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
print_info "User_B_ID: $USER_B_ID"
echo ""

# ============================================
# 第七步：用户B加入家庭
# ============================================
print_step "7" "用户B加入家庭..."
curl -s -X POST "${API_BASE}/api/family/join" \
  -H "Content-Type: application/json" \
  -H "X-User-Id: $USER_B_ID" \
  -d "{\"inviteCode\":\"$FAMILY_CODE\"}" \
  -o response_b_join.json

cat response_b_join.json
echo ""

# ============================================
# 第八步：用户A获取成员列表
# ============================================
print_step "8" "用户A获取家庭成员列表..."
curl -s -X GET "${API_BASE}/api/family/members" \
  -H "Content-Type: application/json" \
  -H "X-User-Id: $USER_A_ID" \
  -o response_a_members.json

cat response_a_members.json
echo ""

# ============================================
# 第九步：用户B获取成员列表
# ============================================
print_step "9" "用户B获取家庭成员列表..."
curl -s -X GET "${API_BASE}/api/family/members" \
  -H "Content-Type: application/json" \
  -H "X-User-Id: $USER_B_ID" \
  -o response_b_members.json

cat response_b_members.json
echo ""

# ============================================
# 第十步：用户B获取家庭信息
# ============================================
print_step "10" "用户B获取家庭信息..."
curl -s -X GET "${API_BASE}/api/family/my" \
  -H "Content-Type: application/json" \
  -H "X-User-Id: $USER_B_ID" \
  -o response_b_my_family.json

cat response_b_my_family.json
echo ""

# ============================================
# 第十一步：用户A更新家庭名称
# ============================================
print_step "11" "用户A更新家庭名称..."
curl -s -X PUT "${API_BASE}/api/family/name?familyName=新测试家庭" \
  -H "Content-Type: application/json" \
  -H "X-User-Id: $USER_A_ID" \
  -o response_a_update_name.json

cat response_a_update_name.json
echo ""

# ============================================
# 第十二步：用户B退出家庭
# ============================================
print_step "12" "用户B退出家庭..."
curl -s -X POST "${API_BASE}/api/family/leave" \
  -H "Content-Type: application/json" \
  -H "X-User-Id: $USER_B_ID" \
  -o response_b_leave.json

cat response_b_leave.json
echo ""

# ============================================
# 第十三步：用户A移除成员（可选，如果有成员C）
# ============================================
print_step "13" "用户A移除成员B..."
curl -s -X DELETE "${API_BASE}/api/family/members/$USER_B_ID" \
  -H "Content-Type: application/json" \
  -H "X-User-Id: $USER_A_ID" \
  -o response_a_remove_member.json

cat response_a_remove_member.json
echo ""

# ============================================
# 测试完成
# ============================================
print_separator
print_info "              测试完成！"
print_separator
echo ""
print_info "生成的响应文件："
echo "  - response_a_login.json       (用户A登录)"
echo "  - response_a_create.json      (用户A创建家庭)"
echo "  - response_a_my_family.json   (用户A获取家庭信息)"
echo "  - response_a_qrcode.json      (用户A获取二维码)"
echo "  - response_parse_code.json    (解析邀请码)"
echo "  - response_b_login.json       (用户B登录)"
echo "  - response_b_join.json        (用户B加入家庭)"
echo "  - response_a_members.json     (用户A获取成员列表)"
echo "  - response_b_members.json     (用户B获取成员列表)"
echo "  - response_b_my_family.json   (用户B获取家庭信息)"
echo "  - response_a_update_name.json (用户A更新家庭名称)"
echo "  - response_b_leave.json       (用户B退出家庭)"
echo "  - response_a_remove_member.json (用户A移除成员)"
echo ""
print_info "家庭邀请码: $FAMILY_CODE"
echo ""

# 保存邀请码到文件
echo "FAMILY_CODE=$FAMILY_CODE" > test-env.txt
echo "USER_A_ID=$USER_A_ID" >> test-env.txt
echo "USER_B_ID=$USER_B_ID" >> test-env.txt
echo "TOKEN_A=$TOKEN_A" >> test-env.txt

print_info "测试环境变量已保存到 test-env.txt"
echo ""
