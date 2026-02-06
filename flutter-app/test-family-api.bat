@echo off
REM ================================================
REM 家庭功能 API 测试脚本
REM ================================================
REM 后端服务地址
set API_BASE=http://139.129.108.119:8080

REM 测试账号 A (作为家庭创建者/管理员)
set PHONE_A=13800138000
set PASSWORD_A=abc123456

REM 测试账号 B (作为家庭加入者)
set PHONE_B=13900139000
set PASSWORD_B=xyz123456

echo ===============================================
echo       家庭功能 API 测试脚本
echo ===============================================
echo 后端地址: %API_BASE%
echo 测试账号A: %PHONE_A% (管理员)
echo 测试账号B: %PHONE_B% (成员)
echo ===============================================
echo.

REM ============================================
REM 第一步：用户A登录
REM ===============================================
echo [1] 用户A登录...
curl -s -X POST "%API_BASE%/api/auth/login" ^
  -H "Content-Type: application/json" ^
  -d "{\"phone\":\"%PHONE_A%\",\"password\":\"%PASSWORD_A%\"}" ^
  > response_a_login.json

type response_a_login.json
echo.

REM 解析Token (使用PowerShell)
for /f "tokens=2 delims=:," %%a in ('type response_a_login.json ^| findstr /C:"token"') do set TOKEN_A=%%a
set TOKEN_A=%TOKEN_A:"=%
set TOKEN_A=%TOKEN_A: =%
echo Token_A: %TOKEN_A%
echo.

REM 解析用户ID
for /f "tokens=2 delims=:," %%a in ('type response_a_login.json ^| findstr /C:"id"') do set USER_A_ID=%%a
set USER_A_ID=%USER_A_ID:"=%
set USER_A_ID=%USER_A_ID: =%
set USER_A_ID=%USER_A_ID:,=%
echo User_A_ID: %USER_A_ID%
echo.

REM ============================================
REM 第二步：用户A创建家庭
REM ===============================================
echo [2] 用户A创建家庭...
curl -s -X POST "%API_BASE%/api/family/create" ^
  -H "Content-Type: application/json" ^
  -H "X-User-Id: %USER_A_ID%" ^
  -d "{\"familyName\":\"测试家庭\"}" ^
  > response_a_create.json

type response_a_create.json
echo.

REM 解析家庭邀请码
for /f "tokens=2 delims=:," %%a in ('type response_a_create.json ^| findstr /C:"familyCode"') do set FAMILY_CODE=%%a
set FAMILY_CODE=%FAMILY_CODE:"=%
set FAMILY_CODE=%FAMILY_CODE: =%
set FAMILY_CODE=%FAMILY_CODE:,=%
echo 家庭邀请码: %FAMILY_CODE%
echo.

REM ============================================
REM 第三步：用户A获取家庭信息
REM ===============================================
echo [3] 用户A获取家庭信息...
curl -s -X GET "%API_BASE%/api/family/my" ^
  -H "Content-Type: application/json" ^
  -H "X-User-Id: %USER_A_ID%" ^
  > response_a_my_family.json

type response_a_my_family.json
echo.

REM ============================================
REM 第四步：用户A获取家庭二维码
REM ===============================================
echo [4] 用户A获取家庭二维码...
curl -s -X GET "%API_BASE%/api/family/qrcode" ^
  -H "Content-Type: application/json" ^
  -H "X-User-Id: %USER_A_ID%" ^
  > response_a_qrcode.json

type response_a_qrcode.json
echo.

REM ============================================
REM 第五步：解析邀请码（无需登录）
REM ===============================================
echo [5] 解析邀请码（预览家庭信息）...
curl -s -X GET "%API_BASE%/api/family/info/%FAMILY_CODE%" ^
  -H "Content-Type: application/json" ^
  > response_parse_code.json

type response_parse_code.json
echo.

