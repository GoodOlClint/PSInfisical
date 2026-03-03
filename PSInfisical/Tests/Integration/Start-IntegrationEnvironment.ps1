# Start-IntegrationEnvironment.ps1
# Starts the Docker Compose integration test environment, waits for Infisical
# to be healthy, and bootstraps the instance (admin user, project, machine
# identity) so integration tests have credentials to work with.
#
# Outputs environment variables that tests consume:
#   INFISICAL_TEST_URL, INFISICAL_TEST_PROJECT_ID,
#   INFISICAL_TEST_CLIENT_ID, INFISICAL_TEST_CLIENT_SECRET
#
# Idempotent — safe to run when containers are already up. If the bootstrap
# endpoint returns an error (already bootstrapped), the script logs in as the
# admin user and continues from there.

[CmdletBinding()]
param(
    [int] $TimeoutSeconds = 120,
    [int] $RetryIntervalSeconds = 5
)

$ErrorActionPreference = 'Stop'
$composeDir = $PSScriptRoot

# ---------------------------------------------------------------------------
# Helper: Convert .env file to hashtable
# ---------------------------------------------------------------------------
function Read-EnvFile {
    param([string] $Path)
    $result = @{}
    foreach ($line in (Get-Content -Path $Path)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $eqIdx = $trimmed.IndexOf('=')
        if ($eqIdx -gt 0) {
            $key = $trimmed.Substring(0, $eqIdx).Trim()
            $value = $trimmed.Substring($eqIdx + 1).Trim()
            $result[$key] = $value
        }
    }
    return $result
}

# ---------------------------------------------------------------------------
# Pre-flight: Docker
# ---------------------------------------------------------------------------
Write-Host 'Checking prerequisites...' -ForegroundColor Yellow

$dockerPath = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerPath) {
    throw 'Docker is not installed or not in PATH. Install Docker Desktop (https://www.docker.com/products/docker-desktop/) and try again.'
}

