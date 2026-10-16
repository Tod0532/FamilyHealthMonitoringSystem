# 模拟板子上报器 —— 没有 ESP32 硬件时，代替板子按固件的真实节奏上报心率
#
# 为什么需要它：
#   ESP32 固件在本机从未编译过（无工具链），但下位机到 App 的整条链路
#   （上报 → 服务端节流 + 实时缓存 → GET /api/device/latest → App 监控页）
#   可以完全脱离硬件验证。本脚本扮演板子的角色，行为与固件一致：
#     · 每 5 秒上报一次心率（与 firmware/src/main.cpp 的 HEARTBEAT_REPORT_MS 一致）
#     · 带 X-Device-Token 头（固件 v2 的绑定令牌）
#     · 定期发 /api/device/heartbeat 维持"在线"状态
#
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File `
#     spring-boot-backend/src/test/sim-board.ps1
#   powershell ... -File sim-board.ps1 -Scenario spike -IntervalSeconds 5
#   powershell ... -File sim-board.ps1 -DurationSeconds 600
#
#   停止：Ctrl+C
#   换绑：-Rebind（默认复用上次的令牌；后端重启会清空 H2，此时会自动重绑）
#
# 注意：本文件含中文，**必须存成 UTF-8 带 BOM**，见下方自检。

param(
  [string]$Base = 'http://127.0.0.1:8080',
  [string]$Phone = '13800138000',
  [string]$Password = '123456',
  [string]$DeviceSn = 'ESP32-SIM-001',
  [string]$DeviceName = '模拟心率桥',
  [int]$IntervalSeconds = 5,
  [int]$DurationSeconds = 0,
  [ValidateSet('rest', 'walk', 'spike', 'recover')]
  [string]$Scenario = 'walk',
  [switch]$Rebind
)

$ErrorActionPreference = 'Continue'

# 自检：本文件含中文，被别人用 PS 5.1 按 GBK 读会解析失败，
# 而且症状是"函数名不认得"这种莫名其妙的报错。
$selfBytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
if (-not ($selfBytes[0] -eq 0xEF -and $selfBytes[1] -eq 0xBB -and $selfBytes[2] -eq 0xBF)) {
  Write-Host "本文件缺少 UTF-8 BOM，PowerShell 5.1 会按 GBK 解析而导致语法错误。"
  Write-Host "修复：把文件重新存为 UTF-8 with BOM（或用 PowerShell 补写 EF BB BF 三个字节）。"
  exit 2
}

. "$PSScriptRoot\smoke-http.ps1"

$tokenFile = Join-Path $env:TEMP 'sim_board_token.txt'

# 心率序列：不同场景用来驱动 App 与预警规则
function Get-NextHr {
  param([int]$i, [string]$scenario, [int]$intervalSec)
  $t = $i * $intervalSec
  switch ($scenario) {
    # 静息：68~78 之间缓慢起伏
    'rest' { return [int](72 + 6 * [math]::Sin($t / 20.0)) }
    # 走路：88~104，会周期性越过"心率过快 >100"这条默认规则
    'walk' { return [int](95 + 9 * [math]::Sin($t / 15.0)) }
    # 持续偏高：稳定在 110 以上（用来验证预警冷却、以及 App 显示）
    'spike' { return [int](112 + 4 * [math]::Sin($t / 10.0)) }
    # 回落又升高：105 → 70 → 105，用来验证"两个独立异常事件"不被合并
    'recover' {
      $cycle = $t % 120
      if ($cycle -lt 40) { return [int](106 + 3 * [math]::Sin($t / 8.0)) }
      if ($cycle -lt 80) { return [int](70 + 4 * [math]::Sin($t / 8.0)) }
      return [int](108 + 3 * [math]::Sin($t / 8.0))
    }
    default { return 75 }
  }
}

Write-Host "=== 1. 登录并绑定设备 ==="
$login = (Invoke-CurlJson -Url "$Base/api/auth/login" -Method POST `
    -Json (ConvertTo-JsonCompact @{ phone = $Phone; password = $Password })) | ConvertFrom-Json
if (-not $login.data.accessToken) {
  Write-Host "    登录失败：$($login | ConvertTo-Json -Compress)"
  Write-Host "    （dev 环境的种子账号是 $Phone / $Password）"
  exit 1
}
$auth = @("Authorization: Bearer $($login.data.accessToken)")

