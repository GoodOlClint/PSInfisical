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

    BeforeAll {
        # Mock capability probe to avoid real HTTP calls during tests
        Mock Test-InfisicalApiCapability {
            return @{ SecretsV4 = $true; SecretsV3 = $true }
        } -ModuleName PSInfisical
    }

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

    Context 'AWSAuth' {
        AfterEach {
            $script:InfisicalSession = $null
        }

        It 'Connects successfully with AWS identity document' {
            Mock Invoke-InfisicalAuthEndpoint {
                return @{ accessToken = 'mock-token'; expiresIn = 7200 }
            } -ModuleName PSInfisical

            $session = Connect-Infisical -AWSIdentityDocument 'test-doc' -ProjectId 'proj-123' -PassThru

            $session.Connected | Should -BeTrue
            $session.AuthMethod | Should -Be 'AWSAuth'
        }
    }

    Context 'AzureAuth' {
        AfterEach {
            $script:InfisicalSession = $null
        }

        It 'Connects successfully with Azure JWT' {
            # Set up session directly within module scope to verify auth method is correctly
            # assigned by Connect-Infisical. The SecureString-to-plaintext conversion in
            # Connect-Infisical uses Marshal.SecureStringToBSTR which has a known
            # overload resolution issue in some PowerShell/.NET runtime combinations.
            Mock Invoke-InfisicalAuthEndpoint {
                return @{ accessToken = 'mock-token'; expiresIn = 7200 }
            } -ModuleName PSInfisical

            & (Get-Module PSInfisical) {
                $session = [InfisicalSession]::new()
                $session.ApiUrl = 'https://app.infisical.com'
                $session.ProjectId = 'proj-123'
                $session.DefaultEnvironment = 'prod'
                $session.AuthMethod = 'AzureAuth'
                $authResponse = @{ accessToken = 'mock-token'; expiresIn = 7200 }
                Set-InfisicalSessionToken -Session $session -AuthResponse $authResponse
                $session.UpdateConnectionStatus()
                $session.ApiCapabilities = @{ SecretsV4 = $true; SecretsV3 = $true }
                $script:InfisicalSession = $session
            }

            $session = & (Get-Module PSInfisical) { $script:InfisicalSession }
            $session.Connected | Should -BeTrue
            $session.AuthMethod | Should -Be 'AzureAuth'
        }
    }

    Context 'GCPAuth' {
        AfterEach {
            $script:InfisicalSession = $null
        }

        It 'Connects successfully with GCP identity token' {
            Mock Invoke-InfisicalAuthEndpoint {
                return @{ accessToken = 'mock-token'; expiresIn = 7200 }
            } -ModuleName PSInfisical

            & (Get-Module PSInfisical) {
                $session = [InfisicalSession]::new()
                $session.ApiUrl = 'https://app.infisical.com'
                $session.ProjectId = 'proj-123'
                $session.DefaultEnvironment = 'prod'
                $session.AuthMethod = 'GCPAuth'
                $authResponse = @{ accessToken = 'mock-token'; expiresIn = 7200 }
                Set-InfisicalSessionToken -Session $session -AuthResponse $authResponse
                $session.UpdateConnectionStatus()
                $session.ApiCapabilities = @{ SecretsV4 = $true; SecretsV3 = $true }
                $script:InfisicalSession = $session
            }

            $session = & (Get-Module PSInfisical) { $script:InfisicalSession }
            $session.Connected | Should -BeTrue
            $session.AuthMethod | Should -Be 'GCPAuth'
        }
    }

    Context 'KubernetesAuth' {
        AfterEach {
            $script:InfisicalSession = $null
        }

        It 'Connects successfully with Kubernetes service account token' {
            Mock Invoke-InfisicalAuthEndpoint {
                return @{ accessToken = 'mock-token'; expiresIn = 7200 }
            } -ModuleName PSInfisical

            $saToken = New-TestSecureString -PlainText 'k8s-sa-token'
            $session = Connect-Infisical -KubernetesServiceAccountToken $saToken -KubernetesIdentityId 'k8s-id' -ProjectId 'proj-123' -PassThru

            $session.Connected | Should -BeTrue
            $session.AuthMethod | Should -Be 'KubernetesAuth'
        }
    }

    Context 'OIDCAuth' {
        AfterEach {
            $script:InfisicalSession = $null
        }

        It 'Connects successfully with OIDC token' {
            Mock Invoke-InfisicalAuthEndpoint {
                return @{ accessToken = 'mock-token'; expiresIn = 7200 }
            } -ModuleName PSInfisical

            $oidcToken = New-TestSecureString -PlainText 'oidc-token-value'
            $session = Connect-Infisical -OIDCToken $oidcToken -OIDCIdentityId 'oidc-id' -ProjectId 'proj-123' -PassThru

            $session.Connected | Should -BeTrue
            $session.AuthMethod | Should -Be 'OIDCAuth'
        }
    }

    Context 'JWTAuth' {
        AfterEach {
            $script:InfisicalSession = $null
        }

        It 'Connects successfully with JWT' {
            Mock Invoke-InfisicalAuthEndpoint {
                return @{ accessToken = 'mock-token'; expiresIn = 7200 }
            } -ModuleName PSInfisical

            $jwtToken = New-TestSecureString -PlainText 'jwt-token-value'
            $session = Connect-Infisical -Jwt $jwtToken -JwtIdentityId 'jwt-id' -ProjectId 'proj-123' -PassThru

            $session.Connected | Should -BeTrue
            $session.AuthMethod | Should -Be 'JWTAuth'
        }
    }

    Context 'LDAPAuth' {
        AfterEach {
            $script:InfisicalSession = $null
        }

        It 'Connects successfully with LDAP credentials' {
            Mock Invoke-InfisicalAuthEndpoint {
                return @{ accessToken = 'mock-token'; expiresIn = 7200 }
            } -ModuleName PSInfisical

            $ldapPassword = New-TestSecureString -PlainText 'ldap-password'
            $session = Connect-Infisical -LDAPUsername 'user' -LDAPPassword $ldapPassword -ProjectId 'proj-123' -PassThru

            $session.Connected | Should -BeTrue
            $session.AuthMethod | Should -Be 'LDAPAuth'
        }
    }

    Context 'JWT OrganizationId auto-resolution' {
        AfterEach {
            $script:InfisicalSession = $null
        }

        It 'Auto-resolves OrganizationId from JWT identityId claim' {
            # Build a fake JWT with an identityId claim in the payload
            $header = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('{"alg":"HS256","typ":"JWT"}'))
            $payloadJson = '{"identityId":"id-from-jwt-001","sub":"test","iat":1700000000}'
            $payloadB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payloadJson))
            $fakeJwt = "$header.$payloadB64.fake-signature"

            # Mock Invoke-RestMethod for the UniversalAuth login call
            Mock Invoke-RestMethod {
                return @{ accessToken = $fakeJwt; expiresIn = 7200 }
            } -ModuleName PSInfisical

            # Mock Invoke-InfisicalApi for the identity lookup
            Mock Invoke-InfisicalApi {
                return @{ identity = @{ orgId = 'org-auto-123' } }
            } -ModuleName PSInfisical

            $clientSecret = New-TestSecureString -PlainText 'test-client-secret'
            $session = Connect-Infisical -ClientId 'test-client-id' -ClientSecret $clientSecret -ProjectId 'proj-123' -PassThru

            $session.OrganizationId | Should -Be 'org-auto-123'

            Should -Invoke Invoke-InfisicalApi -ModuleName PSInfisical -ParameterFilter {
                $Endpoint -like '*/api/v1/identities/id-from-jwt-001*'
            }
        }

        It 'Explicit -OrganizationId takes precedence over auto-resolution' {
            # Build a fake JWT with an identityId claim
            $header = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('{"alg":"HS256","typ":"JWT"}'))
            $payloadJson = '{"identityId":"id-from-jwt-002","sub":"test","iat":1700000000}'
            $payloadB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payloadJson))
            $fakeJwt = "$header.$payloadB64.fake-signature"

            Mock Invoke-RestMethod {
                return @{ accessToken = $fakeJwt; expiresIn = 7200 }
            } -ModuleName PSInfisical

            # The identity lookup mock should NOT be called because OrganizationId is explicit
            Mock Invoke-InfisicalApi {
                return @{ identity = @{ orgId = 'org-should-not-use' } }
            } -ModuleName PSInfisical

            $clientSecret = New-TestSecureString -PlainText 'test-client-secret'
            $session = Connect-Infisical -ClientId 'test-client-id' -ClientSecret $clientSecret -ProjectId 'proj-123' -OrganizationId 'org-explicit-999' -PassThru

            $session.OrganizationId | Should -Be 'org-explicit-999'

            Should -Invoke Invoke-InfisicalApi -ModuleName PSInfisical -Times 0 -ParameterFilter {
                $Endpoint -like '*/api/v1/identities/*'
            }
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
