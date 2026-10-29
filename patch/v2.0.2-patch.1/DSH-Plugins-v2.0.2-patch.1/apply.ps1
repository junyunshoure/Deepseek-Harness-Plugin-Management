# DSH-Plugins v2.0.2-patch.1 maintenance engine (CL-001 .. CL-007)
# ASCII-only on purpose: Windows PowerShell 5.1 mis-parses non-BOM UTF-8 scripts.
# Nothing is written unless you leave -CheckOnly out. Every write is backed up first.
param(
  [switch]$CheckOnly,
  [switch]$RepairEmpty,
  [switch]$PurgeDeprecated,
  [switch]$PurgeLogs,
  [switch]$Rollback,
  [string]$DshHome = '',
  [int]$LogSizeMB = 100,
  [string]$RemeRoot = '',
  [string]$LlmBaseUrl = '',
  [string]$LlmModel = '',
  [string]$LlmApiKey = ''
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$patchId = 'maintenance-20261029'
$patchVersion = 'v2.0.2-patch.1'
$store = Join-Path $env:LOCALAPPDATA ('DSHPluginMigration\' + $patchId)
$deprecated = @('dsh-my-skill-manager', 'dsh-shared', 'dsh-skill-hub')
$llmVars = @('LLM_BACKEND', 'LLM_MODEL_NAME', 'LLM_BASE_URL', 'LLM_API_KEY')
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
function Get-Sha([string]$path) { if (Test-Path -LiteralPath $path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower() } else { '' } }
function Fail([string]$msg) { Write-Host ('FAILED: ' + $msg) -ForegroundColor Red; exit 1 }
function Step([string]$msg) { Write-Host ''; Write-Host $msg -ForegroundColor Cyan }
function Ok([string]$msg) { Write-Host ('  [ok]   ' + $msg) -ForegroundColor Green }
function Info([string]$msg) { Write-Host ('  [info] ' + $msg) }
function Warn([string]$msg) { Write-Host ('  [warn] ' + $msg) -ForegroundColor Yellow }
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

# ---------------------------------------------------------------- 1. self-check
Step ('[1/7] Package self-check (' + $patchVersion + ')')
$sumsPath = Join-Path $here 'checksums.json'
if (-not (Test-Path -LiteralPath $sumsPath)) { Fail 'checksums.json missing' }
$sums = Read-Utf8 $sumsPath | ConvertFrom-Json
$verified = 0
foreach ($item in $sums.files) {
  $f = Join-Path $here $item.path
  if (-not (Test-Path -LiteralPath $f)) { Fail ('missing file: ' + $item.path) }
  if ((Get-Sha $f) -ne $item.sha256.ToLower()) { Fail ('checksum mismatch: ' + $item.path) }
  $verified++
}
Ok ($verified.ToString() + ' file(s) SHA-256 verified')

# ---------------------------------------------------------------- 2. resolve
Step '[2/7] Resolve DSH home and profiles'
if ($Rollback) {
  if (-not (Test-Path -LiteralPath $store)) { Fail 'no backup store found: ' + $store }
  $cand = Get-ChildItem -LiteralPath $store -Directory -Filter 'backup-*' -ErrorAction SilentlyContinue | Sort-Object Name -Descending
  if (-not $cand -or $cand.Count -eq 0) { Fail 'no backup set in ' + $store }
  $bd = $cand[0].FullName
  $mf = Join-Path $bd 'manifest.json'
  if (-not (Test-Path -LiteralPath $mf)) { Fail 'manifest.json missing in ' + $bd }
  $man = Read-Utf8 $mf | ConvertFrom-Json
  $restored = 0
  foreach ($e in $man.entries) {
    if (-not $e.backup) { continue }
    if (Test-Path -LiteralPath $e.backup) {
      Copy-Item -LiteralPath $e.backup -Destination $e.restore -Force
      Info ('restored ' + $e.restore)
      $restored++
    } else { Warn ('backup copy missing: ' + $e.backup) }
  }
  if ($man.PSObject.Properties.Name -contains 'removedDirs') {
    foreach ($d in $man.removedDirs) {
      if ($d -and -not (Test-Path -LiteralPath $d)) {
        New-Item -ItemType Directory -Force -Path $d | Out-Null
        Info ('recreated empty dir: ' + $d + ' (was a 0-file residue)')
      }
    }
  }
  Ok ('rollback from ' + $bd + ': ' + $restored + ' file(s) restored')
  Write-Host ''
  Write-Host 'Restart DSH (and ReMe, if it was running) to pick the restored files up.' -ForegroundColor Green
  exit 0
}

if (-not $DshHome) {
  if ($env:DSH_HOME) { $DshHome = $env:DSH_HOME }
  elseif ($env:USERPROFILE) { $DshHome = Join-Path $env:USERPROFILE '.dsh' }
  elseif ($env:HOME) { $DshHome = Join-Path $env:HOME '.dsh' }
  else { Fail 'cannot resolve the DSH home directory; pass -DshHome' }
}
$DshHome = [System.IO.Path]::GetFullPath($DshHome)
if (-not (Test-Path -LiteralPath $DshHome)) { Fail 'DSH home not found: ' + $DshHome }
Ok ('DSH home: ' + $DshHome)

$profileRoot = Join-Path $DshHome 'profiles'
$profiles = @()
if (Test-Path -LiteralPath $profileRoot) {
  $profiles = @(Get-ChildItem -LiteralPath $profileRoot -Directory -ErrorAction SilentlyContinue | Where-Object { -not $_.Name.StartsWith('.') })
}
Ok ('profiles: ' + $(if ($profiles.Count) { ($profiles | ForEach-Object { $_.Name }) -join ', ' } else { '(none)' }))
if ($CheckOnly) { Info 'check-only mode: nothing will be written' }

# ---------------------------------------------------------------- 3. CL-001
Step '[3/7] CL-001  ReMe log rotation (00:00 -> 100 MB)'
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

if ($targets.Count -eq 0) { Warn 'no reme/utils/logger_utils.py found under the DSH home (use -RemeRoot if ReMe lives elsewhere)' }
foreach ($t in $targets) {
  $text = Read-Utf8 $t.FullName
  if ($text.Contains('rotation="100 MB"')) {
    Ok ('already sized-rotation: ' + $t.FullName)
    Add-Action 'CL-001' $t.FullName 'skip' 'rotation already 100 MB'
  } elseif ($text.Contains('rotation="00:00"')) {
    if ($CheckOnly) {
      Warn ('would patch rotation in: ' + $t.FullName)
      Add-Action 'CL-001' $t.FullName 'would-patch' 'rotation="00:00" -> rotation="100 MB"'
    } else {
      $bk = Backup-File $t.FullName 'logger'
      $new = $text.Replace('rotation="00:00"', 'rotation="100 MB"')
      Write-Utf8 $t.FullName $new
      $chk = Read-Utf8 $t.FullName
      if (-not $chk.Contains('rotation="100 MB"')) { Fail ('post-write check failed: ' + $t.FullName) }
      Ok ('patched: ' + $t.FullName)
      Info ('backup: ' + $bk)
      Add-Action 'CL-001' $t.FullName 'patched' 'rotation="00:00" -> rotation="100 MB"'
    }
  } else {
    Warn ('rotation setting not recognised (upstream changed?): ' + $t.FullName)
    Add-Action 'CL-001' $t.FullName 'unknown' 'no rotation="00:00" and no rotation="100 MB"'
  }
}

# ---------------------------------------------------------------- 4. CL-002/003 + CL-004
Step '[4/7] CL-002/003  deprecated package residue  +  CL-004  empty bundle directories'
foreach ($p in $profiles) {
  $pname = $p.Name
  $pjPath = Join-Path $p.FullName 'package.json'
  $nm = Join-Path $p.FullName 'node_modules'
  $deps = @()
  $bundles = @()
  $pjObj = $null
  if (Test-Path -LiteralPath $pjPath) {
    try { $pjObj = Read-Utf8 $pjPath | ConvertFrom-Json } catch { Warn ('package.json not parseable: ' + $pjPath); $pjObj = $null }
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

  # --- CL-002/003: deprecated dirs
  foreach ($name in $deprecated) {
    $dir = Join-Path $nm ($name -replace '/', '\')
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $files = Count-Files $dir
    $referenced = @($deps | Where-Object { $_.name -eq $name }).Count -gt 0 -or ($bundles -contains $name)
    if ($files -le 0) {
      if ($CheckOnly) { Warn ('would remove empty residue: ' + $dir); Add-Action 'CL-002/003' $dir 'would-remove' '0 files' }
      else {
        Remove-Item -LiteralPath $dir -Recurse -Force
        Ok ('removed empty residue: ' + $dir)
        Add-Action 'CL-002/003' $dir 'removed' '0 files'
        [void]$script:removedDirs.Add($dir)
      }
    } elseif ($PurgeDeprecated) {
      if ($CheckOnly) { Warn ('would purge (has files): ' + $dir); Add-Action 'CL-002/003' $dir 'would-purge' ($files.ToString() + ' files, referenced=' + $referenced) }
      else {
        Remove-Item -LiteralPath $dir -Recurse -Force
        Ok ('purged deprecated dir: ' + $dir + ' (' + $files + ' files)')
        Add-Action 'CL-002/003' $dir 'purged' ($files.ToString() + ' files; reinstall with pnpm add if a plugin needs it')
      }
    } else {
      Info ('kept (has ' + $files + ' files): ' + $dir)
      Add-Action 'CL-002/003' $dir 'kept' ($files.ToString() + ' files; referenced=' + $referenced + ' (use -PurgeDeprecated to delete)')
    }
  }

  # --- CL-002/003: strip references from package.json
  if ($pjObj) {
    $hit = @($deps | Where-Object { $deprecated -contains $_.name })
    $bundleHit = @($bundles | Where-Object { $deprecated -contains $_ })
    if (($hit.Count + $bundleHit.Count) -gt 0) {
      $changed = 0
      foreach ($h in $hit) {
        if ($CheckOnly) { Warn ('would strip dependency: ' + $pname + ' -> ' + $h.name); $changed++ }
        else {
          $pjObj.$($h.section).PSObject.Properties.Remove($h.name); $changed++
        }
      }
      if ($bundleHit.Count -gt 0) {
        $rest = @($bundles | Where-Object { $deprecated -notcontains $_ })
        if ($CheckOnly) { Warn ('would strip ' + $bundleHit.Count + ' bundle entry(ies) in ' + $pname) }
        else {
          if ($pjObj.dsh.PSObject.Properties.Name -contains 'bundles') {
            if ($pjObj.dsh.bundles -is [array]) { $pjObj.dsh.bundles = $rest } else { $pjObj.dsh.bundles = $rest }
          }
        }
        $changed++
      }
      if (-not $CheckOnly -and $changed -gt 0) {
        $bk = Backup-File $pjPath 'packagejson'
        $json = ($pjObj | ConvertTo-Json -Depth 100)
        Write-Utf8 $pjPath ($json + "`n")
        try { Read-Utf8 $pjPath | ConvertFrom-Json | Out-Null } catch { Fail ('written package.json is not valid JSON: ' + $pjPath) }
        Ok ('stripped deprecated references in ' + $pname + ' (' + $changed + ')')
        Info ('backup: ' + $bk)
        Add-Action 'CL-002/003' $pjPath 'stripped' ($changed.ToString() + ' reference(s) removed')
      } elseif ($CheckOnly) {
        Add-Action 'CL-002/003' $pjPath 'would-strip' ($changed.ToString() + ' reference(s)')
      }
    }
  }

  # --- CL-004: empty declared dependency dirs
  $names = @($deps | ForEach-Object { $_.name }) + @($bundles)
  $names = @($names | Sort-Object -Unique)
  foreach ($name in $names) {
    if ([string]::IsNullOrWhiteSpace($name)) { continue }
    $dir = Join-Path $nm ($name -replace '/', '\')
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $files = Count-Files $dir
    if ($files -ne 0) { continue }
    $spec = ($deps | Where-Object { $_.name -eq $name } | Select-Object -First 1).spec
    Warn ('empty bundle directory: ' + $dir)
    Add-Action 'CL-004' $dir 'empty' ('0 files; spec=' + $spec)
    if (-not $RepairEmpty) { Info '  (pass -RepairEmpty to reinstall it)'; continue }
    if ($CheckOnly) { Warn ('would reinstall: ' + $name); continue }
    if ($spec -and ($spec -match '^(link|file|workspace):')) { Warn ('  local spec, skipped: ' + $name + ' ' + $spec); continue }
    $pnpm = Get-Command pnpm -ErrorAction SilentlyContinue
    if (-not $pnpm) { Warn ('  pnpm not on PATH; run manually: cd ' + $p.FullName + ' ; pnpm add ' + $name); continue }
    Push-Location $p.FullName
    try {
      $specArg = if ($spec) { $name + '@' + ($spec -replace '^[\^~]', '') } else { $name }
      & pnpm add $specArg --prefer-offline 2>&1 | ForEach-Object { Info ('  pnpm: ' + $_) }
      $files2 = Count-Files $dir
      if ($files2 -gt 0) { Ok ('reinstalled ' + $name + ' (' + $files2 + ' files)'); Add-Action 'CL-004' $dir 'reinstalled' ($files2.ToString() + ' files') }
      else { Warn ('reinstall did not populate ' + $name); Add-Action 'CL-004' $dir 'reinstall-failed' 'still 0 files' }
    } catch { Warn ('reinstall error for ' + $name + ': ' + $_.Exception.Message); Add-Action 'CL-004' $dir 'reinstall-error' $_.Exception.Message }
    finally { Pop-Location }
  }
}

# ---------------------------------------------------------------- 5. CL-005
Step '[5/7] CL-005  feature-profiles temp files'
$tmpCount = 0
foreach ($p in $profiles) {
  $fpDir = Join-Path $p.FullName 'feature-profiles'
  if (-not (Test-Path -LiteralPath $fpDir)) { continue }
  $tmps = @(Get-ChildItem -LiteralPath $fpDir -File -Filter '*.tmp' -Force -ErrorAction SilentlyContinue)
  if ($tmps.Count -eq 0) { continue }
  foreach ($t in $tmps) {
    $tmpCount++
    if ($CheckOnly) { Warn ('would delete temp file: ' + $t.FullName); Add-Action 'CL-005' $t.FullName 'would-delete' ($t.Length.ToString() + ' bytes') }
    else {
      Remove-Item -LiteralPath $t.FullName -Force
      Ok ('deleted temp file: ' + $t.FullName)
      Add-Action 'CL-005' $t.FullName 'deleted' ($t.Length.ToString() + ' bytes')
    }
  }
}
if ($tmpCount -eq 0) { Ok 'no *.tmp leftovers' }

# ---------------------------------------------------------------- 6. CL-006
Step ('[6/7] CL-006  giant logs (threshold ' + $LogSizeMB + ' MB, dead PID only)')
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
      Info ('live process, kept: ' + $l.FullName + ' (' + $mb + ' MB, pid ' + $pidNum + ')')
      Add-Action 'CL-006' $l.FullName 'kept-live' ($mb.ToString() + ' MB; pid ' + $pidNum + ' running')
      continue
    }
    if ($PurgeLogs) {
      if ($CheckOnly) { Warn ('would delete: ' + $l.FullName + ' (' + $mb + ' MB)'); Add-Action 'CL-006' $l.FullName 'would-delete' ($mb.ToString() + ' MB') }
      else {
        Remove-Item -LiteralPath $l.FullName -Force
        $script:savedBytes += $l.Length
        Ok ('deleted: ' + $l.FullName + ' (' + $mb + ' MB)')
        Add-Action 'CL-006' $l.FullName 'deleted' ($mb.ToString() + ' MB')
      }
    } else {
      Warn ('large dead-process log: ' + $l.FullName + ' (' + $mb + ' MB)  -> pass -PurgeLogs to delete')
      Add-Action 'CL-006' $l.FullName 'reported' ($mb.ToString() + ' MB; use -PurgeLogs')
    }
  }
}
if ($bigCount -eq 0) { Ok 'no log above the threshold' }
else { Info ('scanned ' + $bigCount + ' large file(s), total ' + [math]::Round($bigTotal / 1MB, 1) + ' MB') }

# ---------------------------------------------------------------- 7. CL-007
Step '[7/7] CL-007  ReMe memory LLM environment (user scope, values never printed)'
function Get-UserEnv([string]$n) { [Environment]::GetEnvironmentVariable($n, 'User') }
$missing = @()
foreach ($v in $llmVars) { if (-not (Get-UserEnv $v)) { $missing += $v } }
if ($missing.Count -eq 0) {
  Ok 'all four LLM_* user variables are set'
  Add-Action 'CL-007' 'user env' 'present' 'LLM_BACKEND/MODEL_NAME/BASE_URL/API_KEY all set'
} else {
  Warn ('missing user variable(s): ' + ($missing -join ', '))
  Add-Action 'CL-007' 'user env' 'missing' ($missing -join ',')
}
$wantLlm = ($LlmBaseUrl -or $LlmModel -or $LlmApiKey)
if ($wantLlm) {
  if (-not $LlmBaseUrl -or -not $LlmModel -or -not $LlmApiKey) {
    Fail 'CL-007 needs all three of -LlmBaseUrl, -LlmModel, -LlmApiKey (nothing was written)'
  }
  if ($CheckOnly) {
    Warn 'would write 4 user environment variables (LLM_BACKEND=openai)'
    Add-Action 'CL-007' 'user env' 'would-write' 'LLM_BACKEND=openai; base/model supplied; key masked'
  } else {
    $prev = @{}
    foreach ($v in $llmVars) { $prev[$v] = Get-UserEnv $v }
    $bd = Ensure-BackupDir
    $envSnap = [ordered]@{ capturedAt = (Get-Date).ToString('o'); note = 'API key intentionally not stored'; values = @{} }
    foreach ($v in $llmVars) {
      $val = $prev[$v]
      if ($v -eq 'LLM_API_KEY' -and $val) { $val = '(set, not recorded)' }
      $envSnap.values[$v] = if ($val) { $val } else { '(unset)' }
    }
    Write-Utf8 (Join-Path $bd 'user-env-before.json') (($envSnap | ConvertTo-Json -Depth 5) + "`n")
    [Environment]::SetEnvironmentVariable('LLM_BACKEND', 'openai', 'User')
    [Environment]::SetEnvironmentVariable('LLM_MODEL_NAME', $LlmModel, 'User')
    [Environment]::SetEnvironmentVariable('LLM_BASE_URL', $LlmBaseUrl, 'User')
    [Environment]::SetEnvironmentVariable('LLM_API_KEY', $LlmApiKey, 'User')
    Ok 'wrote 4 user environment variables (restart ReMe to pick them up)'
    Info ('previous state (key masked): ' + (Join-Path $bd 'user-env-before.json'))
    Add-Action 'CL-007' 'user env' 'written' 'LLM_BACKEND=openai; model and base url set; key set (masked)'
  }
} elseif ($missing.Count -gt 0) {
  Info 'set them manually, e.g.:'
  Info '  setx LLM_BACKEND openai'
  Info '  setx LLM_MODEL_NAME <model>'
  Info '  setx LLM_BASE_URL https://<your-endpoint>/v1'
  Info '  setx LLM_API_KEY <key>'
}

# ---------------------------------------------------------------- report
$reportDir = $store
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
  rollback    = if ($script:backupDir) { 'apply.ps1 -Rollback  (restores ' + $script:backupDir + ')' } else { 'nothing was written' }
  flags       = [ordered]@{ repairEmpty = [bool]$RepairEmpty; purgeDeprecated = [bool]$PurgeDeprecated; purgeLogs = [bool]$PurgeLogs; logSizeMB = $LogSizeMB }
}
if ($CheckOnly) {
  Write-Host ''
  Write-Host ('CHANGE PLAN: ' + $script:actions.Count + ' finding(s), nothing written.') -ForegroundColor Yellow
  foreach ($a in $script:actions) { if ($a.action -like 'would-*' -or $a.action -in @('missing', 'empty', 'reported', 'unknown')) { Write-Host ('   - ' + $a.op + '  ' + $a.action + '  ' + $a.target) -ForegroundColor Yellow } }
  Write-Host ''
  Write-Host 'Re-run without -CheckOnly to apply.' -ForegroundColor Green
  exit 0
}

New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
if ($script:backupDir) {
  $mfObj = [ordered]@{ capturedAt = (Get-Date).ToString('o'); patch = $patchVersion; entries = @($script:manifest); removedDirs = @($script:removedDirs) }
  Write-Utf8 (Join-Path $script:backupDir 'manifest.json') (($mfObj | ConvertTo-Json -Depth 8) + "`n")
}
$runDir = Join-Path $reportDir 'runs'
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$runPath = Join-Path $runDir ((Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
Write-Utf8 $runPath (($report | ConvertTo-Json -Depth 8) + "`n")
Write-Utf8 (Join-Path $reportDir 'maintenance-report.json') (($report | ConvertTo-Json -Depth 8) + "`n")

Write-Host ''
Write-Host ('DONE  ' + $script:actions.Count + ' finding(s) processed, ' + [math]::Round($script:savedBytes / 1MB, 1) + ' MB freed.') -ForegroundColor Green
foreach ($a in $script:actions) { if ($a.action -notin @('skip', 'kept')) { Write-Host ('   - ' + $a.op + '  ' + $a.action + '  ' + $a.target) } }
Write-Host ''
Write-Host ('Backup store : ' + $(if ($script:backupDir) { $script:backupDir } else { '(nothing written)' }))
Write-Host ('Report       : ' + $runPath)
Write-Host ('Rollback     : ' + $report.rollback)
Write-Host 'Restart DSH (and ReMe) after applying CL-001 / CL-007.' -ForegroundColor Green
