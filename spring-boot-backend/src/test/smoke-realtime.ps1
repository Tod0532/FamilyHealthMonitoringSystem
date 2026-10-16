# 心率实时监控链路冒烟（打真实运行的后端，不用 mock）
#
# 验证四件事：
#   1. 板子 5 秒一报后，GET /api/device/latest 的读数**每次都在变**
#      （实时值走内存缓存，不受落库节流影响）
#   2. ageSeconds 始终很小 —— 节流没有"漏"到实时值这条路上
#   3. 落库节流生效：health_data 行数**明显少于**上报次数
#   4. 上报一停，latest 置 stale=true（App 据此显示"数据已停止"，
#      不把旧读数当实时值显示）
#
# 为什么必须单独冒烟：节流一旦写错（比如顺手让实时值也走库），
# 实时监控页会一直显示 60 秒前的旧值；单元测试只覆盖 service 层，
# 覆盖不到 JSON 字段与两个接口的配合。
#
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File `
#     spring-boot-backend/src/test/smoke-realtime.ps1
#
# 注意（本项目踩过的坑）：
#   · 本文件与 smoke-http.ps1 含中文，**必须存成 UTF-8 带 BOM**，
#     否则 PowerShell 5.1 按 GBK 读会解析失败
#   · HTTP 一律用 curl.exe（见 smoke-http.ps1 顶部说明）

$ErrorActionPreference = 'Continue'

# 自检：本文件含中文，被别人用 PS 5.1 按 GBK 读会解析失败，
# 而且症状是"函数名不认得"这种莫名其妙的报错。
# 编辑工具（如各类 AI 编辑器）保存时会**悄悄去掉 BOM**，这里主动检查一次。
$selfBytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
if (-not ($selfBytes[0] -eq 0xEF -and $selfBytes[1] -eq 0xBB -and $selfBytes[2] -eq 0xBF)) {
  Write-Host "❌ 本文件缺少 UTF-8 BOM，PowerShell 5.1 会按 GBK 解析而导致语法错误。"
  Write-Host "   修复：把文件重新存为 UTF-8 with BOM（或用 PowerShell 补写 EF BB BF 三个字节）。"
  exit 2
}

. "$PSScriptRoot\smoke-http.ps1"

$base = 'http://127.0.0.1:8080'
$jar = 'D:\ReadHealthInfo\spring-boot-backend\target\health-center-backend-1.0.0.jar'
$log = Join-Path $env:TEMP 'dev_realtime.log'

$pass = 0
$fail = 0
function Check($ok, $passMsg, $failMsg) {
  if ($ok) { Write-Host "    ✅ PASS $passMsg"; $script:pass++ }
  else { Write-Host "    ❌ FAIL $failMsg"; $script:fail++ }
}

Write-Host "=== 1. 启动 dev 后端（H2 内存库）==="
if (-not (Start-DevBackend -JarPath $jar -BaseUrl $base -LogPath $log)) {
  Write-Host "    ❌ 后端没起来，看 $log"
  exit 1
}
Write-Host "    后端就绪"

Write-Host "=== 2. 登录 + 绑定设备 ==="
$login = (Invoke-CurlJson -Url "$base/api/auth/login" -Method POST `
    -Json (ConvertTo-JsonCompact @{ phone = '13800138000'; password = '123456' })) | ConvertFrom-Json
$auth = @("Authorization: Bearer $($login.data.accessToken)")
$members = (Invoke-CurlJson -Url "$base/api/members" -Headers $auth) | ConvertFrom-Json
$mid = $members.data[0].id
$bc = (Invoke-CurlJson -Url "$base/api/device/bind-code" -Method POST -Headers $auth `
    -Json (ConvertTo-JsonCompact @{ memberId = $mid; deviceName = 'realtime-smoke' })) | ConvertFrom-Json
$bind = (Invoke-CurlJson -Url "$base/api/device/bind" -Method POST `
    -Json (ConvertTo-JsonCompact @{
      bindCode        = $bc.data.bindCode
      deviceSn        = 'ESP32-RT-SMOKE'
      deviceName      = 'realtime-smoke'
      deviceType      = 'esp32_hr_bridge'
      firmwareVersion = 'v2.1'
    })) | ConvertFrom-Json
$dhead = @("X-Device-Token: $($bind.data.deviceToken)")
Write-Host "    已绑定，归属成员 $($bind.data.memberName)（id=$mid）"

# 上报序列：前 4 条小步变化（<3bpm，期望被节流），第 5 条跳变（期望入库）
$seq = @(75, 76, 75, 77, 90, 91, 90, 92)

