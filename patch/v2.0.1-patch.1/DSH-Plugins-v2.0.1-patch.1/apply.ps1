# DSH-Plugins v2.0.1-patch.1 installer (Alignment Protocol v1.0)
# ASCII-only on purpose: Windows PowerShell 5.1 mis-parses non-BOM UTF-8 scripts.
param(
  [switch]$CheckOnly,
  [switch]$Uninstall,
  [string]$Target = ''
)
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$markerStart = '<!-- ALIGNMENT_PROTOCOL v1.0 START'
$markerEnd = 'ALIGNMENT_PROTOCOL v1.0 END -->'
$id = 'align-protocol-20261029'
$store = Join-Path $env:LOCALAPPDATA ('DSHPluginMigration\' + $id)

function Write-Utf8([string]$path, [string]$text) {
  [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
}
function Read-Utf8([string]$path) {
  [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}
function Get-Sha([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return '' }
  (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()
}
function Fail([string]$msg) { Write-Host ('FAILED: ' + $msg) -ForegroundColor Red; exit 1 }

# ---- 1. package self-check (SHA-256 of every listed file) ----
$sumsPath = Join-Path $here 'checksums.json'
if (-not (Test-Path -LiteralPath $sumsPath)) { Fail 'checksums.json missing' }
$sums = Read-Utf8 $sumsPath | ConvertFrom-Json
$verified = 0
foreach ($item in $sums.files) {
  $f = Join-Path $here $item.path
  if (-not (Test-Path -LiteralPath $f)) { Fail ('missing file: ' + $item.path) }
  $h = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower()
  if ($h -ne $item.sha256.ToLower()) { Fail ('checksum mismatch: ' + $item.path) }
  $verified++
}
Write-Host ('[1/5] SHA-256 verified: ' + $verified + ' file(s).') -ForegroundColor Green

# ---- 2. read protocol block ----
$payloadPath = Join-Path $here 'ALIGNMENT-PROTOCOL.md'
$payload = Read-Utf8 $payloadPath
$lines = $payload -split "`r?`n"
$startIdx = -1; $endIdx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($startIdx -lt 0 -and $lines[$i].StartsWith($markerStart)) { $startIdx = $i }
  elseif ($lines[$i].IndexOf($markerEnd) -ge 0) { $endIdx = $i; break }
}
if ($startIdx -lt 0 -or $endIdx -le $startIdx) { Fail 'protocol markers not found in ALIGNMENT-PROTOCOL.md' }
$block = ($lines[$startIdx..$endIdx] -join "`n").TrimEnd()
Write-Host ('[2/5] Protocol block: ' + ($endIdx - $startIdx + 1) + ' lines, ' + $block.Length + ' chars.') -ForegroundColor Green

# ---- 3. resolve target ----
$home2 = $env:USERPROFILE
if (-not $home2) { $home2 = $HOME }
if (-not $Target) { $Target = Join-Path $home2 '.dsh\AGENTS.md' }
$Target = [System.IO.Path]::GetFullPath($Target)
Write-Host ('[3/5] Target: ' + $Target)
$existed = Test-Path -LiteralPath $Target
$before = ''
if ($existed) { $before = Read-Utf8 $Target }
$hasBlock = $before.Contains($markerStart)

if ($CheckOnly) {
  $wouldAction = if (-not $existed) { 'CREATE (target missing)' } elseif ($hasBlock) { 'REPLACE existing block' } else { 'APPEND new block' }
  Write-Host ('[4/5] Check-only: ' + $wouldAction)
  if ($existed) {
    Write-Host ('        current AGENTS.md: ' + $before.Length + ' chars, block present: ' + $hasBlock)
  }
  Write-Host '[5/5] No file was modified (dry run).' -ForegroundColor Green
  exit 0
}

if ($Uninstall) {
  if (-not $hasBlock) { Write-Host '[4/5] No protocol block found; nothing to remove.' -ForegroundColor Yellow; exit 0 }
  $rx = [regex]::new('(?s)\r?\n?<!-- ALIGNMENT_PROTOCOL v1\.0 START.*?ALIGNMENT_PROTOCOL v1\.0 END -->[ \t]*\r?\n?')
  $stripped = $rx.Replace($before, "`n")
  $stripped = $stripped -replace "(`n){3,}", "`n`n"
  New-Item -ItemType Directory -Force -Path $store | Out-Null
  $bk = Join-Path $store ('backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-uninstall')
  New-Item -ItemType Directory -Force -Path $bk | Out-Null
  Copy-Item -LiteralPath $Target -Destination (Join-Path $bk 'AGENTS.md') -Force
  Write-Utf8 $Target $stripped.TrimEnd() 
  $rep = [ordered]@{
    completedAt = (Get-Date).ToString('o'); patch = $id; action = 'uninstall'; target = $Target; backup = $bk
    charsBefore = $before.Length; charsAfter = $stripped.TrimEnd().Length; blockPresent = $false
  }
  Write-Utf8 (Join-Path $store 'patch-result.json') (($rep | ConvertTo-Json -Depth 5) + "`n")
  Write-Host ('[4/5] Block removed. AGENTS.md: ' + $before.Length + ' -> ' + $stripped.TrimEnd().Length + ' chars.') -ForegroundColor Green
  Write-Host ('[5/5] Backup: ' + $bk) -ForegroundColor Green
  exit 0
}

# ---- 4. backup + apply ----
$backup = $null
if ($existed) {
  New-Item -ItemType Directory -Force -Path $store | Out-Null
  $backup = Join-Path $store ('backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
  New-Item -ItemType Directory -Force -Path $backup | Out-Null
  Copy-Item -LiteralPath $Target -Destination (Join-Path $backup 'AGENTS.md') -Force
}
$dir = Split-Path -Parent $Target
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

if ($hasBlock) {
  $rx = [regex]::new('(?s)<!-- ALIGNMENT_PROTOCOL v1\.0 START.*?ALIGNMENT_PROTOCOL v1\.0 END -->')
  $after = $rx.Replace($before, $block, 1)
  $mode = 'replace'
} elseif ($existed -and $before.Trim().Length -gt 0) {
  $after = $before.TrimEnd() + "`n`n" + $block + "`n"
  $mode = 'append'
} else {
  $after = $block + "`n"
  $mode = 'create'
}
Write-Utf8 $Target $after
Write-Host ('[4/5] Applied (' + $mode + '): ' + $before.Length + ' -> ' + $after.Length + ' chars.') -ForegroundColor Green

# ---- 5. verify written block is byte-identical to payload block ----
$check = Read-Utf8 $Target
if (-not $check.Contains($block)) { Fail 'post-write verification failed (block text not found in target)' }
if (($check.Split([string[]]@($markerStart), [System.StringSplitOptions]::None)).Count - 1 -ne 1) { Fail 'post-write verification failed (marker count != 1)' }

$report = [ordered]@{
  completedAt   = (Get-Date).ToString('o')
  patch         = $id
  protocol      = 'ALIGNMENT_PROTOCOL v1.0'
  action        = if ($Uninstall) { 'uninstall' } else { $mode }
  target        = $Target
  backup        = $backup
  chars         = @{ before = $before.Length; after = $after.Length }
  blockSha256   = (Get-FileHash -LiteralPath $payloadPath -Algorithm SHA256).Hash.ToLower()
  targetSha256  = (Get-Sha $Target)
  rollback      = if ($backup) { 'Copy ' + (Join-Path $backup 'AGENTS.md') + ' back to ' + $Target } else { 'Delete ' + $Target }
  note          = 'Takes effect in the next DSH session (global instructions are read per session).'
}
New-Item -ItemType Directory -Force -Path $store | Out-Null
Write-Utf8 (Join-Path $store 'patch-result.json') (($report | ConvertTo-Json -Depth 6) + "`n")

Write-Host '[5/5] Done.' -ForegroundColor Green
Write-Host ('      Backup   : ' + $backup)
Write-Host ('      Report   : ' + (Join-Path $store 'patch-result.json'))
Write-Host ('      Rollback : ' + $report.rollback)
Write-Host '      Takes effect in the NEXT DSH session.'