REM ============================================
REM 第六步：用户B登录
REM ===============================================
echo [6] 用户B登录...
curl -s -X POST "%API_BASE%/api/auth/login" ^
  -H "Content-Type: application/json" ^
  -d "{\"phone\":\"%PHONE_B%\",\"password\":\"%PASSWORD_B%\"}" ^
  > response_b_login.json

type response_b_login.json
echo.

REM 解析用户B的ID
for /f "tokens=2 delims=:," %%a in ('type response_b_login.json ^| findstr /C:"id"') do set USER_B_ID=%%a
set USER_B_ID=%USER_B_ID:"=%
set USER_B_ID=%USER_B_ID: =%
set USER_B_ID=%USER_B_ID:,=%
echo User_B_ID: %USER_B_ID%
echo.

REM ============================================
REM 第七步：用户B加入家庭
REM ===============================================
echo [7] 用户B加入家庭...
curl -s -X POST "%API_BASE%/api/family/join" ^
  -H "Content-Type: application/json" ^
  -H "X-User-Id: %USER_B_ID%" ^
  -d "{\"inviteCode\":\"%FAMILY_CODE%\"}" ^
  > response_b_join.json

type response_b_join.json
echo.

REM ============================================
REM 第八步：用户A获取成员列表
REM ===============================================
echo [8] 用户A获取家庭成员列表...
curl -s -X GET "%API_BASE%/api/family/members" ^
  -H "Content-Type: application/json" ^
  -H "X-User-Id: %USER_A_ID%" ^
  > response_a_members.json

type response_a_members.json
echo.

REM ============================================
REM 第九步：用户B获取成员列表
REM ===============================================
echo [9] 用户B获取家庭成员列表...
curl -s -X GET "%API_BASE%/api/family/members" ^
  -H "Content-Type: application/json" ^
  -H "X-User-Id: %USER_B_ID%" ^
  > response_b_members.json

type response_b_members.json
echo.

REM ============================================
REM 第十步：用户B获取家庭信息
REM ===============================================
echo [10] 用户B获取家庭信息...
curl -s -X GET "%API_BASE%/api/family/my" ^
  -H "Content-Type: application/json" ^
  -H "X-User-Id: %USER_B_ID%" ^
  > response_b_my_family.json

type response_b_my_family.json
echo.

REM ============================================
REM 第十一步：用户A更新家庭名称
REM ===============================================
echo [11] 用户A更新家庭名称...
curl -s -X PUT "%API_BASE%/api/family/name?familyName=新测试家庭" ^
  -H "Content-Type: application/json" ^
  -H "X-User-Id: %USER_A_ID%" ^
  > response_a_update_name.json

type response_a_update_name.json
echo.

REM ============================================
REM 第十二步：用户B退出家庭
REM ===============================================
echo [12] 用户B退出家庭...
curl -s -X POST "%API_BASE%/api/family/leave" ^
  -H "Content-Type: application/json" ^
  -H "X-User-Id: %USER_B_ID%" ^
  > response_b_leave.json

type response_b_leave.json
echo.

echo ===============================================
echo               测试完成！
echo ===============================================
echo.
echo 生成的响应文件：
echo   - response_a_login.json       (用户A登录)
echo   - response_a_create.json      (用户A创建家庭)
echo   - response_a_my_family.json   (用户A获取家庭信息)
echo   - response_a_qrcode.json      (用户A获取二维码)
echo   - response_parse_code.json    (解析邀请码)
echo   - response_b_login.json       (用户B登录)
echo   - response_b_join.json        (用户B加入家庭)
echo   - response_a_members.json     (用户A获取成员列表)
echo   - response_b_members.json     (用户B获取成员列表)
echo   - response_b_my_family.json   (用户B获取家庭信息)
echo   - response_a_update_name.json (用户A更新家庭名称)
echo   - response_b_leave.json       (用户B退出家庭)
echo.
echo 家庭邀请码: %FAMILY_CODE%
echo.

pause
