using module ..\..\PSInfisical.psd1

# Connect-Infisical.Tests.ps1
# Unit tests for the Connect-Infisical function.
# Called by: Pester test runner.
# Dependencies: PSInfisical module, TestHelpers.ps1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Connect-Infisical' {

    BeforeEach {
        # Ensure clean state
        Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    }

    Context 'UniversalAuth' {
        AfterEach {
            $script:InfisicalSession = $null
        }

        It 'Connects successfully and stores session' {
            Mock Invoke-RestMethod {
                return Get-SampleAuthResponse
            } -ModuleName PSInfisical

            $clientSecret = New-TestSecureString -PlainText 'test-client-secret'
            Connect-Infisical -ClientId 'test-client-id' -ClientSecret $clientSecret -ProjectId 'proj-123'

            Should -InvokeVerifiable
        }

        It 'Session.Connected is true after successful connect' {
            Mock Invoke-RestMethod {
                return Get-SampleAuthResponse
            } -ModuleName PSInfisical

            $clientSecret = New-TestSecureString -PlainText 'test-client-secret'
            $session = Connect-Infisical -ClientId 'test-client-id' -ClientSecret $clientSecret -ProjectId 'proj-123' -PassThru

            $session.Connected | Should -BeTrue
        }

        It '-PassThru returns the session object' {
            Mock Invoke-RestMethod {
                return Get-SampleAuthResponse
            } -ModuleName PSInfisical

            $clientSecret = New-TestSecureString -PlainText 'test-client-secret'
            $session = Connect-Infisical -ClientId 'test-client-id' -ClientSecret $clientSecret -ProjectId 'proj-123' -PassThru

            $session | Should -Not -BeNullOrEmpty
            $session.GetType().Name | Should -Be 'InfisicalSession'
            $session.AuthMethod | Should -Be 'UniversalAuth'
            $session.ProjectId | Should -Be 'proj-123'
        }

        It 'Throws descriptive error if API call fails' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('Connection refused')
            } -ModuleName PSInfisical

            $clientSecret = New-TestSecureString -PlainText 'test-client-secret'

            { Connect-Infisical -ClientId 'test-client-id' -ClientSecret $clientSecret -ProjectId 'proj-123' } |
                Should -Throw '*UniversalAuth login failed*'
        }
    }

    Context 'Token' {
        AfterEach {
            $script:InfisicalSession = $null
        }

        It 'Connects successfully with static Token' {
            $token = New-TestSecureString -PlainText 'static-api-token'
            $session = Connect-Infisical -Token $token -ProjectId 'proj-123' -PassThru

            $session.Connected | Should -BeTrue
            $session.AuthMethod | Should -Be 'Token'
        }
    }

    Context 'AccessToken' {
        AfterEach {
            $script:InfisicalSession = $null
        }

        It 'Connects successfully with pre-obtained AccessToken' {
            $accessToken = New-TestSecureString -PlainText 'pre-obtained-jwt'
            $session = Connect-Infisical -AccessToken $accessToken -ProjectId 'proj-123' -PassThru

            $session.Connected | Should -BeTrue
            $session.AuthMethod | Should -Be 'AccessToken'
        }
    }

    Context 'Session Management' {
        AfterEach {
            $script:InfisicalSession = $null
        }

        It 'Clears existing session before connecting (idempotent)' {
            $token = New-TestSecureString -PlainText 'first-token'
            Connect-Infisical -Token $token -ProjectId 'proj-111'

            $token2 = New-TestSecureString -PlainText 'second-token'
            $session = Connect-Infisical -Token $token2 -ProjectId 'proj-222' -PassThru

            $session.ProjectId | Should -Be 'proj-222'
        }

        It 'Normalizes ApiUrl trailing slash' {
            $token = New-TestSecureString -PlainText 'test-token'
            $session = Connect-Infisical -Token $token -ProjectId 'proj-123' -ApiUrl 'https://infisical.mycompany.com/api/' -PassThru

            $session.ApiUrl | Should -Be 'https://infisical.mycompany.com/api'
        }

        It 'Uses default environment of prod' {
            $token = New-TestSecureString -PlainText 'test-token'
            $session = Connect-Infisical -Token $token -ProjectId 'proj-123' -PassThru

            $session.DefaultEnvironment | Should -Be 'prod'
        }

        It 'Accepts custom environment' {
            $token = New-TestSecureString -PlainText 'test-token'
            $session = Connect-Infisical -Token $token -ProjectId 'proj-123' -Environment 'staging' -PassThru

            $session.DefaultEnvironment | Should -Be 'staging'
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
