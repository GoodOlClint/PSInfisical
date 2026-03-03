# Stop-IntegrationEnvironment.ps1
# Tears down the Docker Compose integration test environment.
# Safe to run even if containers are not running.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$composeDir = $PSScriptRoot

Write-Host 'Stopping integration test environment...' -ForegroundColor Yellow

try {
    # docker compose down -v removes containers, networks, and anonymous/named volumes
    $downArgs = @('compose', 'down', '-v', '--remove-orphans')
    $process = Start-Process -FilePath 'docker' -ArgumentList $downArgs -WorkingDirectory $composeDir -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) {
        Write-Warning "docker compose down exited with code $($process.ExitCode) — containers may not have been running."
    }
}
catch {
    Write-Warning "Failed to run docker compose down: $($_.Exception.Message)"
}

Write-Host 'Integration test environment stopped.' -ForegroundColor Green
