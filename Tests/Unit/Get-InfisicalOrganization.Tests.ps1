using module ..\..\PSInfisical.psd1

# Get-InfisicalOrganization.Tests.ps1
# Unit tests for the Get-InfisicalOrganization function.

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalOrganization' {

    BeforeEach {
        $mockSession = New-MockSession
        Mock Get-InfisicalSession { return $mockSession } -ModuleName PSInfisical
    }

    Context 'List organizations' {
        It 'Returns all organizations' {
            Mock Invoke-InfisicalApi {
                return @{
                    organizations = @(
                        @{ id = 'org-001'; name = 'Acme Corp'; slug = 'acme-corp'; createdAt = '2025-01-01T00:00:00Z' }
                        @{ id = 'org-002'; name = 'Test Org'; slug = 'test-org'; createdAt = '2025-06-01T00:00:00Z' }
                    )
                }
            } -ModuleName PSInfisical

            $result = Get-InfisicalOrganization
            $result | Should -HaveCount 2
            $result[0].Id | Should -Be 'org-001'
            $result[0].Name | Should -Be 'Acme Corp'
            $result[0].PSObject.TypeNames | Should -Contain 'InfisicalOrganization'
        }

        It 'Calls /api/v1/organization endpoint' {
            Mock Invoke-InfisicalApi { return @{ organizations = @() } } -ModuleName PSInfisical

            Get-InfisicalOrganization

            Should -Invoke Invoke-InfisicalApi -ModuleName PSInfisical -ParameterFilter {
                $Method -eq 'GET' -and $Endpoint -eq '/api/v1/organization'
            }
        }

        It 'Returns nothing when no organizations' {
            Mock Invoke-InfisicalApi { return @{ organizations = @() } } -ModuleName PSInfisical

            $result = Get-InfisicalOrganization
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Get by ID' {
        It 'Filters to a single organization' {
            Mock Invoke-InfisicalApi {
                return @{
                    organizations = @(
                        @{ id = 'org-001'; name = 'Acme Corp'; slug = 'acme-corp'; createdAt = '2025-01-01T00:00:00Z' }
                        @{ id = 'org-002'; name = 'Other Org'; slug = 'other'; createdAt = '2025-06-01T00:00:00Z' }
                    )
                }
            } -ModuleName PSInfisical

            $result = Get-InfisicalOrganization -Id 'org-001'
            $result | Should -HaveCount 1
            $result.Id | Should -Be 'org-001'
            $result.Name | Should -Be 'Acme Corp'
        }

        It 'Writes non-terminating error if not found' {
            Mock Invoke-InfisicalApi {
                return @{ organizations = @( @{ id = 'org-other'; name = 'Other'; slug = 'other'; createdAt = '2025-01-01T00:00:00Z' } ) }
            } -ModuleName PSInfisical

            $result = Get-InfisicalOrganization -Id 'org-missing' -ErrorVariable errs -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $errs | Should -HaveCount 1
            $errs[0].FullyQualifiedErrorId | Should -Match 'InfisicalOrganizationNotFound'
        }
    }
}
