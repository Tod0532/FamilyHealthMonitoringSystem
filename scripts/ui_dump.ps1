# 读取真机当前界面（Flutter 的文字在 content-desc 里，不在 text 里）
#
# 为什么需要它：
#   本项目用的模型不能直接看图，真机界面只能靠 uiautomator 转成文字来判断。
#   踩过的坑：Flutter 的 Text 在 uiautomator dump 里出现在 **content-desc**，
#   `text=` 全是空串 —— 只看 text= 会得出"界面查不到文字"的错误结论。
#   另外 dump 会返回**上一次的缓存**，所以必须换文件名 + 先删旧文件。
#
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ui_dump.ps1
#   powershell ... -File scripts\ui_dump.ps1 -Json      # 额外输出可点击元素的坐标（便于 input tap）

param(
  [switch]$Json,
  [string]$Adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
)

$ErrorActionPreference = 'Continue'

if (-not (Test-Path $Adb)) {
  Write-Host "找不到 adb: $Adb"
  exit 1
}

# 每次换一个文件名，避免读到上一次的缓存
$stamp = Get-Date -Format 'HHmmssfff'
$remote = "/sdcard/ui_$stamp.xml"
$local = Join-Path $env:TEMP "ui_$stamp.xml"

& $Adb shell uiautomator dump $remote 2>&1 | Out-Null
& $Adb shell cat $remote > $local
& $Adb shell rm -f $remote 2>&1 | Out-Null

if (-not (Test-Path $local)) {
  Write-Host "dump 失败"
  exit 1
}
$xml = [System.IO.File]::ReadAllText($local, [System.Text.Encoding]::UTF8)
if ($xml.Length -lt 50) {
  Write-Host "dump 内容异常（$($xml.Length) 字符）"
  exit 1
}

# 当前前台包名
$pkg = ''
$m = [regex]::Match($xml, 'package="([^"]+)"')
if ($m.Success) { $pkg = $m.Groups[1].Value }
Write-Host "前台包名: $pkg"

# 从单行 node 里取某个属性值
function Get-Attr {
  param([string]$NodeXml, [string]$Name)
  $mm = [regex]::Match($NodeXml, "$Name=`"([^`"]*)`"")
  if ($mm.Success) { return $mm.Groups[1].Value }
  return ''
}

$nodes = [regex]::Matches($xml, '<node\b[^>]*>')
$idx = 0
foreach ($n in $nodes) {
  $s = $n.Value
  $desc = Get-Attr $s 'content-desc'
  $text = Get-Attr $s 'text'
  $cls = Get-Attr $s 'class'
  $bounds = Get-Attr $s 'bounds'
  $label = if ($desc) { $desc } else { $text }
  if ($label) {
    $short = $cls -replace '^android\.widget\.', '' -replace '^android\.view\.', ''
    Write-Host ("  [{0,2}] {1,-12} {2,-28} {3}" -f $idx, $short, $bounds, $label)
  }
  $idx++
}

if ($Json) {
  Write-Host ""
  Write-Host "=== 可点击元素中心点（可直接用于 adb shell input tap X Y）==="
  foreach ($n in $nodes) {
    $s = $n.Value
    if ($s -notmatch 'clickable="true"') { continue }
    $mm = [regex]::Match($s, 'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
    if (-not $mm.Success) { continue }
    $x1 = [int]$mm.Groups[1].Value; $y1 = [int]$mm.Groups[2].Value
    $x2 = [int]$mm.Groups[3].Value; $y2 = [int]$mm.Groups[4].Value
    $dm = [regex]::Match($s, 'content-desc="([^"]*)"')
    $tm = [regex]::Match($s, 'text="([^"]*)"')
    $lbl = if ($dm.Success -and $dm.Groups[1].Value) { $dm.Groups[1].Value } else { $tm.Groups[1].Value }
    Write-Host ("  tap {0} {1}   # {2}" -f ([int](($x1 + $x2) / 2)), ([int](($y1 + $y2) / 2)), $lbl)
  }
}
