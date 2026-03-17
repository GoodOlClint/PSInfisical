using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalIdentity' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'List identities' {
        It 'Returns array of InfisicalIdentity objects' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentitiesListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalIdentity -OrganizationId 'org-test-123'
            $results | Should -HaveCount 2
            $results[0].GetType().Name | Should -Be 'InfisicalIdentity'
        }

        It 'Returns identities with correct names' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentitiesListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalIdentity -OrganizationId 'org-test-123'
            $results[0].Name | Should -Be 'deploy-agent'
            $results[1].Name | Should -Be 'ci-runner'
            $results[1].HasDeleteProtection | Should -BeTrue
        }
    }

    Context 'Get by ID' {
        It 'Returns a single identity' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentityResponse -Name 'my-agent' -Id 'identity-001'
            } -ModuleName PSInfisical

            $result = Get-InfisicalIdentity -Id 'identity-001'
            $result.GetType().Name | Should -Be 'InfisicalIdentity'
            $result.Name | Should -Be 'my-agent'
            $result.Role | Should -Be 'member'
        }

        It 'Writes non-terminating error if not found' {
            Mock Invoke-RestMethod { return $null } -ModuleName PSInfisical

            $result = Get-InfisicalIdentity -Id 'nonexistent' -ErrorAction SilentlyContinue -ErrorVariable errVar
            $result | Should -BeNullOrEmpty
            $errVar[0].FullyQualifiedErrorId | Should -Match 'InfisicalIdentityNotFound'
        }
    }

    Context 'List identities with membership-wrapped response' {
        It 'Unwraps nested identity from membership wrapper' {
            Mock Invoke-RestMethod {
                return @{
                    identities = @(
                        @{
                            id         = 'membership-001'
                            role       = 'admin'
                            orgId      = 'org-123'
                            identityId = 'identity-real-001'
                            createdAt  = '2025-01-01T00:00:00Z'
                            updatedAt  = '2025-06-01T00:00:00Z'
                            identity   = @{
                                name                = 'deploy-agent'
                                id                  = 'identity-real-001'
                                hasDeleteProtection = $false
                                authMethods         = @('universal-auth')
                            }
                        }
                    )
                }
            } -ModuleName PSInfisical

            $results = Get-InfisicalIdentity -OrganizationId 'org-123'
            $results | Should -HaveCount 1
            $results[0].Id | Should -Be 'identity-real-001'
            $results[0].Name | Should -Be 'deploy-agent'
            $results[0].OrganizationId | Should -Be 'org-123'
            $results[0].Role | Should -Be 'admin'
            $results[0].AuthMethods | Should -Contain 'universal-auth'
        }
    }

    Context 'Empty results' {
        It 'Returns nothing when no identities exist' {
            Mock Invoke-RestMethod { return @{ identities = @() } } -ModuleName PSInfisical
            $results = @(Get-InfisicalIdentity -OrganizationId 'org-123')
            $results | Should -HaveCount 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
