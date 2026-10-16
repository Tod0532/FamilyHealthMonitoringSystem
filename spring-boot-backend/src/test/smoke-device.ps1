$ErrorActionPreference = 'Continue'
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot'
$base = 'http://127.0.0.1:8080'
$jar = 'D:\ReadHealthInfo\spring-boot-backend\target\health-center-backend-1.0.0.jar'
$log = "$env:TEMP\dev_device.log"

function J($o) { $o | ConvertTo-Json -Depth 8 -Compress }

Write-Host "=== 1. 启动 dev 后端（H2 内存库）==="
Get-Process java -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*jdk-17*' } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Remove-Item $log -ErrorAction SilentlyContinue
Start-Process -FilePath "$env:JAVA_HOME\bin\java.exe" `
  -ArgumentList '-jar', $jar, '--spring.profiles.active=dev' `
  -RedirectStandardOutput $log -RedirectStandardError "$env:TEMP\dev_device_err.log" | Out-Null
for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Seconds 2
  try { $null = Invoke-RestMethod "$base/api/auth/login" -Method POST -TimeoutSec 3 `
        -ContentType 'application/json' -Body ([Text.Encoding]::UTF8.GetBytes('{"phone":"x","password":"y"}')) ; break } catch { }
  if (Select-String -Path $log -Pattern 'Started HealthCenterApplication' -Quiet -ErrorAction SilentlyContinue) { break }
}
Write-Host "    后端就绪"

Write-Host "=== 2. 用户登录（拿 JWT）==="
$login = Invoke-RestMethod "$base/api/auth/login" -Method POST -ContentType 'application/json' `
  -Body ([Text.Encoding]::UTF8.GetBytes((J @{ phone = '13800138000'; password = '123456' })))
$jwt = $login.data.accessToken
Write-Host "    token: $($jwt.Substring(0,[Math]::Min(20,$jwt.Length)))..."
$auth = @{ Authorization = "Bearer $jwt" }

Write-Host "=== 3. 找一个家庭成员 id ==="
$members = Invoke-RestMethod "$base/api/members" -Headers $auth
$mid = $members.data[0].id
Write-Host "    成员: $($members.data[0].name) (id=$mid)"

Write-Host "=== 4. App 生成绑定码 ==="
$bc = Invoke-RestMethod "$base/api/device/bind-code" -Method POST -Headers $auth -ContentType 'application/json' `
  -Body ([Text.Encoding]::UTF8.GetBytes((J @{ memberId = $mid; deviceName = '冒烟测试桥' })))
$code = $bc.data.bindCode
Write-Host "    绑定码: $code （$($bc.data.expireMinutes) 分钟有效，成员 $($bc.data.memberName)）"

Write-Host "=== 5. 设备用绑定码换令牌 ==="
$bind = Invoke-RestMethod "$base/api/device/bind" -Method POST -ContentType 'application/json' `
  -Body ([Text.Encoding]::UTF8.GetBytes((J @{ bindCode = $code; deviceSn = 'ESP32-SMOKE-001'; deviceName = '冒烟测试桥'; deviceType = 'esp32_hr_bridge'; firmwareVersion = 'v2.0' })))
$dtoken = $bind.data.deviceToken
Write-Host "    令牌: $($dtoken.Substring(0,[Math]::Min(16,$dtoken.Length)))...  归属成员: $($bind.data.memberName)"
$dhead = @{ 'X-Device-Token' = $dtoken }

Write-Host "=== 6. 设备上报心率 ==="
$hr = 72
$ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
Invoke-RestMethod "$base/api/device/health-data" -Method POST -Headers $dhead -ContentType 'application/json' `
  -Body ([Text.Encoding]::UTF8.GetBytes((J @{ dataType = 'heart_rate'; value1 = $hr; unit = 'bpm'; measureTime = $ts }))) | Out-Null
Write-Host "    已上报 $hr bpm @ $ts"

Write-Host "=== 7. 校验：数据是否进了健康数据 ==="
$hd = Invoke-RestMethod "$base/api/health-data?page=1&size=5" -Headers $auth
$found = $hd.data.records | Where-Object { $_.dataType -eq 'heart_rate' -and [int]$_.value1 -eq $hr }
if ($found) { Write-Host "    ✅ 找到设备上报记录：$($found.value1) bpm，来源 $($found.dataSource)，设备 $($found.deviceName)" }
else { Write-Host "    ❌ 没找到上报记录" }

Write-Host "=== 8. 设备列表（App 视角）==="
$devs = Invoke-RestMethod "$base/api/device" -Headers $auth
$devs.data | ForEach-Object { "    设备: $($_.deviceName)  成员=$($_.memberName)  在线=$($_.online)  最近=$($_.lastSeen)  固件=$($_.firmwareVersion)" }

Write-Host "=== 9. 解绑后令牌应失效 ==="
$id = $devs.data[0].id
Invoke-RestMethod "$base/api/device/$id" -Method DELETE -Headers $auth | Out-Null
try {
  Invoke-RestMethod "$base/api/device/heartbeat" -Method POST -Headers $dhead | Out-Null
  Write-Host "    ❌ 解绑后仍可用（异常）"
} catch {
  Write-Host "    ✅ 解绑后令牌已被拒绝：$($_.Exception.Response.StatusCode.value__)"
}

Write-Host "=== 10. 无效绑定码应被拒绝 ==="
try {
  Invoke-RestMethod "$base/api/device/bind" -Method POST -ContentType 'application/json' `
    -Body ([Text.Encoding]::UTF8.GetBytes((J @{ bindCode = '000000'; deviceSn = 'X' }))) | Out-Null
  Write-Host "    ❌ 无效绑定码被接受（异常）"
} catch {
  Write-Host "    ✅ 无效绑定码被拒绝：$($_.Exception.Response.StatusCode.value__)"
}
