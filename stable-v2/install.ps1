<#
  DeepSeek Harness 插件整合包 v2.0.0 —— 统一入口（Windows）
  由 INSTALL.cmd / VERIFY.cmd / DOCTOR.cmd / ROLLBACK.cmd / UNINSTALL.cmd / SETUP-SERVICES.cmd 调用。
  不联网、不改系统设置、只操作 DSH 的 profile 目录与本包持久目录。
#>
[CmdletBinding()]
param(
  [ValidateSet('install', 'verify', 'doctor', 'rollback', 'uninstall', 'services')]
  [string]$Action = 'install',
  [string]$DesktopDir = '',
  [ValidateSet('', 'new', 'merge', 'backup')]
  [string]$Mode = '',
  [switch]$Yes,
  [switch]$NoLaunch,
  [switch]$ForceConfig,
  [switch]$ForceKernel
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Write-Title($text) {
  Write-Host ''
  Write-Host ('=' * 74) -ForegroundColor DarkCyan
  Write-Host "  $text" -ForegroundColor Cyan
  Write-Host ('=' * 74) -ForegroundColor DarkCyan
}

function Find-Desktop([string]$given) {
  $cands = @()
  if ($given) { $cands += $given }
  if ($env:DSH_DESKTOP_DIR) { $cands += $env:DSH_DESKTOP_DIR }
  $cands += @(
    (Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness'),
    (Join-Path $env:LOCALAPPDATA 'DeepSeek Harness'),
    (Join-Path $env:ProgramFiles 'DeepSeek Harness'),
    (Join-Path ${env:ProgramFiles(x86)} 'DeepSeek Harness')
  )
  foreach ($c in $cands) {
    if (-not $c) { continue }
    if (Test-Path (Join-Path $c 'DeepSeek Harness.exe')) { return (Resolve-Path $c).Path }
  }
  return ''
}

Write-Title "DeepSeek Harness 插件整合包 v2.0.0 —— 动作：$Action"

# ---------- 定位 Desktop ----------
$desktop = Find-Desktop $DesktopDir
if (-not $desktop) {
  Write-Host '没有自动找到 DeepSeek Harness 的安装目录。' -ForegroundColor Yellow
  Write-Host '请把「包含 DeepSeek Harness.exe 的那个文件夹」完整路径粘贴进来（例如 C:\Users\你\AppData\Local\Programs\DeepSeek Harness）：'
  $input = Read-Host '安装目录'
  $input = $input.Trim('"', ' ')
  if (-not (Test-Path (Join-Path $input 'DeepSeek Harness.exe'))) {
    Write-Host '这个目录里没有 DeepSeek Harness.exe，已停止。' -ForegroundColor Red
    exit 1
  }
  $desktop = (Resolve-Path $input).Path
}
$exe = Join-Path $desktop 'DeepSeek Harness.exe'
Write-Host "Desktop：$desktop"

# ---------- 安装模式菜单 ----------
$helper = Join-Path $Root 'install-helper.cjs'
if (-not (Test-Path $helper)) { Write-Host '安装器核心 install-helper.cjs 不见了，包可能没解压完整。' -ForegroundColor Red; exit 1 }

$modeArg = @()
if ($Action -eq 'install' -and -not $Mode) {
  Write-Host ''
  Write-Host '请选择安装方式：' -ForegroundColor Cyan
  Write-Host '  A  全新安装 —— 只接受“空壳”DSH（没有任何第三方插件）。最干净，也是推荐给第一次装整合包的人。'
  Write-Host '  B  智能合并 —— 只补你缺的插件，已经装过的同名插件一律跳过，不覆盖。日常升级/加装选这个。'
  Write-Host '  C  备份后覆盖 —— 先把现有配置完整备份，再用本包版本覆盖同名插件。适合“就是要这套东西”的场景。'
  Write-Host ''
  $ans = Read-Host '输入 A / B / C（直接回车 = B 智能合并）'
  switch ($ans.Trim().ToUpper()) {
    'A' { $Mode = 'new' }
    'C' { $Mode = 'backup' }
    default { $Mode = 'merge' }
  }
}
if ($Mode) { $modeArg = @('--mode', $Mode) }
if ($Yes) { $modeArg += '--yes' }
if ($NoLaunch) { $modeArg += '--no-launch' }
if ($ForceConfig) { $modeArg += '--force-config' }
if ($ForceKernel) { $modeArg += '--force-kernel' }

# ---------- 用 Desktop 自带的 Electron 跑 Node 脚本（用户机器不需要装 Node.js） ----------
$env:ELECTRON_RUN_AS_NODE = '1'
$common = @('--expose-internals', $helper, '--desktop-dir', $desktop)

function Invoke-Helper([string[]]$extra) {
  & $exe @($common + $extra)
  return $LASTEXITCODE
}

switch ($Action) {
  'install' {
    if (-not (Test-Path (Join-Path $Root 'payload\node_modules'))) {
      Write-Host '解压不完整：没有 payload\node_modules。请用 7-Zip 重新解压（Windows 自带解压对超长路径不友好）。' -ForegroundColor Red
      exit 1
    }
    $code = Invoke-Helper $modeArg
    if ($code -ne 0) { Write-Host "`n安装没有完成（退出码 $code）。上面有中文原因，日志可以直接贴给别人看。" -ForegroundColor Red; exit $code }
  }
  'verify' {
    $code = Invoke-Helper @('--check-only')
    if ($code -eq 0) {
      Write-Host ''
      Write-Host '包完整性没问题：可以放心运行 INSTALL.cmd。' -ForegroundColor Green
    } else { exit $code }
  }
  'doctor' {
    $code = Invoke-Helper @('--doctor')
    exit $code
  }
  'rollback' {
    $code = Invoke-Helper @('--rollback')
    exit $code
  }
  'uninstall' {
    $code = Invoke-Helper @('--uninstall')
    exit $code
  }
  'services' {
    $code = Invoke-Helper (@('--services-only') + $modeArg)
    exit $code
  }
}
