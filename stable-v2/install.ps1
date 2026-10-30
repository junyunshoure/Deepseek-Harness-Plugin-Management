<#
  DeepSeek Harness 插件整合包 v2.1.2 —— 统一入口（Windows）
  由 INSTALL.cmd / VERIFY.cmd / DOCTOR.cmd / ROLLBACK.cmd / UNINSTALL.cmd /
  SETUP-SERVICES.cmd / MAINTAIN.cmd / UPGRADE.cmd 调用。
  不联网（除非显式 -AllowNetwork）、不改系统设置、只操作 DSH 的 profile 目录与本包持久目录。
#>
[CmdletBinding()]
param(
  [ValidateSet('install', 'upgrade', 'repair', 'verify', 'doctor', 'rollback', 'uninstall', 'services', 'maintain', 'prune', 'appendix')]
  [string]$Action = 'install',
  [string]$DesktopDir = '',
  [ValidateSet('', 'new', 'merge', 'backup', 'upgrade', 'repair')]
  [string]$Mode = '',
  [switch]$Yes,
  [switch]$NoLaunch,
  [switch]$ForceConfig,
  [switch]$ForceKernel,
  [string]$SkillsRoot = '',
  [switch]$AllowNetwork,
  [switch]$SkipAppendix,
  [switch]$SkipCleanup,
  [int]$KeepDays = 7,
  [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$PackVersion = '2.1.2'

function Write-Title($text) {
  Write-Host ''
  Write-Host ('=' * 74) -ForegroundColor DarkCyan
  Write-Host "  $text" -ForegroundColor Cyan
  Write-Host ('=' * 74) -ForegroundColor DarkCyan
}

function Read-PackJson($name) {
  $p = Join-Path $Root $name
  if (-not (Test-Path $p)) { return $null }
  try { return (Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
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

Write-Title "DeepSeek Harness 插件整合包 v$PackVersion —— 动作：$Action"

# ---------- 定位 Desktop ----------
$desktop = Find-Desktop $DesktopDir
if (-not $desktop -and $Action -notin @('verify', 'maintain', 'prune', 'appendix')) {
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
  Write-Host '没有找到 DeepSeek Harness —— 校验/维护不需要它，安装时才需要（届时会提示你填路径）。' -ForegroundColor Yellow
}

$helper = Join-Path $Root 'install-helper.cjs'
if (-not (Test-Path $helper)) { Write-Host '安装器核心 install-helper.cjs 不见了，包可能没解压完整。' -ForegroundColor Red; exit 1 }

# ---------- 内核门禁（只提示，不阻断） ----------
if ($desktop) {
  try {
    $kv = (Get-Item $exe).VersionInfo.FileVersion
    if ($kv) { Write-Host "内核版本：$kv" -ForegroundColor DarkGray }
  } catch {}
}

# ---------- 模式菜单 ----------
$modeArg = @()
if ($Action -eq 'install' -and -not $Mode) {
  Write-Host ''
  Write-Host '请选择安装方式：' -ForegroundColor Cyan
  Write-Host '  A  全新安装 —— 只接受“空壳”DSH（没有任何第三方插件）。最干净，推荐给第一次装整合包的人。'
  Write-Host '  B  智能合并 —— 只补你缺的插件，已装过的同名插件一律跳过，不覆盖。加装插件选这个。'
  Write-Host '  C  备份后覆盖 —— 先把现有配置完整备份，再用本包版本覆盖同名插件。'
  Write-Host '  D  升级 —— 你装过旧版整合包（v2.0.x 或更早），把插件重指向本包载荷。装过旧包的人选这个。'
  Write-Host '  E  修复 —— 声明过本包插件但目录丢了/挂载断了，重新挂一遍，不动别的。'
  Write-Host ''
  $ans = Read-Host '输入 A / B / C / D / E（直接回车 = B 智能合并）'
  switch ($ans.Trim().ToUpper()) {
    'A' { $Mode = 'new' }
    'C' { $Mode = 'backup' }
    'D' { $Mode = 'upgrade' }
    'E' { $Mode = 'repair' }
    default { $Mode = 'merge' }
  }
}
if (-not $Mode) {
  switch ($Action) {
    'upgrade' { $Mode = 'upgrade' }
    'repair' { $Mode = 'repair' }
  }
}
if ($Mode) { $modeArg = @('--mode', $Mode) }
if ($Yes) { $modeArg += '--yes' }
if ($NoLaunch) { $modeArg += '--no-launch' }
if ($ForceConfig) { $modeArg += '--force-config' }
if ($ForceKernel) { $modeArg += '--force-kernel' }
if ($SkillsRoot) { $modeArg += @('--skills-root', $SkillsRoot) }
if ($AllowNetwork) { $modeArg += '--allow-network' }
if ($SkipAppendix) { $modeArg += '--skip-appendix' }
if ($SkipCleanup) { $modeArg += '--skip-cleanup' }
if ($CheckOnly) { $modeArg += '--check-only' }

# ---------- 用 Desktop 自带的 Electron 跑 Node 脚本（用户机器不需要装 Node.js） ----------
$env:ELECTRON_RUN_AS_NODE = '1'
$common = @('--expose-internals', $helper, '--desktop-dir', $desktop)

function Invoke-Helper([string[]]$extra) {
  $ArgList = @($common + $extra)
  # DeepSeek Harness.exe 是 GUI 子系统程序：PowerShell 用 & 调用它不会等待进程结束，
  # 会出现「窗口已经往下走、结果还没打印」甚至一闪而过。这里用管道逐行转发，
  # 既保证等到进程真正退出（管道读到 EOF），也保证输出能实时显示。
  #
  # 但在外部真机上踩过一次死坑（v2.1.0 报告）：本脚本全局 $ErrorActionPreference='Stop'，
  # 而 helper 正常进度的提示是走 stderr 的（例如「已存在同名包指向其他目录，将重指向载荷」）。
  # `2>&1 |` 会把每条 stderr 包装成 NativeCommandError，Stop 策略当场终止整条脚本 ——
  # 用户看到的是「退出码 1、一行都没写盘」，其实什么都没坏。这里局部放宽策略、把 stderr
  # 当普通文本转发，绝不因为一句提示而中断安装。
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $script:helperExit = 0
  try {
    & $exe @ArgList 2>&1 | ForEach-Object {
      $line = $_
      if ($line -is [System.Management.Automation.ErrorRecord]) {
        $msg = ''
        if ($null -ne $line.Exception) { $msg = [string]$line.Exception.Message }
        if ([string]::IsNullOrEmpty($msg)) { $msg = [string]$line }
        Write-Host $msg
      } else {
        Write-Host ([string]$line)
      }
    }
    if ($null -eq $LASTEXITCODE) { $script:helperExit = 0 } else { $script:helperExit = $LASTEXITCODE }
  } catch {
    # 管道本身出异常（极少见）：记下来但不改写 helper 的退出码语义
    Write-Host ("[warn] 转发 helper 输出时出错：" + $_.Exception.Message)
  } finally {
    $ErrorActionPreference = $prevEap
  }
  return $script:helperExit
}

function Get-Sha256([string]$Path) {
  # 用 .NET 直接算 SHA-256，不用 Get-FileHash：
  # 从 PowerShell 7 窗口里启动 powershell.exe 时，PSModulePath 会被 pwsh 的路径占住，
  # Windows PowerShell 5.1 就可能找不到 Microsoft.PowerShell.Utility，Get-FileHash 直接报
  # 「not recognized」——纯 PowerShell 自检会当场失败。走 .NET 不依赖模块自动加载。
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $fs = $null
  try {
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    return ([System.BitConverter]::ToString($sha.ComputeHash($fs))).Replace('-', '').ToLower()
  } finally {
    if ($fs) { $fs.Dispose() }
    $sha.Dispose()
  }
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
    # 包里有 260 字符以上的长路径（@jimp 的 __image_snapshots__ 与 billion-context 的论文 md）。
    # Windows PowerShell 5.1 的 Test-Path / Get-Item / Get-FileHash 走 MAX_PATH，会把存在的文件
    # 误报成「缺失」，所以这里统一走 .NET FileInfo + \\?\ 前缀（≥240 字符时才加）。
    $lp = if ($p.Length -ge 240) { '\\?\' + $p } else { $p }
    $fi = $null
    try { $fi = New-Object System.IO.FileInfo($lp) } catch { $fi = $null }
    if (-not $fi -or -not $fi.Exists) { [void]$bad.Add("$($f.path)：文件缺失"); continue }
    if ($fi.Length -ne $f.size) { [void]$bad.Add("$($f.path)：体积不符（实得 $($fi.Length)，应为 $($f.size)）"); continue }
    $h = Get-Sha256 -Path $lp
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
  Write-Host ("✓ 本包版本：$PackVersion")
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
  'upgrade' {
    $code = Invoke-Helper $modeArg
    if ($code -ne 0) { Write-Host "`n升级没有完成（退出码 $code）。旧版本还在，可以照旧使用；把上面的原因贴出来即可。" -ForegroundColor Yellow; exit $code }
  }
  'repair' {
    $code = Invoke-Helper $modeArg
    exit $code
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
  'prune' {
    $pruneArg = @('--prune-old', '--keep-days', "$KeepDays")
    if ($CheckOnly) {
      $code = Invoke-Helper $pruneArg
    } else {
      $ans = Read-Host "确认删除 $KeepDays 天以前、且没有任何 profile 引用的旧载荷？(y/N)"
      if ($ans -match '^(y|Y)') { $pruneArg += '--yes' }
      $code = Invoke-Helper $pruneArg
    }
    exit $code
  }
  'maintain' {
    $mp = Join-Path $Root 'maintain.ps1'
    if (-not (Test-Path $mp)) { Write-Host '维护引擎 maintain.ps1 不见了，包可能没解压完整。' -ForegroundColor Red; exit 1 }
    $mArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $mp)
    if ($CheckOnly) { $mArgs += '-CheckOnly' }
    $mArgList = @($mArgs)
    & powershell @mArgList
    exit $LASTEXITCODE
  }
  'appendix' {
    # 只重写 AGENTS.md 里的「深度档位 + 对齐协议」（安装/升级/修复时已自动做过，这里是单独补跑）
    $code = Invoke-Helper @('--write-appendix')
    exit $code
  }
}
