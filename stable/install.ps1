param([string]$DshCmd = '', [switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$exitCode = 1
try {
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'Windows x64 is required.' }
    $candidates = @()
    if ($DshCmd) { $candidates += $DshCmd }
    $found = Get-Command dsh.cmd -ErrorAction SilentlyContinue
    if ($found) { $candidates += $found.Source }
    $uninstallKeys = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
    $installs = Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*DeepSeek Harness*' -and $_.InstallLocation }
    foreach ($item in $installs) { $candidates += Join-Path $item.InstallLocation 'resources\runtime\cli\bin\dsh.cmd' }
    foreach ($base in @("$env:LOCALAPPDATA\Programs\DeepSeek Harness", "$env:ProgramFiles\DeepSeek Harness", "$env:LOCALAPPDATA\DeepSeek Harness")) {
        $candidates += Join-Path $base 'resources\runtime\cli\bin\dsh.cmd'
    }
    $desktopRoot = $null
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        $cmdPath = (Resolve-Path -LiteralPath $candidate).Path
        $base = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $cmdPath) '..\..\..\..'))
        if ((Test-Path -LiteralPath (Join-Path $base 'DeepSeek Harness.exe')) -and (Test-Path -LiteralPath (Join-Path $base 'resources\app.asar'))) { $desktopRoot = $base; break }
    }
    if (-not $desktopRoot) {
        Write-Host 'Select the installed DeepSeek Harness.exe in the next dialog.'
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = 'Select DeepSeek Harness.exe'
        $dialog.Filter = 'DeepSeek Harness.exe|DeepSeek Harness.exe'
        if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { throw 'Desktop was not selected.' }
        $desktopRoot = Split-Path -Parent $dialog.FileName
        if (-not (Test-Path -LiteralPath (Join-Path $desktopRoot 'resources\app.asar'))) { throw 'This is not the supported Desktop installation.' }
    }
    if (-not $CheckOnly) {
        $running = @(Get-Process -Name 'DeepSeek Harness' -ErrorAction SilentlyContinue)
        if ($running.Count -gt 0) { throw 'Fully quit DeepSeek Harness, including its tray icon, then run INSTALL.cmd again.' }
    }
    $exe = Join-Path $desktopRoot 'DeepSeek Harness.exe'
    $helper = Join-Path $PSScriptRoot 'install-helper.cjs'
    $previousElectron = $env:ELECTRON_RUN_AS_NODE
    try {
        $env:ELECTRON_RUN_AS_NODE = '1'
        $invokeArgs = @('--expose-internals', $helper, '--desktop-dir', $desktopRoot)
        if ($CheckOnly) { $invokeArgs += '--check-only' }
        $proc = Start-Process -FilePath $exe -ArgumentList ($invokeArgs | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -Wait -PassThru -NoNewWindow
        $exitCode = $proc.ExitCode
    } finally {
        $env:ELECTRON_RUN_AS_NODE = $previousElectron
    }
} catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    $exitCode = 1
}
exit $exitCode
