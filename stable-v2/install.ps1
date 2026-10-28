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
if (-not $desktop -and $Action -ne 'verify') {
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
$exe = if ($desktop) { Join-Path $desktop 'DeepSeek Harness.exe' } else { '' }
if ($desktop) {
  Write-Host "Desktop：$desktop"
} else {
  Write-Host '没有找到 DeepSeek Harness —— 校验不需要它，安装时才需要（届时会提示你填路径）。' -ForegroundColor Yellow
}

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

function Invoke-PureVerify {
  # 机器上还没有 DSH（没有可借用的 Electron/Node）时，用 PowerShell 自己按 checksums.json 逐文件比对
  $csPath = Join-Path $Root 'checksums.json'
  if (-not (Test-Path $csPath)) { Write-Host '缺少 checksums.json，这个包不完整，请重新解压。' -ForegroundColor Red; return 1 }
  $cs = Get-Content $csPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Write-Host ('校验清单：{0} 个文件，{1} MB' -f $cs.counts.files, [math]::Round($cs.counts.bytes / 1MB, 1))
  $bad = New-Object System.Collections.ArrayList
  $n = 0
  foreach ($f in $cs.files) {
    $n++
    $p = Join-Path $Root ($f.path -replace '/', '\')
    if (-not (Test-Path -LiteralPath $p)) { [void]$bad.Add("$($f.path)：文件缺失"); continue }
    $len = (Get-Item -LiteralPath $p).Length
    if ($len -ne $f.size) { [void]$bad.Add("$($f.path)：体积不符（实得 $len，应为 $($f.size)）"); continue }
    $h = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()
    if ($h -ne $f.sha256) { [void]$bad.Add("$($f.path)：内容哈希不符") }
    if ($n % 2000 -eq 0) { Write-Host ('  已比对 {0}/{1}' -f $n, $cs.counts.files) }
  }
  Write-Host ('  已比对 {0}/{1}' -f $n, $cs.counts.files)
  if ($bad.Count -gt 0) {
    Write-Host ''
    Write-Host ('有 {0} 个文件对不上（下载或解压损坏）：' -f $bad.Count) -ForegroundColor Red
    $bad | Select-Object -First 15 | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host '处理办法：换 7-Zip 重新解压；仍然不对就重新下载。' -ForegroundColor Yellow
    return 1
  }
  Write-Host '✓ 全部文件与清单一致' -ForegroundColor Green
  Write-Host ('✓ 本包版本：2.0.0') 
  Write-Host '✓ 只做校验，未改动任何文件。'
  return 0
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
    if ($desktop -and (Test-Path $exe)) {
      $code = Invoke-Helper @('--check-only')
    } else {
      $code = Invoke-PureVerify
    }
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
