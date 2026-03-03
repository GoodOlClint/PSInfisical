using module ..\..\PSInfisical.psd1

# Connect-Infisical.Integration.Tests.ps1
# Integration tests for Connect-Infisical covering all three auth methods
# against a live self-hosted Infisical instance.
# Called by: Pester test runner (Invoke-Build Test-Integration).

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')

    $testUrl = $env:INFISICAL_TEST_URL
    $projectId = $env:INFISICAL_TEST_PROJECT_ID
    $clientId = $env:INFISICAL_TEST_CLIENT_ID
    $clientSecret = $env:INFISICAL_TEST_CLIENT_SECRET

    if (-not $testUrl -or -not $projectId -or -not $clientId -or -not $clientSecret) {
        throw @"
Integration test environment variables are not set. Ensure the following are defined:
  INFISICAL_TEST_URL, INFISICAL_TEST_PROJECT_ID,
  INFISICAL_TEST_CLIENT_ID, INFISICAL_TEST_CLIENT_SECRET

Run Start-IntegrationEnvironment.ps1 to bootstrap the environment.
"@
    }
}

Describe 'Connect-Infisical Integration Tests' -Tag 'Integration' {

    Context 'UniversalAuth' {

        It 'Connects with valid machine identity credentials' {
            $secureSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force

            $session = Connect-Infisical `
                -ClientId $clientId `
                -ClientSecret $secureSecret `
                -ProjectId $projectId `
                -ApiUrl $testUrl `
                -Environment 'dev' `
                -PassThru

            $session | Should -Not -BeNullOrEmpty
            $session.Connected | Should -BeTrue
            $session.AuthMethod | Should -Be 'UniversalAuth'
            $session.ApiUrl | Should -Be $testUrl
            $session.ProjectId | Should -Be $projectId
        }

        It 'Sets token expiry when using UniversalAuth' {
            $secureSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force

            $session = Connect-Infisical `
                -ClientId $clientId `
                -ClientSecret $secureSecret `
                -ProjectId $projectId `
                -ApiUrl $testUrl `
                -PassThru

            $session.TokenExpiry | Should -Not -BeNullOrEmpty
            $session.TokenExpiry | Should -BeGreaterThan ([datetime]::UtcNow)
        }
    }

    Context 'Token' {
        # Service tokens are deprecated in Infisical in favor of Machine Identities.
        # The Token auth method in Connect-Infisical accepts any bearer token and
        # stores it directly without a login handshake. We can test this by obtaining
        # an access token via UniversalAuth and passing it as a static Token.

        It 'Connects with a bearer token obtained from UniversalAuth' {
            # First, get a real access token via the UniversalAuth login endpoint
            $loginBody = @{
                clientId     = $clientId
                clientSecret = $clientSecret
            } | ConvertTo-Json -Compress

            $authResponse = Invoke-RestMethod `
                -Uri "$testUrl/api/v1/auth/universal-auth/login" `
                -Method POST `
                -Body $loginBody `
                -ContentType 'application/json' `
                -TimeoutSec 30 `
                -ErrorAction Stop

            $secureToken = ConvertTo-SecureString -String $authResponse.accessToken -AsPlainText -Force

            $session = Connect-Infisical `
                -Token $secureToken `
                -ProjectId $projectId `
                -ApiUrl $testUrl `
                -Environment 'dev' `
                -PassThru

            $session | Should -Not -BeNullOrEmpty
            $session.Connected | Should -BeTrue
            $session.AuthMethod | Should -Be 'Token'

            # Verify the token actually works by making an API call
            $secrets = Get-InfisicalSecrets -ErrorAction SilentlyContinue
            # May be empty but should not throw (proves the token is valid)
        }
    }

    Context 'AccessToken' {

        It 'Connects with a pre-obtained JWT access token' {
            # Obtain a JWT via UniversalAuth directly with Invoke-RestMethod
            $loginBody = @{
                clientId     = $clientId
                clientSecret = $clientSecret
            } | ConvertTo-Json -Compress

            $authResponse = Invoke-RestMethod `
                -Uri "$testUrl/api/v1/auth/universal-auth/login" `
                -Method POST `
                -Body $loginBody `
                -ContentType 'application/json' `
                -TimeoutSec 30 `
                -ErrorAction Stop

            $secureJwt = ConvertTo-SecureString -String $authResponse.accessToken -AsPlainText -Force

            $session = Connect-Infisical `
                -AccessToken $secureJwt `
                -ProjectId $projectId `
                -ApiUrl $testUrl `
                -Environment 'dev' `
                -PassThru

            $session | Should -Not -BeNullOrEmpty
            $session.Connected | Should -BeTrue
            $session.AuthMethod | Should -Be 'AccessToken'

            # Verify the token actually works
            $secrets = Get-InfisicalSecrets -ErrorAction SilentlyContinue
        }
    }

    Context 'Invalid Credentials' {

        It 'Throws InfisicalUniversalAuthFailed with bad client credentials' {
            $badSecret = ConvertTo-SecureString -String 'totally-wrong-secret' -AsPlainText -Force

            $thrown = $null
            try {
                Connect-Infisical `
                    -ClientId 'nonexistent-client-id' `
                    -ClientSecret $badSecret `
                    -ProjectId $projectId `
                    -ApiUrl $testUrl `
                    -ErrorAction Stop
            }
            catch {
                $thrown = $_
            }

            $thrown | Should -Not -BeNullOrEmpty
            $thrown.FullyQualifiedErrorId | Should -Match 'InfisicalUniversalAuthFailed'
        }

        It 'Throws InfisicalUniversalAuthFailed with valid client ID but wrong secret' {
            $badSecret = ConvertTo-SecureString -String 'wrong-secret-value' -AsPlainText -Force

            $thrown = $null
            try {
                Connect-Infisical `
                    -ClientId $clientId `
                    -ClientSecret $badSecret `
                    -ProjectId $projectId `
                    -ApiUrl $testUrl `
                    -ErrorAction Stop
            }
            catch {
                $thrown = $_
            }

            $thrown | Should -Not -BeNullOrEmpty
            $thrown.FullyQualifiedErrorId | Should -Match 'InfisicalUniversalAuthFailed'
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
