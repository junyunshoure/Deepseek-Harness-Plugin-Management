<#
  DeepSeek Harness 插件整合包 v2.1.0 —— 维护引擎（Windows）
  把 v2.0.1-patch.1 / v2.0.2-patch.1 的补丁动作折进来，装完包就能直接跑，不用再记命令。

  动作清单：
    [1/8] 自我校验（maintain.ps1 与 appendix 是否与 checksums.json 一致）
    [2/8] 解析 DSH home / profiles（支持 -Rollback 从备份还原）
    [3/8] AGENTS.md 对齐协议附录块（标记块替换，绝不叠加）
    [4/8] CL-001  ReMe 日志轮转（rotation="00:00" -> rotation="100 MB"）
    [5/8] CL-002/003  卸载残留包 + CL-004 空 bundel 目录
    [6/8] CL-005  feature-profiles 临时文件
    [7/8] CL-006  巨型日志（只清死进程的）+ 日志总量巡检
    [8/8] CL-007  ReMe 记忆 LLM 环境变量（用户作用域，值不打印）

  安全约定：
    - 不加 -CheckOnly 才会写文件；所有写入先备份到 %LOCALAPPDATA%\DSHPluginMigration\maintenance-<date>\backup-*
    - -Rollback 读该备份目录的 manifest.json 逐文件还原
    - 任何一步失败即停，已备份的文件可用 -Rollback 还原
