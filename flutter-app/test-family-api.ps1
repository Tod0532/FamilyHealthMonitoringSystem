# ================================================
# 家庭功能 API 测试脚本 (PowerShell)
# ================================================

# 配置
$API_BASE = "http://139.129.108.119:8080"
$PHONE_A = "13800138000"
$PASSWORD_A = "abc123456"
$PHONE_B = "13900139000"
$PASSWORD_B = "xyz123456"

# 全局变量
$TOKEN_A = ""
$USER_A_ID = ""
$TOKEN_B = ""
$USER_B_ID = ""
$FAMILY_CODE = ""

# 颜色函数
function Write-Step([string]$step, [string]$desc) {
    Write-Host "`n[$step] $desc" -ForegroundColor Green
}

function Write-Info([string]$msg) {
    Write-Host $msg -ForegroundColor Yellow
}

function Write-Success([string]$msg) {
    Write-Host $msg -ForegroundColor Cyan
}

function Write-Error([string]$msg) {
    Write-Host $msg -ForegroundColor Red
}

# HTTP请求函数
function Invoke-ApiRequest {
    param(
        [string]$Method,
        [string]$Url,
        [hashtable]$Headers,
        [string]$Body
    )

    try {
        $params = @{
            Method = $Method
            Uri = $Url
            ContentType = "application/json"
        }

        if ($Headers) {
            $params.Headers = $Headers
        }

        if ($Body) {
            $params.Body = $Body
        }

        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        Write-Error "请求失败: $($_.Exception.Message)"
        return $null
    }
}

# ================================================
# 测试开始
# ================================================

Clear-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "      家庭功能 API 测试脚本" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Info "后端地址: $API_BASE"
Write-Info "测试账号A: $PHONE_A (管理员)"
Write-Info "测试账号B: $PHONE_B (成员)"
Write-Host "==============================================" -ForegroundColor Cyan

# ============================================
# 1. 用户A登录
# ============================================
Write-Step "1" "用户A登录..."
$response = Invoke-ApiRequest -Method "POST" -Url "$API_BASE/api/auth/login" -Body @{
    phone = $PHONE_A
    password = $PASSWORD_A
} | ConvertTo-Json -Depth 10

Write-Host $response

# 解析响应
$data = $response | ConvertFrom-Json
$TOKEN_A = $data.data.token
$USER_A_ID = $data.data.id
Write-Info "Token_A: $TOKEN_A"
Write-Info "User_A_ID: $USER_A_ID"

# ============================================
# 2. 用户A创建家庭
# ============================================
Write-Step "2" "用户A创建家庭..."
$response = Invoke-ApiRequest -Method "POST" -Url "$API_BASE/api/family/create" -Headers @{
    "X-User-Id" = $USER_A_ID
} -Body @{
    familyName = "测试家庭"
} | ConvertTo-Json -Depth 10

Write-Host $response

$data = $response | ConvertFrom-Json
$FAMILY_CODE = $data.data.familyCode
Write-Info "家庭邀请码: $FAMILY_CODE"

# ============================================
# 3. 用户A获取家庭信息
# ============================================
Write-Step "3" "用户A获取家庭信息..."
$response = Invoke-ApiRequest -Method "GET" -Url "$API_BASE/api/family/my" -Headers @{
    "X-User-Id" = $USER_A_ID
} | ConvertTo-Json -Depth 10

Write-Host $response

# ============================================
# 4. 用户A获取二维码
# ============================================
Write-Step "4" "用户A获取家庭二维码..."
$response = Invoke-ApiRequest -Method "GET" -Url "$API_BASE/api/family/qrcode" -Headers @{
    "X-User-Id" = $USER_A_ID
} | ConvertTo-Json -Depth 10

Write-Host $response

# ============================================
# 5. 解析邀请码
# ============================================
Write-Step "5" "解析邀请码（预览家庭信息）..."
$response = Invoke-ApiRequest -Method "GET" -Url "$API_BASE/api/family/info/$FAMILY_CODE" | ConvertTo-Json -Depth 10

