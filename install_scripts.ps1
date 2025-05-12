# PowerShell script to install DaVinci Resolve Lua scripts and Macros
# Installs all *.lua files to %APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp
# Installs MLS-Scoreboard.setting to %APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Macros

# Define source and destination paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptsTargetDir = "$env:APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp"
$macrosTargetDir = "$env:APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Macros"

# Create scripts destination directory if it doesn't exist
if (-not (Test-Path -Path $scriptsTargetDir)) {
    Write-Host "Creating scripts directory: $scriptsTargetDir"
    New-Item -ItemType Directory -Path $scriptsTargetDir -Force | Out-Null
}

# Create macros destination directory if it doesn't exist
if (-not (Test-Path -Path $macrosTargetDir)) {
    Write-Host "Creating macros directory: $macrosTargetDir"
    New-Item -ItemType Directory -Path $macrosTargetDir -Force | Out-Null
}

# Create utils subdirectory if it doesn't exist
if (-not (Test-Path -Path "$scriptsTargetDir\utils")) {
    Write-Host "Creating utils subdirectory: $scriptsTargetDir\utils"
    New-Item -ItemType Directory -Path "$scriptsTargetDir\utils" -Force | Out-Null
}

# Copy main Lua scripts
$mainScripts = Get-ChildItem -Path $scriptDir -Filter "*.lua" -File
foreach ($script in $mainScripts) {
    Write-Host "Installing $($script.Name) to $scriptsTargetDir"
    Copy-Item -Path $script.FullName -Destination "$scriptsTargetDir\$($script.Name)" -Force
}

# Copy utils scripts
$utilsDir = Join-Path $scriptDir "utils"
if (Test-Path -Path $utilsDir) {
    $utilsScripts = Get-ChildItem -Path $utilsDir -Filter "*.lua" -File
    foreach ($script in $utilsScripts) {
        Write-Host "Installing utils/$($script.Name) to $scriptsTargetDir\utils"
        Copy-Item -Path $script.FullName -Destination "$scriptsTargetDir\utils\$($script.Name)" -Force
    }
}

# Copy all setting files to Macros folder
$settings = Get-ChildItem -Path $scriptDir -Filter "*.setting" -File
foreach ($setting in $settings) {
    Write-Host "Installing $($setting.Name) to $macrosTargetDir"
    Copy-Item -Path $setting.FullName -Destination "$macrosTargetDir\$($setting.Name)" -Force
}

Write-Host "`nInstallation complete!`n"
Write-Host "Scripts installed to: $scriptsTargetDir"
Write-Host "Macros installed to: $macrosTargetDir"
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")