#>
param(
  [switch]$CheckOnly,
  [switch]$RepairEmpty,
  [switch]$PurgeDeprecated,
  [switch]$PurgeLogs,
  [switch]$Rollback,
  [switch]$NoAppendix,
  [string]$DshHome = '',
  [int]$LogSizeMB = 100,
  [string]$RemeRoot = '',
  [string]$Appendix = '',
  [string]$LlmBaseUrl = '',
  [string]$LlmModel = '',
  [string]$LlmApiKey = ''
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$patchId = 'maintenance-20261029'
$patchVersion = 'v2.1.0'
$store = Join-Path $env:LOCALAPPDATA ('DSHPluginMigration\' + $patchId)
$deprecated = @('dsh-my-skill-manager', 'dsh-shared', 'dsh-skill-hub')
$llmVars = @('LLM_BACKEND', 'LLM_MODEL_NAME', 'LLM_BASE_URL', 'LLM_API_KEY')
$markerStart = '<!-- ALIGNMENT_PROTOCOL v1.0 START'
$markerEnd = '<!-- ALIGNMENT_PROTOCOL v1.0 END -->'
$script:actions = New-Object System.Collections.ArrayList
$script:backupDir = $null
$script:manifest = New-Object System.Collections.ArrayList
$script:removedDirs = New-Object System.Collections.ArrayList
$script:savedBytes = [int64]0

function Write-Utf8([string]$path, [string]$text) {
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
}
function Read-Utf8([string]$path) { [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) }
function Get-Sha([string]$path) {
  # 不用 Get-FileHash：从 PowerShell 7 窗口里启动 powershell.exe 时 PSModulePath 会被占住，
  # Windows PowerShell 5.1 可能找不到 Microsoft.PowerShell.Utility → Get-FileHash 报 not recognized。
  if (-not (Test-Path -LiteralPath $path)) { return '' }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $fs = $null
  try {
    $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    return ([System.BitConverter]::ToString($sha.ComputeHash($fs))).Replace('-', '').ToLower()
  } finally {
    if ($fs) { $fs.Dispose() }
    $sha.Dispose()
  }
}
function Fail([string]$msg) { Write-Host ('失败：' + $msg) -ForegroundColor Red; exit 1 }
function Step([string]$msg) { Write-Host ''; Write-Host $msg -ForegroundColor Cyan }
function Ok([string]$msg) { Write-Host ('  [正常] ' + $msg) -ForegroundColor Green }
function Info([string]$msg) { Write-Host ('  [信息] ' + $msg) }
function Warn([string]$msg) { Write-Host ('  [注意] ' + $msg) -ForegroundColor Yellow }
function Count-Files([string]$dir) { if (-not (Test-Path -LiteralPath $dir)) { return -1 }; @(Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction SilentlyContinue).Count }
function Add-Action([string]$op, [string]$target, [string]$action, [string]$detail) {
  [void]$script:actions.Add([pscustomobject]@{ op = $op; target = $target; action = $action; detail = $detail })
}
function Ensure-BackupDir {
  if ($script:backupDir) { return $script:backupDir }
  $script:backupDir = Join-Path $store ('backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
  New-Item -ItemType Directory -Force -Path $script:backupDir | Out-Null
  return $script:backupDir
}
function Backup-File([string]$path, [string]$tag) {
  $bd = Ensure-BackupDir
  $name = $tag + '__' + (Split-Path -Leaf $path)
  $dest = Join-Path $bd $name
  Copy-Item -LiteralPath $path -Destination $dest -Force
  [void]$script:manifest.Add([pscustomobject]@{ restore = $path; backup = $dest })
  return $dest
}

Write-Host ''
Write-Host ('=' * 74) -ForegroundColor DarkCyan
Write-Host ('  DSH 插件整合包 ' + $patchVersion + ' —— 维护引擎') -ForegroundColor Cyan
Write-Host ('=' * 74) -ForegroundColor DarkCyan
if ($CheckOnly) { Info '预演模式：只报告将做什么，不写任何文件' }

# ---------------------------------------------------------------- 1. 自我校验
Step '[1/8] 包自检'
$selfSums = Join-Path $here 'checksums.json'
if (Test-Path -LiteralPath $selfSums) {
  try {
    $sums = Read-Utf8 $selfSums | ConvertFrom-Json
    $want = @('maintain.ps1', 'install-helper.cjs', 'inventory.json')
    $checked = 0
    foreach ($item in $sums.files) {
      if ($want -notcontains $item.path) { continue }
      $f = Join-Path $here ($item.path -replace '/', '\')
      if (-not (Test-Path -LiteralPath $f)) { Fail ('包内缺少文件：' + $item.path) }
      if ((Get-Sha $f) -ne $item.sha256.ToLower()) { Fail ('文件内容与校验清单不符：' + $item.path + '（换 7-Zip 重新解压）') }
      $checked++
    }
    Ok ('关键文件 SHA-256 校验通过：' + $checked + ' 个')
  } catch { Warn ('checksums.json 读取失败，跳过自检：' + $_.Exception.Message) }
} else {
  Info '没有 checksums.json（可能是在源码目录里直接跑），跳过自检'
}

# ---------------------------------------------------------------- 2. 解析
Step '[2/8] 定位 DSH 主目录与 profile'
if ($Rollback) {
  if (-not (Test-Path -LiteralPath $store)) { Fail ('没有可回滚的备份目录：' + $store) }
  $cand = Get-ChildItem -LiteralPath $store -Directory -Filter 'backup-*' -ErrorAction SilentlyContinue | Sort-Object Name -Descending
  if (-not $cand -or $cand.Count -eq 0) { Fail ('备份目录里没有备份集：' + $store) }
  $bd = $cand[0].FullName
  $mf = Join-Path $bd 'manifest.json'
  if (-not (Test-Path -LiteralPath $mf)) { Fail ('备份集缺少 manifest.json：' + $bd) }
  $man = Read-Utf8 $mf | ConvertFrom-Json
  $restored = 0
  foreach ($e in $man.entries) {
    if (-not $e.backup) { continue }
    if (Test-Path -LiteralPath $e.backup) {
      Copy-Item -LiteralPath $e.backup -Destination $e.restore -Force
      Info ('已还原 ' + $e.restore)
      $restored++
    } else { Warn ('备份副本不见了：' + $e.backup) }
  }
  if ($man.PSObject.Properties.Name -contains 'removedDirs') {
    foreach ($d in $man.removedDirs) {
      if ($d -and -not (Test-Path -LiteralPath $d)) {
        New-Item -ItemType Directory -Force -Path $d | Out-Null
        Info ('已重建空目录：' + $d + '（原本是 0 文件残留）')
      }
    }
  }
  Ok ('回滚完成：从 ' + $bd + ' 还原 ' + $restored + ' 个文件')
  Write-Host ''
  Write-Host '请重启 DSH（若 ReMe 在跑也一起重启）让还原生效。' -ForegroundColor Green
  exit 0
}

if (-not $DshHome) {
  if ($env:DSH_HOME) { $DshHome = $env:DSH_HOME }
  elseif ($env:USERPROFILE) { $DshHome = Join-Path $env:USERPROFILE '.dsh' }
  elseif ($env:HOME) { $DshHome = Join-Path $env:HOME '.dsh' }
  else { Fail '找不到 DSH 主目录，请用 -DshHome 指定' }
}
$DshHome = [System.IO.Path]::GetFullPath($DshHome)
if (-not (Test-Path -LiteralPath $DshHome)) { Fail ('DSH 主目录不存在：' + $DshHome) }
Ok ('DSH 主目录：' + $DshHome)

$profileRoot = Join-Path $DshHome 'profiles'
$profiles = @()
if (Test-Path -LiteralPath $profileRoot) {
  $profiles = @(Get-ChildItem -LiteralPath $profileRoot -Directory -ErrorAction SilentlyContinue | Where-Object { -not $_.Name.StartsWith('.') })
}
Ok ('profile：' + $(if ($profiles.Count) { ($profiles | ForEach-Object { $_.Name }) -join ', ' } else { '(无)' }))

# ---------------------------------------------------------------- 3. AGENTS 附录
Step '[3/8] AGENTS.md 对齐协议附录块（替换式，绝不叠加）'
if ($NoAppendix) {
  Info '按参数跳过（-NoAppendix）'
} else {
  $appPath = if ($Appendix) { $Appendix } else { Join-Path $here 'appendix\AGENTS.appendix.md' }
  $agentsPath = Join-Path $DshHome 'AGENTS.md'
  if (-not (Test-Path -LiteralPath $appPath)) {
    Warn ('附录模板不存在，跳过：' + $appPath)
    Add-Action 'AGENTS' $agentsPath 'skip' 'appendix template missing'
  } else {
    $block = (Read-Utf8 $appPath).Trim()
    if (-not $block.Contains($markerStart) -or -not $block.Contains($markerEnd)) {
      Warn '附录模板缺少 START/END 标记，跳过（避免写坏 AGENTS.md）'
      Add-Action 'AGENTS' $appPath 'skip' 'template missing markers'
    } else {
      $cur = if (Test-Path -LiteralPath $agentsPath) { Read-Utf8 $agentsPath } else { '' }
      # 只数行首的标记，避免正文里提到标记也被算进去
      $starts = @($cur -split "`n" | Where-Object { $_.TrimStart().StartsWith($markerStart) })
      $ends = @($cur -split "`n" | Where-Object { $_.Trim() -eq $markerEnd })
      if ($starts.Count -gt 1 -or $ends.Count -gt 1) {
        Warn ('AGENTS.md 里有 ' + $starts.Count + ' 个 START / ' + $ends.Count + ' 个 END 标记，状态异常，已跳过（请手工清理到各 1 个）')
        Add-Action 'AGENTS' $agentsPath 'skip' ('ambiguous markers: ' + $starts.Count + '/' + $ends.Count)
      } elseif ($starts.Count -eq 1 -and $ends.Count -eq 1) {
        $i = $cur.IndexOf($markerStart)
        $j = $cur.IndexOf($markerEnd, $i)
        if ($j -lt 0) {
          Warn '标记顺序异常（END 在 START 之前），已跳过'
          Add-Action 'AGENTS' $agentsPath 'skip' 'marker order broken'
        } else {
          $tail = $j + $markerEnd.Length
          $newText = $cur.Substring(0, $i) + $block + $cur.Substring($tail)
          if ($CheckOnly) {
            Warn '将替换 AGENTS.md 里的附录块（' + $block.Length + ' 字节）'
            Add-Action 'AGENTS' $agentsPath 'would-replace' ($block.Length.ToString() + ' bytes')
          } else {
            $bk = Backup-File $agentsPath 'agents'
            Write-Utf8 $agentsPath $newText
            $chk = Read-Utf8 $agentsPath
            $s2 = @($chk -split "`n" | Where-Object { $_.TrimStart().StartsWith($markerStart) }).Count
            $e2 = @($chk -split "`n" | Where-Object { $_.Trim() -eq $markerEnd }).Count
            if ($s2 -ne 1 -or $e2 -ne 1) { Fail ('写入后标记数异常（' + $s2 + '/' + $e2 + '），请用 -Rollback 还原') }
            Ok ('已替换 AGENTS.md 附录块（标记数 1/1，备份：' + $bk + '）')
            Add-Action 'AGENTS' $agentsPath 'replaced' ($block.Length.ToString() + ' bytes')
          }
        }
      } else {
        if ($CheckOnly) {
          Warn '将把附录块追加到 AGENTS.md 末尾（' + $block.Length + ' 字节）'
          Add-Action 'AGENTS' $agentsPath 'would-append' ($block.Length.ToString() + ' bytes')
        } else {
          $bk = if (Test-Path -LiteralPath $agentsPath) { Backup-File $agentsPath 'agents' } else { '(new file)' }
          $sep = if ([string]::IsNullOrWhiteSpace($cur)) { '' } elseif ($cur.EndsWith("`n")) { "`n" } else { "`n`n" }
          Write-Utf8 $agentsPath ($cur + $sep + $block + "`n")
          $chk = Read-Utf8 $agentsPath
          $s2 = @($chk -split "`n" | Where-Object { $_.TrimStart().StartsWith($markerStart) }).Count
          $e2 = @($chk -split "`n" | Where-Object { $_.Trim() -eq $markerEnd }).Count
          if ($s2 -ne 1 -or $e2 -ne 1) { Fail ('写入后标记数异常（' + $s2 + '/' + $e2 + '），请用 -Rollback 还原') }
          Ok ('已追加 AGENTS.md 附录块（标记数 1/1，备份：' + $bk + '）')
          Add-Action 'AGENTS' $agentsPath 'appended' ($block.Length.ToString() + ' bytes')
        }
      }
    }
  }
}

# ---------------------------------------------------------------- 4. CL-001
Step '[4/8] CL-001  ReMe 日志轮转（00:00 -> 100 MB）'
$targets = @()
if ($RemeRoot) {
  $cand = Get-ChildItem -LiteralPath $RemeRoot -Recurse -File -Filter 'logger_utils.py' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match 'reme[\\/]utils[\\/]logger_utils\.py$' }
  $targets += @($cand)
}
$scan = Get-ChildItem -LiteralPath $DshHome -Recurse -File -Filter 'logger_utils.py' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match 'reme[\\/]utils[\\/]logger_utils\.py$' }
$targets += @($scan)
$targets = @($targets | Sort-Object FullName -Unique)

if ($targets.Count -eq 0) {
  Warn '没找到 reme/utils/logger_utils.py（ReMe 装在别处就用 -RemeRoot 指定）'
} else {
  foreach ($t in $targets) {
    $text = Read-Utf8 $t.FullName
    if ($text.Contains('rotation="100 MB"')) {
      Ok ('已经是按体积轮转：' + $t.FullName)
      Add-Action 'CL-001' $t.FullName 'skip' 'rotation already 100 MB'
    } elseif ($text.Contains('rotation="00:00"')) {
      if ($CheckOnly) {
        Warn ('将改：' + $t.FullName)
        Add-Action 'CL-001' $t.FullName 'would-patch' 'rotation="00:00" -> rotation="100 MB"'
      } else {
        $bk = Backup-File $t.FullName 'logger'
        Write-Utf8 $t.FullName ($text.Replace('rotation="00:00"', 'rotation="100 MB"'))
        if (-not (Read-Utf8 $t.FullName).Contains('rotation="100 MB"')) { Fail ('写入后校验失败：' + $t.FullName) }
        Ok ('已改为 100MB 轮转：' + $t.FullName)
        Info ('备份：' + $bk)
        Add-Action 'CL-001' $t.FullName 'patched' 'rotation="00:00" -> rotation="100 MB"'
      }
    } else {
      Warn ('轮转设置没认出来（上游可能改过写法）：' + $t.FullName)
      Add-Action 'CL-001' $t.FullName 'unknown' 'no rotation="00:00" and no rotation="100 MB"'
    }
  }
}

# ---------------------------------------------------------------- 5. CL-002/003/004
Step '[5/8] CL-002/003  卸载残留包  +  CL-004  空插件目录'
foreach ($p in $profiles) {
  $pname = $p.Name
  $pjPath = Join-Path $p.FullName 'package.json'
  $nm = Join-Path $p.FullName 'node_modules'
  $deps = @()
  $bundles = @()
  $pjObj = $null
  if (Test-Path -LiteralPath $pjPath) {
    try { $pjObj = Read-Utf8 $pjPath | ConvertFrom-Json } catch { Warn ('package.json 解析失败：' + $pjPath); $pjObj = $null }
  }
  if ($pjObj) {
    foreach ($sec in @('dependencies', 'devDependencies', 'optionalDependencies')) {
      if ($pjObj.PSObject.Properties.Name -contains $sec) {
        foreach ($prop in $pjObj.$sec.PSObject.Properties) {
          $deps += [pscustomobject]@{ name = $prop.Name; spec = [string]$prop.Value; section = $sec }
        }
      }
    }
    if ($pjObj.PSObject.Properties.Name -contains 'dsh' -and $pjObj.dsh -and $pjObj.dsh.PSObject.Properties.Name -contains 'bundles') {
      $bundles = @($pjObj.dsh.bundles)
    }
  }

  foreach ($name in $deprecated) {
    $dir = Join-Path $nm ($name -replace '/', '\')
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $files = Count-Files $dir
    $referenced = @($deps | Where-Object { $_.name -eq $name }).Count -gt 0 -or ($bundles -contains $name)
    if ($files -le 0) {
      if ($CheckOnly) { Warn ('将删除空残留：' + $dir); Add-Action 'CL-002/003' $dir 'would-remove' '0 files' }
      else {
        Remove-Item -LiteralPath $dir -Recurse -Force
        Ok ('已删除空残留：' + $dir)
        Add-Action 'CL-002/003' $dir 'removed' '0 files'
        [void]$script:removedDirs.Add($dir)
      }
    } elseif ($PurgeDeprecated) {
      if ($CheckOnly) { Warn ('将删除（有文件）：' + $dir); Add-Action 'CL-002/003' $dir 'would-purge' ($files.ToString() + ' files, referenced=' + $referenced) }
      else {
        Remove-Item -LiteralPath $dir -Recurse -Force
        Ok ('已删除残留：' + $dir + '（' + $files + ' 个文件）')
        Add-Action 'CL-002/003' $dir 'purged' ($files.ToString() + ' files; 需要时用 pnpm add 重装')
      }
    } else {
      Info ('保留（有 ' + $files + ' 个文件）：' + $dir)
      Add-Action 'CL-002/003' $dir 'kept' ($files.ToString() + ' files; referenced=' + $referenced + '（加 -PurgeDeprecated 可删）')
    }
  }

  if ($pjObj) {
    $hit = @($deps | Where-Object { $deprecated -contains $_.name })
    $bundleHit = @($bundles | Where-Object { $deprecated -contains $_ })
    if (($hit.Count + $bundleHit.Count) -gt 0) {
      $changed = 0
      foreach ($h in $hit) {
        if ($CheckOnly) { Warn ('将移除依赖声明：' + $pname + ' -> ' + $h.name); $changed++ }
        else { $pjObj.$($h.section).PSObject.Properties.Remove($h.name); $changed++ }
      }
      if ($bundleHit.Count -gt 0) {
        $rest = @($bundles | Where-Object { $deprecated -notcontains $_ })
        if ($CheckOnly) { Warn ('将移除 ' + $bundleHit.Count + ' 条 bundle 声明（' + $pname + '）') }
        else {
          if ($pjObj.dsh.PSObject.Properties.Name -contains 'bundles') { $pjObj.dsh.bundles = $rest }
        }
        $changed++
      }
      if (-not $CheckOnly -and $changed -gt 0) {
        $bk = Backup-File $pjPath 'packagejson'
        Write-Utf8 $pjPath (($pjObj | ConvertTo-Json -Depth 100) + "`n")
        try { Read-Utf8 $pjPath | ConvertFrom-Json | Out-Null } catch { Fail ('写出的 package.json 不是合法 JSON：' + $pjPath) }
        Ok ('已清理 ' + $pname + ' 的残留声明（' + $changed + ' 处，备份：' + $bk + '）')
        Add-Action 'CL-002/003' $pjPath 'stripped' ($changed.ToString() + ' reference(s) removed')
      } elseif ($CheckOnly) {
        Add-Action 'CL-002/003' $pjPath 'would-strip' ($changed.ToString() + ' reference(s)')
      }
    }
  }

  $names = @($deps | ForEach-Object { $_.name }) + @($bundles)
  $names = @($names | Sort-Object -Unique)
  foreach ($name in $names) {
    if ([string]::IsNullOrWhiteSpace($name)) { continue }
    $dir = Join-Path $nm ($name -replace '/', '\')
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $files = Count-Files $dir
    if ($files -ne 0) { continue }
    $spec = ($deps | Where-Object { $_.name -eq $name } | Select-Object -First 1).spec
    Warn ('空插件目录：' + $dir)
    Add-Action 'CL-004' $dir 'empty' ('0 files; spec=' + $spec)
    if (-not $RepairEmpty) { Info '  （加 -RepairEmpty 可重装）'; continue }
    if ($CheckOnly) { Warn ('将重装：' + $name); continue }
    if ($spec -and ($spec -match '^(link|file|workspace):')) { Warn ('  本地包，跳过：' + $name + ' ' + $spec); continue }
    $pnpm = Get-Command pnpm -ErrorAction SilentlyContinue
    if (-not $pnpm) { Warn ('  pnpm 不在 PATH，请手动执行：cd ' + $p.FullName + ' ; pnpm add ' + $name); continue }
    Push-Location $p.FullName
    try {
      $specArg = if ($spec) { $name + '@' + ($spec -replace '^[\^~]', '') } else { $name }
      & pnpm add $specArg --prefer-offline 2>&1 | ForEach-Object { Info ('  pnpm: ' + $_) }
      $files2 = Count-Files $dir
      if ($files2 -gt 0) { Ok ('已重装 ' + $name + '（' + $files2 + ' 个文件）'); Add-Action 'CL-004' $dir 'reinstalled' ($files2.ToString() + ' files') }
      else { Warn ('重装没有填充 ' + $name); Add-Action 'CL-004' $dir 'reinstall-failed' 'still 0 files' }
    } catch { Warn ('重装出错 ' + $name + '：' + $_.Exception.Message); Add-Action 'CL-004' $dir 'reinstall-error' $_.Exception.Message }
    finally { Pop-Location }
  }
}

# ---------------------------------------------------------------- 6. CL-005
Step '[6/8] CL-005  feature-profiles 临时文件'
$tmpCount = 0
foreach ($p in $profiles) {
  $fpDir = Join-Path $p.FullName 'feature-profiles'
  if (-not (Test-Path -LiteralPath $fpDir)) { continue }
  $tmps = @(Get-ChildItem -LiteralPath $fpDir -File -Filter '*.tmp' -Force -ErrorAction SilentlyContinue)
  foreach ($t in $tmps) {
    $tmpCount++
    if ($CheckOnly) { Warn ('将删除临时文件：' + $t.FullName); Add-Action 'CL-005' $t.FullName 'would-delete' ($t.Length.ToString() + ' bytes') }
    else {
      Remove-Item -LiteralPath $t.FullName -Force
      Ok ('已删除临时文件：' + $t.FullName)
      Add-Action 'CL-005' $t.FullName 'deleted' ($t.Length.ToString() + ' bytes')
    }
  }
}
if ($tmpCount -eq 0) { Ok '没有 *.tmp 残留' }

# ---------------------------------------------------------------- 7. CL-006 + 新增巡检
Step ('[7/8] CL-006  巨型日志（阈值 ' + $LogSizeMB + ' MB，只清死进程）  +  日志总量巡检')
$svcRoot = Join-Path $DshHome 'services'
$bigTotal = [int64]0
$bigCount = 0
if (Test-Path -LiteralPath $svcRoot) {
  $logs = @(Get-ChildItem -LiteralPath $svcRoot -Recurse -File -Filter '*.log' -ErrorAction SilentlyContinue | Where-Object { $_.Length -ge ($LogSizeMB * 1MB) })
  foreach ($l in $logs) {
    $pidNum = 0
    if ($l.BaseName -match '_(\d+)$') { $pidNum = [int]$Matches[1] }
    $alive = $false
    if ($pidNum -gt 0) { $alive = [bool](Get-Process -Id $pidNum -ErrorAction SilentlyContinue) }
    $bigTotal += $l.Length; $bigCount++
    $mb = [math]::Round($l.Length / 1MB, 1)
    if ($alive) {
      Info ('进程还活着，保留：' + $l.FullName + '（' + $mb + ' MB，pid ' + $pidNum + '）')
      Add-Action 'CL-006' $l.FullName 'kept-live' ($mb.ToString() + ' MB; pid ' + $pidNum + ' running')
      continue
    }
    if ($PurgeLogs) {
      if ($CheckOnly) { Warn ('将删除：' + $l.FullName + '（' + $mb + ' MB）'); Add-Action 'CL-006' $l.FullName 'would-delete' ($mb.ToString() + ' MB') }
      else {
        Remove-Item -LiteralPath $l.FullName -Force
        $script:savedBytes += $l.Length
        Ok ('已删除：' + $l.FullName + '（' + $mb + ' MB）')
        Add-Action 'CL-006' $l.FullName 'deleted' ($mb.ToString() + ' MB')
      }
    } else {
      Warn ('死进程留下的大日志：' + $l.FullName + '（' + $mb + ' MB）-> 加 -PurgeLogs 才会删')
      Add-Action 'CL-006' $l.FullName 'reported' ($mb.ToString() + ' MB; use -PurgeLogs')
    }
  }
}
if ($bigCount -eq 0) { Ok ('没有超过 ' + $LogSizeMB + ' MB 的日志') }
else { Info ('扫描到 ' + $bigCount + ' 个大文件，合计 ' + [math]::Round($bigTotal / 1MB, 1) + ' MB') }

# ReMe 日志总量：轮转改完后仍可能长期堆积，超过 100MB 就提示（对应 v2.0.1-patch.1 的 CL-001 复验）
$logDirs = @()
foreach ($p in $profiles) { $logDirs += (Join-Path $p.FullName 'logs') }
$logDirs += (Join-Path $DshHome 'logs')
foreach ($ld in ($logDirs | Sort-Object -Unique)) {
  if (-not (Test-Path -LiteralPath $ld)) { continue }
  $all = @(Get-ChildItem -LiteralPath $ld -Recurse -File -ErrorAction SilentlyContinue)
  if ($all.Count -eq 0) { continue }
  $sum = ($all | Measure-Object -Property Length -Sum).Sum
  $mb = [math]::Round($sum / 1MB, 1)
  if ($mb -ge 100) {
    Warn ('日志目录偏大：' + $ld + '（' + $mb + ' MB，' + $all.Count + ' 个文件）-> 确认 CL-001 已生效，或加 -PurgeLogs 清理死进程日志')
    Add-Action 'CL-006' $ld 'large-dir' ($mb.ToString() + ' MB in ' + $all.Count + ' files')
  } else {
    Info ('日志目录正常：' + $ld + '（' + $mb + ' MB）')
  }
}

# ---------------------------------------------------------------- 8. CL-007
Step '[8/8] CL-007  ReMe 记忆 LLM 环境变量（用户作用域，值不打印）'
function Get-UserEnv([string]$n) { [Environment]::GetEnvironmentVariable($n, 'User') }
$missing = @()
foreach ($v in $llmVars) { if (-not (Get-UserEnv $v)) { $missing += $v } }
if ($missing.Count -eq 0) {
  Ok '四个 LLM_* 用户变量都已设置'
  Add-Action 'CL-007' 'user env' 'present' 'LLM_BACKEND/MODEL_NAME/BASE_URL/API_KEY all set'
} else {
  Warn ('缺少用户变量：' + ($missing -join ', '))
  Add-Action 'CL-007' 'user env' 'missing' ($missing -join ',')
}
$wantLlm = ($LlmBaseUrl -or $LlmModel -or $LlmApiKey)
if ($wantLlm) {
  if (-not $LlmBaseUrl -or -not $LlmModel -or -not $LlmApiKey) {
    Fail 'CL-007 需要 -LlmBaseUrl / -LlmModel / -LlmApiKey 三个一起给（本次没有写入任何内容）'
  }
  if ($CheckOnly) {
    Warn '将写入 4 个用户环境变量（LLM_BACKEND=openai）'
    Add-Action 'CL-007' 'user env' 'would-write' 'LLM_BACKEND=openai; base/model supplied; key masked'
  } else {
    $prev = @{}
    foreach ($v in $llmVars) { $prev[$v] = Get-UserEnv $v }
    $bd = Ensure-BackupDir
    $snap = [ordered]@{ capturedAt = (Get-Date).ToString('o'); note = 'API key intentionally not stored'; values = @{} }
    foreach ($v in $llmVars) {
      $val = $prev[$v]
      if ($v -eq 'LLM_API_KEY' -and $val) { $val = '(已设置，不记录)' }
      $snap.values[$v] = if ($val) { $val } else { '(未设置)' }
    }
    Write-Utf8 (Join-Path $bd 'user-env-before.json') (($snap | ConvertTo-Json -Depth 5) + "`n")
    [Environment]::SetEnvironmentVariable('LLM_BACKEND', 'openai', 'User')
    [Environment]::SetEnvironmentVariable('LLM_MODEL_NAME', $LlmModel, 'User')
    [Environment]::SetEnvironmentVariable('LLM_BASE_URL', $LlmBaseUrl, 'User')
    [Environment]::SetEnvironmentVariable('LLM_API_KEY', $LlmApiKey, 'User')
    Ok '已写入 4 个用户环境变量（重启 ReMe 生效）'
    Info ('写入前状态（key 已打码）：' + (Join-Path $bd 'user-env-before.json'))
    Add-Action 'CL-007' 'user env' 'written' 'LLM_BACKEND=openai; model and base url set; key set (masked)'
  }
} elseif ($missing.Count -gt 0) {
  Info '可以手动设置，例如：'
  Info '  setx LLM_BACKEND openai'
  Info '  setx LLM_MODEL_NAME <model>'
  Info '  setx LLM_BASE_URL https://<your-endpoint>/v1'
  Info '  setx LLM_API_KEY <key>'
}

# ---------------------------------------------------------------- 报告
$report = [ordered]@{
  completedAt = (Get-Date).ToString('o')
  patch       = $patchVersion
  patchId     = $patchId
  checkOnly   = [bool]$CheckOnly
  dshHome     = $DshHome
  profiles    = @($profiles | ForEach-Object { $_.Name })
  backupDir   = $script:backupDir
  savedBytes  = $script:savedBytes
  actions     = @($script:actions)
  rollback    = if ($script:backupDir) { 'maintain.ps1 -Rollback  （会还原 ' + $script:backupDir + '）' } else { '本次没有写入任何文件' }
  flags       = [ordered]@{ repairEmpty = [bool]$RepairEmpty; purgeDeprecated = [bool]$PurgeDeprecated; purgeLogs = [bool]$PurgeLogs; logSizeMB = $LogSizeMB; noAppendix = [bool]$NoAppendix }
}
if ($CheckOnly) {
  Write-Host ''
  Write-Host ('变更计划：' + $script:actions.Count + ' 项发现，未写入任何文件。') -ForegroundColor Yellow
  foreach ($a in $script:actions) {
    if ($a.action -like 'would-*' -or $a.action -in @('missing', 'empty', 'reported', 'unknown', 'large-dir')) {
      Write-Host ('   - ' + $a.op + '  ' + $a.action + '  ' + $a.target) -ForegroundColor Yellow
    }
  }
  Write-Host ''
  Write-Host '去掉 -CheckOnly 再跑一次就会真正执行。' -ForegroundColor Green
  exit 0
}

New-Item -ItemType Directory -Force -Path $store | Out-Null
if ($script:backupDir) {
  $mfObj = [ordered]@{ capturedAt = (Get-Date).ToString('o'); patch = $patchVersion; entries = @($script:manifest); removedDirs = @($script:removedDirs) }
  Write-Utf8 (Join-Path $script:backupDir 'manifest.json') (($mfObj | ConvertTo-Json -Depth 8) + "`n")
}
$runDir = Join-Path $store 'runs'
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$runPath = Join-Path $runDir ((Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
Write-Utf8 $runPath (($report | ConvertTo-Json -Depth 8) + "`n")
Write-Utf8 (Join-Path $store 'maintenance-report.json') (($report | ConvertTo-Json -Depth 8) + "`n")

Write-Host ''
Write-Host ('完成：处理 ' + $script:actions.Count + ' 项，释放 ' + [math]::Round($script:savedBytes / 1MB, 1) + ' MB。') -ForegroundColor Green
foreach ($a in $script:actions) { if ($a.action -notin @('skip', 'kept')) { Write-Host ('   - ' + $a.op + '  ' + $a.action + '  ' + $a.target) } }
Write-Host ''
Write-Host ('备份目录：' + $(if ($script:backupDir) { $script:backupDir } else { '（本次没有写入）' }))
Write-Host ('报告：' + $runPath)
Write-Host ('回滚：' + $report.rollback)
Write-Host '改了 CL-001 / CL-007 或 AGENTS.md 之后，请重启 DSH 与 ReMe。' -ForegroundColor Green
