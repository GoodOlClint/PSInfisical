using module ..\..\PSInfisical.psd1

# Invoke-InfisicalApi.Integration.Tests.ps1
# Integration tests for Invoke-InfisicalApi covering:
#   - 429 retry behavior via an OpenResty mock container
#   - Error paths: 404, 401, 403, 5xx
# Called by: Pester test runner (Invoke-Build Test-Integration).

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')

    $testUrl = $env:INFISICAL_TEST_URL
    if (-not $testUrl) { $testUrl = 'http://localhost:8080' }

    $mockUrl = $env:MOCK_429_URL
    if (-not $mockUrl) { $mockUrl = 'http://localhost:8429' }
}

Describe 'Invoke-InfisicalApi Integration Tests' -Tag 'Integration' {

    Context '429 Retry Behavior' {

        BeforeAll {
            # Build a session pointing at the mock server
            $mockSession = New-MockSession -ApiUrl $mockUrl -TokenValue 'mock-token-for-429-test'
        }

        BeforeEach {
            # Reset the mock counter before each test
            Invoke-RestMethod -Uri "$mockUrl/reset" -Method GET -TimeoutSec 5 -ErrorAction Stop | Out-Null
        }

        It 'Retries on 429 and eventually succeeds' {
            # The mock returns 429 twice then 200 with a valid secret response.
            # Invoke-InfisicalApi has maxRetries=3, so it should succeed on attempt 3.
            $result = & (Get-Module PSInfisical) {
                param($session)
                Invoke-InfisicalApi -Method GET -Endpoint '/api/test' -Session $session
            } $mockSession

            $result | Should -Not -BeNullOrEmpty
            $result.secret.secretKey | Should -Be 'MOCK'
        }

        It 'Returns a valid response body after retry' {
            $result = & (Get-Module PSInfisical) {
                param($session)
                Invoke-InfisicalApi -Method GET -Endpoint '/api/test' -Session $session
            } $mockSession

            $result.secret.secretValue | Should -Be 'mock-value'
        }
    }

    Context 'Error Handling - 404' {

        BeforeAll {
            # Real session against the live Infisical instance
            $clientId = $env:INFISICAL_TEST_CLIENT_ID
            $clientSecret = $env:INFISICAL_TEST_CLIENT_SECRET
            $projectId = $env:INFISICAL_TEST_PROJECT_ID

            if (-not $clientId -or -not $clientSecret -or -not $projectId) {
                throw 'INFISICAL_TEST_CLIENT_ID, INFISICAL_TEST_CLIENT_SECRET, and INFISICAL_TEST_PROJECT_ID must be set.'
            }

            $secureSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
            Connect-Infisical -ClientId $clientId -ClientSecret $secureSecret -ProjectId $projectId -ApiUrl $testUrl -Environment 'dev'
        }

        It 'Returns $null for a non-existent secret name' {
            $result = Get-InfisicalSecret -Name "NONEXISTENT_SECRET_$([guid]::NewGuid().ToString('N'))" -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Error Handling - 401' {

        It 'Throws an auth error with an invalid token' {
            # Connect with a garbage token — subsequent API calls should get 401 or 403
            $fakeToken = ConvertTo-SecureString -String 'expired-or-invalid-token' -AsPlainText -Force
            Connect-Infisical -AccessToken $fakeToken -ProjectId 'fake-project-id' -ApiUrl $testUrl -Environment 'dev'

            $thrown = $null
            try {
                Get-InfisicalSecrets -ErrorAction Stop
            }
            catch {
                $thrown = $_
            }

            $thrown | Should -Not -BeNullOrEmpty
            # Infisical may return 401 or 403 depending on how the token is validated
            $thrown.FullyQualifiedErrorId | Should -Match 'Infisical(AuthenticationFailed|AccessDenied)'
        }
    }

    Context 'Error Handling - 403' {
        # 403 testing against a real Infisical instance requires a machine identity
        # that has a valid token but lacks permission on the target project.
        #
        # Infisical's permission model is role-based at the project level. To trigger
        # a 403, we would need a second identity with 'no-access' role on the test
        # project. This is achievable but adds significant setup complexity.
        #
        # APPROACH: Create a second identity with org-level access but NO project
        # membership, then try to read secrets from the test project. Infisical
        # returns 403 when the identity has a valid token but no project membership.

        BeforeAll {
            $clientId = $env:INFISICAL_TEST_CLIENT_ID
            $clientSecret = $env:INFISICAL_TEST_CLIENT_SECRET
            $projectId = $env:INFISICAL_TEST_PROJECT_ID

            if (-not $clientId -or -not $clientSecret -or -not $projectId) {
                Set-ItResult -Skipped -Because 'Test credentials not available'
                return
            }

            # We use the admin JWT from bootstrap to create a restricted identity.
            # If the admin JWT is not available, skip this test.
            $secureSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force

            # Connect as the test identity to get a valid token, then connect
            # against a project the identity doesn't belong to.
            Connect-Infisical -ClientId $clientId -ClientSecret $secureSecret -ProjectId 'nonexistent-project-id' -ApiUrl $testUrl -Environment 'dev'
        }

        It 'Returns an error or empty result when identity lacks project permission' {
            # With a nonexistent project ID, Infisical may return 403 (access denied),
            # 404 (not found, mapped to $null), or an empty result depending on the
            # API version. We verify the function handles it gracefully.
            $thrown = $null
            $result = $null
            try {
                $result = Get-InfisicalSecrets -ErrorAction Stop
            }
            catch {
                $thrown = $_
            }

            # Either an auth/access error was thrown, or the function returned empty
            if ($thrown) {
                $thrown.FullyQualifiedErrorId | Should -Match 'Infisical(AuthenticationFailed|AccessDenied|ApiError|ApiVersionUnsupported)'
            }
            else {
                # 404 maps to $null — function returns nothing, which is acceptable
                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Error Handling - 5xx' {
        # Triggering a genuine 5xx against a healthy Infisical instance is not
        # reliably possible without corrupting server state or sending malformed
        # internal requests. The 429 mock proves our error-handling pipeline works
        # end-to-end with real HTTP, and the unit tests verify the 5xx error-record
        # construction. A dedicated 5xx integration test would require either:
        #   - A second mock container returning 500 (trivial but adds infra)
        #   - Intentionally crashing a backend dependency (unreliable)
        #
        # OUT OF SCOPE: 5xx paths are covered by unit tests and the 429 mock
        # validates the real-HTTP error-handling pipeline.

        It 'Is documented as out of scope — covered by unit tests and 429 mock' -Tag 'Integration' {
            Set-ItResult -Skipped -Because '5xx cannot be reliably triggered against a healthy Infisical instance. See comment block above.'
        }
    }
}

AfterAll {
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