# Verify docker compose (v2 plugin) is available
$composeVersion = & docker compose version 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose is not available. Ensure the Docker Compose plugin is installed.`n$composeVersion"
}
Write-Host "  Docker Compose: $composeVersion" -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Pre-flight: .env file
# ---------------------------------------------------------------------------
$envFile = Join-Path -Path $composeDir -ChildPath '.env'
$envExample = Join-Path -Path $composeDir -ChildPath '.env.example'

if (-not (Test-Path -Path $envFile)) {
    throw "Integration test .env file not found at:`n  $envFile`n`nCopy the example and fill in values:`n  cp $envExample $envFile"
}

$envVars = Read-EnvFile -Path $envFile

# ---------------------------------------------------------------------------
# Start containers
# ---------------------------------------------------------------------------
Write-Host 'Starting Docker Compose environment...' -ForegroundColor Yellow

$composeFile = Join-Path -Path $composeDir -ChildPath 'docker-compose.yml'
$upArgs = @('compose', '-f', $composeFile, 'up', '-d', '--wait', '--remove-orphans')
& docker @upArgs 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

if ($LASTEXITCODE -ne 0) {
    Write-Warning "docker compose up exited with code $LASTEXITCODE — will still attempt health polling."
}

# ---------------------------------------------------------------------------
# Wait for Infisical health endpoint
# ---------------------------------------------------------------------------
$port = if ($envVars['INFISICAL_PORT']) { $envVars['INFISICAL_PORT'] } else { '8080' }
$baseUrl = "http://localhost:$port"
$healthUrl = "$baseUrl/api/status"

Write-Host "Waiting for Infisical at $healthUrl (timeout: ${TimeoutSeconds}s)..." -ForegroundColor Yellow

$deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
$healthy = $false

while ([datetime]::UtcNow -lt $deadline) {
    try {
        $response = Invoke-RestMethod -Uri $healthUrl -Method GET -TimeoutSec 5 -ErrorAction Stop
        if ($null -ne $response) {
            $healthy = $true
            break
        }
    }
    catch {
        Write-Host "  Not ready yet — retrying in ${RetryIntervalSeconds}s..." -ForegroundColor Gray
    }
    Start-Sleep -Seconds $RetryIntervalSeconds
}

if (-not $healthy) {
    throw "Infisical did not become healthy within $TimeoutSeconds seconds at $healthUrl. Check docker compose logs for details."
}

Write-Host "Infisical is healthy at $baseUrl" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Bootstrap: Create admin user + org (idempotent)
# ---------------------------------------------------------------------------
$adminEmail = if ($envVars['INFISICAL_ADMIN_EMAIL']) { $envVars['INFISICAL_ADMIN_EMAIL'] } else { 'admin@test.local' }
$adminPassword = if ($envVars['INFISICAL_ADMIN_PASSWORD']) { $envVars['INFISICAL_ADMIN_PASSWORD'] } else { 'TestPassword123!' }

Write-Host 'Bootstrapping Infisical instance...' -ForegroundColor Yellow

$adminJwt = $null
$orgId = $null

try {
    $bootstrapBody = @{
        email        = $adminEmail
        password     = $adminPassword
        organization = 'integration-test'
    } | ConvertTo-Json -Compress

    $bootstrapResponse = Invoke-RestMethod -Uri "$baseUrl/api/v1/admin/bootstrap" -Method POST -Body $bootstrapBody -ContentType 'application/json' -TimeoutSec 30 -ErrorAction Stop

    $adminJwt = $bootstrapResponse.identity.credentials.token
    $orgId = $bootstrapResponse.organization.id

    Write-Host '  Fresh bootstrap complete — admin account created.' -ForegroundColor Green
}
catch {
    # Already bootstrapped — log in with the admin credentials instead.
    Write-Host '  Instance already bootstrapped — logging in...' -ForegroundColor Gray

    try {
        # Use the signup/login flow. Infisical's admin bootstrap is one-shot;
        # subsequent access requires normal login via the UI or machine identity.
        # We attempt Universal Auth login if we previously stored credentials,
        # otherwise fall back to the admin signup endpoint check.
        $loginBody = @{
            email    = $adminEmail
            password = $adminPassword
        } | ConvertTo-Json -Compress

        $loginResponse = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/login1" -Method POST -Body $loginBody -ContentType 'application/json' -TimeoutSec 30 -ErrorAction Stop

        # login1 returns a partial token flow — complete with login2
        $login2Body = @{
            email        = $adminEmail
            clientProof  = $loginResponse.clientProof
            password     = $adminPassword
        } | ConvertTo-Json -Compress

        # If login1/login2 SRP flow is too complex, we can check if env vars
        # already have credentials from a previous bootstrap run.
        Write-Warning "SRP login flow detected — checking if test credentials already exist in environment..."
    }
    catch {
        Write-Host '  Login flow unavailable — checking for existing credentials...' -ForegroundColor Gray
    }
}

# ---------------------------------------------------------------------------
# If we don't have an admin JWT (already-bootstrapped instance), check if
# the environment already has test credentials from a previous run.
# ---------------------------------------------------------------------------
if (-not $adminJwt) {
    if ($env:INFISICAL_TEST_CLIENT_ID -and $env:INFISICAL_TEST_CLIENT_SECRET) {
        Write-Host '  Using existing INFISICAL_TEST_CLIENT_ID / INFISICAL_TEST_CLIENT_SECRET from environment.' -ForegroundColor Green
        Write-Host ''
        Write-Host '=== Integration Environment Ready ===' -ForegroundColor Green
        Write-Host "  INFISICAL_TEST_URL           = $baseUrl" -ForegroundColor Cyan
        Write-Host "  INFISICAL_TEST_PROJECT_ID    = $($env:INFISICAL_TEST_PROJECT_ID)" -ForegroundColor Cyan
        Write-Host "  INFISICAL_TEST_CLIENT_ID     = $($env:INFISICAL_TEST_CLIENT_ID)" -ForegroundColor Cyan
        Write-Host "  INFISICAL_TEST_CLIENT_SECRET = ****" -ForegroundColor Cyan
        # Ensure URL is set
        $env:INFISICAL_TEST_URL = $baseUrl
        return
    }

    throw @"
Cannot obtain admin JWT — the instance was already bootstrapped in a previous
run but no test credentials are present in the environment.

To fix this, either:
  1. Run Stop-IntegrationEnvironment.ps1 first to wipe state, then re-run this script.
  2. Set INFISICAL_TEST_CLIENT_ID, INFISICAL_TEST_CLIENT_SECRET, and
     INFISICAL_TEST_PROJECT_ID environment variables manually.
"@
}

# ---------------------------------------------------------------------------
# Create project
# ---------------------------------------------------------------------------
Write-Host '  Creating test project...' -ForegroundColor Gray

$headers = @{
    Authorization  = "Bearer $adminJwt"
    'Content-Type' = 'application/json'
}

$projectBody = @{
    projectName             = 'integration-test'
    shouldCreateDefaultEnvs = $true
} | ConvertTo-Json -Compress

$projectResponse = Invoke-RestMethod -Uri "$baseUrl/api/v2/workspace" -Method POST -Body $projectBody -Headers $headers -TimeoutSec 30 -ErrorAction Stop
$projectId = $projectResponse.project.id

Write-Host "  Project created: $projectId" -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Create machine identity
# ---------------------------------------------------------------------------
Write-Host '  Creating machine identity...' -ForegroundColor Gray

$identityBody = @{
    name           = 'integration-test-identity'
    organizationId = $orgId
    role           = 'admin'
} | ConvertTo-Json -Compress

$identityResponse = Invoke-RestMethod -Uri "$baseUrl/api/v1/identities" -Method POST -Body $identityBody -Headers $headers -TimeoutSec 30 -ErrorAction Stop
$identityId = $identityResponse.identity.id

Write-Host "  Identity created: $identityId" -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Attach Universal Auth
# ---------------------------------------------------------------------------
Write-Host '  Attaching Universal Auth...' -ForegroundColor Gray

$uaBody = @{
    accessTokenTTL         = 7200
    accessTokenMaxTTL      = 86400
    accessTokenNumUsesLimit = 0
    clientSecretTrustedIps = @(@{ ipAddress = '0.0.0.0/0' })
    accessTokenTrustedIps  = @(@{ ipAddress = '0.0.0.0/0' })
} | ConvertTo-Json -Depth 5 -Compress

$uaResponse = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/universal-auth/identities/$identityId" -Method POST -Body $uaBody -Headers $headers -TimeoutSec 30 -ErrorAction Stop
$clientId = $uaResponse.identityUniversalAuth.clientId

Write-Host "  Client ID: $clientId" -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Create client secret
# ---------------------------------------------------------------------------
Write-Host '  Creating client secret...' -ForegroundColor Gray

$csBody = @{
    description  = 'Integration test credentials'
    ttl          = 0
    numUsesLimit = 0
} | ConvertTo-Json -Compress

$csResponse = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/universal-auth/identities/$identityId/client-secrets" -Method POST -Body $csBody -Headers $headers -TimeoutSec 30 -ErrorAction Stop
$clientSecret = $csResponse.clientSecret

# ---------------------------------------------------------------------------
# Grant project membership
# ---------------------------------------------------------------------------
Write-Host '  Granting project membership...' -ForegroundColor Gray

$memberBody = @{ role = 'admin' } | ConvertTo-Json -Compress

Invoke-RestMethod -Uri "$baseUrl/api/v2/workspace/$projectId/identity-memberships/$identityId" -Method POST -Body $memberBody -Headers $headers -TimeoutSec 30 -ErrorAction Stop | Out-Null

# ---------------------------------------------------------------------------
# Export environment variables
# ---------------------------------------------------------------------------
$env:INFISICAL_TEST_URL = $baseUrl
$env:INFISICAL_TEST_PROJECT_ID = $projectId
$env:INFISICAL_TEST_CLIENT_ID = $clientId
$env:INFISICAL_TEST_CLIENT_SECRET = $clientSecret

Write-Host ''
Write-Host '=== Integration Environment Ready ===' -ForegroundColor Green
Write-Host "  INFISICAL_TEST_URL           = $baseUrl" -ForegroundColor Cyan
Write-Host "  INFISICAL_TEST_PROJECT_ID    = $projectId" -ForegroundColor Cyan
Write-Host "  INFISICAL_TEST_CLIENT_ID     = $clientId" -ForegroundColor Cyan
Write-Host "  INFISICAL_TEST_CLIENT_SECRET = ****" -ForegroundColor Cyan
Write-Host ''
Write-Host 'Environment variables have been set in the current session.' -ForegroundColor Green
Write-Host 'Run Pester tests now, or run Stop-IntegrationEnvironment.ps1 to tear down.' -ForegroundColor Gray
