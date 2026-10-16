# 冒烟脚本共用的 HTTP 小工具（用 curl.exe 而不是 Invoke-RestMethod）
#
# 为什么不用 Invoke-RestMethod：
#   实测在本机 PowerShell 5.1 上会**卡死**（进程停在 13 个线程全 Wait、
#   没有任何 socket 的挂起态），冒烟脚本因此跑到一半就不动了。curl.exe 是
#   系统自带、行为确定的替代品。
#
# 为什么要写临时请求体文件：
#   PowerShell 5.1 → 原生命令的参数传递会把 JSON 里的双引号吞掉，
#   导致后端报"请求体格式错误"（实测踩到）。写成文件用 --data-binary @file 就没事。
#
# 用法：在脚本里 . "$PSScriptRoot\smoke-http.ps1"

$script:SMOKE_BODY_FILE = Join-Path $env:TEMP 'smoke_body.json'
$script:SMOKE_UTF8 = New-Object System.Text.UTF8Encoding($false)

# GET/POST，返回响应文本（失败时返回空串，错误信息在 $script:SMOKE_LAST_ERROR）
function Invoke-CurlJson {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [string]$Method = 'GET',
    [string[]]$Headers = @(),
    [string]$Json = '',
    [int]$TimeoutSec = 10
  )
  $cargs = @('-s', '-m', "$TimeoutSec", '-X', $Method, $Url)
  foreach ($h in $Headers) { $cargs += @('-H', $h) }
  if ($Json) {
    [System.IO.File]::WriteAllText($script:SMOKE_BODY_FILE, $Json, $script:SMOKE_UTF8)
    $cargs += @('-H', 'Content-Type: application/json', '--data-binary', "@$($script:SMOKE_BODY_FILE)")
  }
  $script:SMOKE_LAST_ERROR = ''
  $raw = & curl.exe @cargs 2>&1
  $errs = @($raw | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
  if ($errs.Count -gt 0) { $script:SMOKE_LAST_ERROR = ($errs | ForEach-Object { $_.ToString() }) -join ' ' }
  return (($raw | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n")
}

function ConvertTo-JsonCompact {
  param([Parameter(Mandatory = $true)]$Object)
  return ($Object | ConvertTo-Json -Depth 8 -Compress)
}

# 启动 dev 后端并等到可响应为止；返回 $true/$false
function Start-DevBackend {
  param(
    [string]$JavaHome = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot',
    [string]$JarPath,
    [string]$BaseUrl = 'http://127.0.0.1:8080',
    [string]$LogPath = (Join-Path $env:TEMP 'dev_smoke.log')
  )
  Get-Process java -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like '*jdk-17*' } |
    Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
  Remove-Item $LogPath -ErrorAction SilentlyContinue
  # 三个标准流都要重定向（含 stdin）：少一个，Start-Process 起的后端会让
  # 调用方 PowerShell 进程在脚本跑完后**一直挂着不退出**
  # （实测：结果都打完了，宿主进程还停在 13 个 Wait 线程上）。
  #
  # stdin 不要写 'NUL' —— Start-Process 不认这个路径设备名，直接抛
  # "文件名的值无效/找不到文件"，后端根本起不来（实测踩到）。用空文件。
  $nullInput = Join-Path $env:TEMP 'smoke_nullin.txt'
  if (-not (Test-Path $nullInput)) { [System.IO.File]::WriteAllText($nullInput, '') }
  Start-Process -FilePath (Join-Path $JavaHome 'bin\java.exe') `
    -ArgumentList '-jar', $JarPath, '--spring.profiles.active=dev' `
    -RedirectStandardOutput $LogPath `
    -RedirectStandardError ($LogPath -replace '\.log$', '_err.log') `
    -RedirectStandardInput $nullInput | Out-Null
  for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 2
    $t = Invoke-CurlJson -Url "$BaseUrl/api/auth/login" -Method POST `
      -Json (ConvertTo-JsonCompact @{ phone = 'x'; password = 'y' })
    if ($t -like '*"code"*') { return $true }
  }
  return $false
}