$token = $null
if (-not $Rebind -and (Test-Path $tokenFile)) {
  $token = (Get-Content $tokenFile -Raw).Trim()
  # 令牌可能已失效（后端重启 → H2 内存库重建）。先试一次心跳，失败就重绑。
  $hb = Invoke-CurlJson -Url "$Base/api/device/heartbeat?firmwareVersion=v2.1-sim" `
    -Method POST -Headers @("X-Device-Token: $token")
  if ($hb -notlike '*"code":200*') {
    Write-Host "    上次的令牌已失效（后端重启过？），重新绑定"
    $token = $null
  }
}

if (-not $token) {
  $members = (Invoke-CurlJson -Url "$Base/api/members" -Headers $auth) | ConvertFrom-Json
  $mid = $members.data[0].id
  if (-not $mid) {
    Write-Host "    该账号下没有成员，无法绑定：$($members | ConvertTo-Json -Compress)"
    exit 1
  }
  $bc = (Invoke-CurlJson -Url "$Base/api/device/bind-code" -Method POST -Headers $auth `
      -Json (ConvertTo-JsonCompact @{ memberId = $mid; deviceName = $DeviceName })) | ConvertFrom-Json
  if (-not $bc.data.bindCode) {
    Write-Host "    生成绑定码失败：$($bc | ConvertTo-Json -Compress)"
    exit 1
  }
  $bind = (Invoke-CurlJson -Url "$Base/api/device/bind" -Method POST `
      -Json (ConvertTo-JsonCompact @{
        bindCode        = $bc.data.bindCode
        deviceSn        = $DeviceSn
        deviceName      = $DeviceName
        deviceType      = 'esp32_hr_bridge'
        firmwareVersion = 'v2.1-sim'
      })) | ConvertFrom-Json
  if (-not $bind.data.deviceToken) {
    Write-Host "    绑定失败：$($bind | ConvertTo-Json -Compress)"
    exit 1
  }
  $token = $bind.data.deviceToken
  [System.IO.File]::WriteAllText($tokenFile, $token)
  Write-Host "    已绑定：$DeviceName（SN=$DeviceSn）→ 归属成员 $($bind.data.memberName)"
}

$dhead = @("X-Device-Token: $token")

Write-Host "=== 2. 开始上报 ==="
Write-Host "    场景=$Scenario  间隔=${IntervalSeconds}s  设备=$DeviceName"
if ($DurationSeconds -gt 0) { Write-Host "    时长=${DurationSeconds}s" } else { Write-Host "    时长=不限（Ctrl+C 停止）" }
Write-Host ""

$i = 0
$deadline = if ($DurationSeconds -gt 0) { (Get-Date).AddSeconds($DurationSeconds) } else { $null }
$ok = 0
$failed = 0

while ($true) {
  $hr = Get-NextHr -i $i -scenario $Scenario -intervalSec $IntervalSeconds
  $ts = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
  $r = Invoke-CurlJson -Url "$Base/api/device/health-data" -Method POST -Headers $dhead `
    -Json (ConvertTo-JsonCompact @{
        dataType    = 'heart_rate'
        value1      = $hr
        unit        = 'bpm'
        measureTime = $ts
      })

  if ($r -like '*"code":200*') {
    $ok++
    Write-Host ("    [{0}] 上报 #{1}  hr={2} bpm" -f (Get-Date -Format 'HH:mm:ss'), $i, $hr)
  } else {
    $failed++
    Write-Host ("    [{0}] 上报 #{1}  失败: {2}" -f (Get-Date -Format 'HH:mm:ss'), $i, $r)
    # 令牌失效就停下来，不要每 5 秒刷一屏同样的错误
    if ($r -like '*401*' -or $r -like '*令牌*') {
      Write-Host "    令牌无效，请加 -Rebind 重新绑定"
      break
    }
  }

  # 心跳：固件也是靠它维持"在线"（服务端在线窗口 5 分钟）
  if ($i % 12 -eq 11) {
    Invoke-CurlJson -Url "$Base/api/device/heartbeat?firmwareVersion=v2.1-sim" `
      -Method POST -Headers $dhead | Out-Null
  }

  $i++
  if ($deadline -and (Get-Date) -gt $deadline) { break }
  Start-Sleep -Seconds $IntervalSeconds
}

Write-Host ""
Write-Host ("=== 结束：成功 {0} 次 / 失败 {1} 次 ===" -f $ok, $failed)