Write-Host $response

# ============================================
# 6. 用户B登录
# ============================================
Write-Step "6" "用户B登录..."
$response = Invoke-ApiRequest -Method "POST" -Url "$API_BASE/api/auth/login" -Body @{
    phone = $PHONE_B
    password = $PASSWORD_B
} | ConvertTo-Json -Depth 10

Write-Host $response

$data = $response | ConvertFrom-Json
$USER_B_ID = $data.data.id
Write-Info "User_B_ID: $USER_B_ID"

# ============================================
# 7. 用户B加入家庭
# ============================================
Write-Step "7" "用户B加入家庭..."
$response = Invoke-ApiRequest -Method "POST" -Url "$API_BASE/api/family/join" -Headers @{
    "X-User-Id" = $USER_B_ID
} -Body @{
    inviteCode = $FAMILY_CODE
} | ConvertTo-Json -Depth 10

Write-Host $response

# ============================================
# 8. 用户A获取成员列表
# ============================================
Write-Step "8" "用户A获取家庭成员列表..."
$response = Invoke-ApiRequest -Method "GET" -Url "$API_BASE/api/family/members" -Headers @{
    "X-User-Id" = $USER_A_ID
} | ConvertTo-Json -Depth 10

Write-Host $response

# ============================================
# 9. 用户B获取成员列表
# ============================================
Write-Step "9" "用户B获取家庭成员列表..."
$response = Invoke-ApiRequest -Method "GET" -Url "$API_BASE/api/family/members" -Headers @{
    "X-User-Id" = $USER_B_ID
} | ConvertTo-Json -Depth 10

Write-Host $response

# ============================================
# 10. 用户B获取家庭信息
# ============================================
Write-Step "10" "用户B获取家庭信息..."
$response = Invoke-ApiRequest -Method "GET" -Url "$API_BASE/api/family/my" -Headers @{
    "X-User-Id" = $USER_B_ID
} | ConvertTo-Json -Depth 10

Write-Host $response

# ============================================
# 11. 用户A更新家庭名称
# ============================================
Write-Step "11" "用户A更新家庭名称..."
$response = Invoke-ApiRequest -Method "PUT" -Url "$API_BASE/api/family/name?familyName=新测试家庭" -Headers @{
    "X-User-Id" = $USER_A_ID
} | ConvertTo-Json -Depth 10

Write-Host $response

# ============================================
# 12. 用户B退出家庭
# ============================================
Write-Step "12" "用户B退出家庭..."
$response = Invoke-ApiRequest -Method "POST" -Url "$API_BASE/api/family/leave" -Headers @{
    "X-User-Id" = $USER_B_ID
} | ConvertTo-Json -Depth 10

Write-Host $response

# ============================================
# 13. 用户A移除成员（测试）
# ============================================
Write-Step "13" "用户A移除成员B..."
$response = Invoke-ApiRequest -Method "DELETE" -Url "$API_BASE/api/family/members/$USER_B_ID" -Headers @{
    "X-User-Id" = $USER_A_ID
} | ConvertTo-Json -Depth 10

Write-Host $response

# ============================================
# 测试完成
# ============================================
Write-Host "`n==============================================" -ForegroundColor Cyan
Write-Success "            测试完成！"
Write-Host "==============================================" -ForegroundColor Cyan
Write-Info "`n家庭邀请码: $FAMILY_CODE"
Write-Info "用户A ID: $USER_A_ID"
Write-Info "用户B ID: $USER_B_ID`n"

# 保存测试环境变量
@"
TOKEN_A=$TOKEN_A
USER_A_ID=$USER_A_ID
TOKEN_B=$TOKEN_B
USER_B_ID=$USER_B_ID
FAMILY_CODE=$FAMILY_CODE
"@ | Out-File -FilePath "test-env.txt" -Encoding UTF8

Write-Success "测试环境变量已保存到 test-env.txt"
