# v1.0.0-patch.1 launcher
param(
  [string]$SkillDir = '',
  [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) {
  $candidates = @('C:\Program Files\nodejs\node.exe', "$env:LOCALAPPDATA\Programs\nodejs\node.exe")
  foreach ($c in $candidates) { if (Test-Path $c) { $node = $c; break } }
}
if (-not $node) { Write-Host 'Node.js not found. Install Node 22 or 24 first.' -ForegroundColor Red; exit 1 }

$helper = Join-Path $here 'install-helper.cjs'
$extra = @()
if ($SkillDir) { $extra += @('--skill-dir', $SkillDir) }
if ($CheckOnly) { $extra += '--check-only' }
& $node $helper @extra
exit $LASTEXITCODE