Write-Host "=== 3. 按 5 秒节奏上报，同时每 1.5 秒轮询 /api/device/latest ==="
Write-Host "    上报序列 = $($seq -join ', ')（每 5s 一条，共约 40s）"
$observations = @()
$reported = 0
$deadline = (Get-Date).AddSeconds(40)
while ((Get-Date) -lt $deadline) {
  $hr = $seq[$reported]
  $ts = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
  $r = Invoke-CurlJson -Url "$base/api/device/health-data" -Method POST -Headers $dhead `
    -Json (ConvertTo-JsonCompact @{
        dataType    = 'heart_rate'
        value1      = $hr
        unit        = 'bpm'
        measureTime = $ts
      })
  if ($r -like '*"code":200*') {
    Write-Host ("    [{0}] 上报 {1} bpm" -f (Get-Date -Format 'HH:mm:ss'), $hr)
  } else {
    Write-Host ("    [{0}] 上报失败: {1}" -f (Get-Date -Format 'HH:mm:ss'), $r)
  }
  $reported++

  # 两次上报之间轮询（模拟 App 停在本页）
  for ($p = 0; $p -lt 2; $p++) {
    Start-Sleep -Milliseconds 1500
    $lj = Invoke-CurlJson -Url "$base/api/device/latest" -Headers $auth
    try {
      $d = ($lj | ConvertFrom-Json).data[0]
      $observations += [pscustomobject]@{
        t = (Get-Date -Format 'HH:mm:ss'); hr = $d.heartRate
        age = $d.ageSeconds; stale = $d.stale; on = $d.online
      }
      Write-Host ("             poll -> hr={0} age={1}s stale={2} online={3}" -f `
          $d.heartRate, $d.ageSeconds, $d.stale, $d.online)
    } catch {
      Write-Host ("             poll 解析失败: {0}" -f $lj)
    }
  }
  if ($reported -ge $seq.Length) { break }
}

Write-Host "=== 4. 判定：实时值是否一直在变（内存缓存这条路通不通）==="
$distinct = @($observations | Select-Object -ExpandProperty hr | Sort-Object -Unique)
Check ($distinct.Count -gt 1) `
  ("latest 出现 {0} 个不同读数：{1}" -f $distinct.Count, ($distinct -join ', ')) `
  ("latest 读数始终没变（{0}）—— 实时缓存没生效？" -f ($distinct -join ', '))

Write-Host "=== 5. 判定：上报期间 ageSeconds 是否一直很小 ==="
$maxAge = ($observations | Measure-Object -Property age -Maximum).Maximum
if ($null -eq $maxAge) { $maxAge = 0 }
Check ($maxAge -le 20) `
  ("最大 ageSeconds={0}（App 会显示「已连接」）" -f $maxAge) `
  ("最大 ageSeconds={0} —— 节流漏到了实时值这条路上" -f $maxAge)

Write-Host "=== 6. 判定：落库节流是否真的减少了行数 ==="
# 注意：/api/health-data 的 data 是**数组**（不是 MyBatis Plus 那套 records/total 分页对象）。
# 写成 $hd.data.records 会静默拿到空数组，于是出现"落库 0 行"的假失败（实测踩到）
$hd = (Invoke-CurlJson -Url "$base/api/health-data?page=1&size=100" -Headers $auth) | ConvertFrom-Json
$rows = @($hd.data | Where-Object { $_.dataSource -eq 'device' -and $_.dataType -eq 'heart_rate' })
Write-Host ("    上报 {0} 次 → health_data 落库 {1} 行：{2}" -f `
    $seq.Length, $rows.Count, (($rows | ForEach-Object { $_.value1 }) -join ', '))
Check ($rows.Count -lt $seq.Length -and $rows.Count -ge 1) `
  "落库行数少于上报次数，节流生效" `
  ("期望 1 <= 落库行数 < {0}，实际 {1}" -f $seq.Length, $rows.Count)

Write-Host "=== 7. 判定：上报停止后应置 stale ==="
Write-Host "    静默 25 秒..."
Start-Sleep -Seconds 25
$d = ((Invoke-CurlJson -Url "$base/api/device/latest" -Headers $auth) | ConvertFrom-Json).data[0]
Check ($d.stale -eq $true) `
  ("stale=true（age={0}s）—— App 显示「数据已停止」，不把旧值当实时值" -f $d.ageSeconds) `
  ("stale={0} age={1}s —— 旧读数会被当成实时心率" -f $d.stale, $d.ageSeconds)
Write-Host ("    （online={0}：设备在线窗口是 5 分钟，此刻仍可能为 true）" -f $d.online)

Write-Host ""
Write-Host ("=== 结果：{0} 项通过 / {1} 项失败 ===" -f $pass, $fail)
if ($fail -gt 0) { exit 1 }
