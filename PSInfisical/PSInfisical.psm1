# PSInfisical.psm1
# Root module loader for PSInfisical. Dot-sources all class, private, and public
# function files in the correct order. Manages module-scoped session state.
# Dependencies: All .ps1 files in Classes/, Private/, and Public/ directories.

#Requires -Version 5.1

Set-StrictMode -Version Latest

# Ensure TLS 1.2 is available. PowerShell 5.1 on older Windows may default to
# TLS 1.0/1.1, which Infisical's API (and most modern services) will reject.
if ([Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12') {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

# Module-scoped session variable — stores the current InfisicalSession.
# Accessed via $script:InfisicalSession from within module functions.
$script:InfisicalSession = $null

# Determine module root
$moduleRoot = $PSScriptRoot

# --- Dot-source Classes first (order matters for class definitions) ---
# InfisicalSession must be loaded before InfisicalSecret in case of future dependencies,
# but currently both are independent.
$classFiles = @(
    'InfisicalSession.ps1'
    'InfisicalSecret.ps1'
)
foreach ($file in $classFiles) {
    $filePath = Join-Path -Path $moduleRoot -ChildPath "Classes/$file"
    if (Test-Path -Path $filePath) {
        . $filePath
    }
    else {
        Write-Warning "PSInfisical: Class file not found: $filePath"
    }
}

# --- Dot-source Private functions ---
$privatePath = Join-Path -Path $moduleRoot -ChildPath 'Private'
if (Test-Path -Path $privatePath) {
    $privateFiles = Get-ChildItem -Path $privatePath -Filter '*.ps1' -File
    foreach ($file in $privateFiles) {
        . $file.FullName
    }
}

# --- Dot-source Public functions ---
$publicPath = Join-Path -Path $moduleRoot -ChildPath 'Public'
if (Test-Path -Path $publicPath) {
    $publicFiles = Get-ChildItem -Path $publicPath -Filter '*.ps1' -File
    foreach ($file in $publicFiles) {
        . $file.FullName
    }
}

# Note: FunctionsToExport in the manifest controls which functions are exported.
# Private functions are NOT listed there and therefore not accessible to module consumers.
