# PowerShell script to install DaVinci Resolve Lua scripts and Macros

# Define source and destination paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$fusionScriptsDir = "$env:APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts"
$macrosTargetDir = "$env:APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Macros"

# Define source directories
$compSourceDir = Join-Path $scriptDir "comp"
$utilitySourceDir = Join-Path $scriptDir "Utility"

# Create scripts destination directory if it doesn't exist
if (-not (Test-Path -Path $fusionScriptsDir)) {
    Write-Host "Creating scripts directory: $fusionScriptsDir"
    New-Item -ItemType Directory -Path $fusionScriptsDir -Force | Out-Null
}

# Copy Comp directory (and its subdirectories)
if (Test-Path -Path $compSourceDir) {
    Write-Host "Copying Comp directory..."
    $compTargetDir = "$fusionScriptsDir\Comp"
    
    # Create the Comp directory if it doesn't exist
    if (-not (Test-Path -Path $compTargetDir)) {
        Write-Host "Creating Comp directory: $compTargetDir"
        New-Item -ItemType Directory -Path $compTargetDir -Force | Out-Null
    }
    
    # Copy the entire Comp directory with all subfolders
    Copy-Item -Path "$compSourceDir\*" -Destination $compTargetDir -Recurse -Force
    Write-Host "Completed copying Comp directory."
} else {
    Write-Host "Warning: Comp directory not found at $compSourceDir" -ForegroundColor Yellow
}

# Copy Utility directory (and its subdirectories)
if (Test-Path -Path $utilitySourceDir) {
    Write-Host "Copying Utility directory..."
    $utilityTargetDir = "$fusionScriptsDir\Utility"
    
    # Create the Utility directory if it doesn't exist
    if (-not (Test-Path -Path $utilityTargetDir)) {
        Write-Host "Creating Utility directory: $utilityTargetDir"
        New-Item -ItemType Directory -Path $utilityTargetDir -Force | Out-Null
    }
    
    # Copy the entire Utility directory with all subfolders
    Copy-Item -Path "$utilitySourceDir\*" -Destination $utilityTargetDir -Recurse -Force
    Write-Host "Completed copying Utility directory."
} else {
    Write-Host "Warning: Utility directory not found at $utilitySourceDir" -ForegroundColor Yellow
}

# Create macros destination directory if it doesn't exist
if (-not (Test-Path -Path $macrosTargetDir)) {
    Write-Host "Creating macros directory: $macrosTargetDir"
    New-Item -ItemType Directory -Path $macrosTargetDir -Force | Out-Null
}

# Copy all setting files to Macros folder
$settings = Get-ChildItem -Path $scriptDir -Filter "*.setting" -File
foreach ($setting in $settings) {
    Write-Host "Installing $($setting.Name) to $macrosTargetDir"
    Copy-Item -Path $setting.FullName -Destination "$macrosTargetDir\$($setting.Name)" -Force
}

Write-Host "`nInstallation complete!`n"
Write-Host "Scripts installed to: $scriptsTargetDir"
Write-Host "Utility installed to: $fusionScriptsDir\Utility"
Write-Host "Macros installed to: $macrosTargetDir"