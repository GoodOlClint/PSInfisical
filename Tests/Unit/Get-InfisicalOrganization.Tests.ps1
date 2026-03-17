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
        $mockSession.OrganizationId = 'org-session'
        Mock Get-InfisicalSession { return $mockSession } -ModuleName PSInfisical
    }

    Context 'Default (session org)' {
        It 'Uses session OrganizationId when no -Id specified' {
            Mock Invoke-InfisicalApi {
                return @{
                    organization = @{ id = 'org-session'; name = 'My Org'; slug = 'my-org'; createdAt = '2025-01-01T00:00:00Z' }
                }
            } -ModuleName PSInfisical

            $result = Get-InfisicalOrganization
            $result.Id | Should -Be 'org-session'
            $result.Name | Should -Be 'My Org'
            $result.PSObject.TypeNames | Should -Contain 'InfisicalOrganization'

            Should -Invoke Invoke-InfisicalApi -ModuleName PSInfisical -ParameterFilter {
                $Endpoint -eq '/api/v1/organization/org-session'
            }
        }

        It 'Throws when session has no OrganizationId' {
            $mockSession.OrganizationId = $null
            { Get-InfisicalOrganization } | Should -Throw '*OrganizationId*'
        }
    }

    Context 'Get by ID' {
        It 'Returns a single organization' {
            Mock Invoke-InfisicalApi {
                return @{
                    organization = @{ id = 'org-001'; name = 'Acme Corp'; slug = 'acme-corp'; createdAt = '2025-01-01T00:00:00Z' }
                }
            } -ModuleName PSInfisical

            $result = Get-InfisicalOrganization -Id 'org-001'
            $result.Id | Should -Be 'org-001'
            $result.Name | Should -Be 'Acme Corp'
        }

        It 'Calls correct API endpoint with ID' {
            Mock Invoke-InfisicalApi {
                return @{
                    organization = @{ id = 'org-001'; name = 'Test'; slug = 'test'; createdAt = '2025-01-01T00:00:00Z' }
                }
            } -ModuleName PSInfisical

            Get-InfisicalOrganization -Id 'org-001'

            Should -Invoke Invoke-InfisicalApi -ModuleName PSInfisical -ParameterFilter {
                $Method -eq 'GET' -and $Endpoint -eq '/api/v1/organization/org-001'
            }
        }

        It 'Writes non-terminating error if not found' {
            Mock Invoke-InfisicalApi { return $null } -ModuleName PSInfisical

            $result = Get-InfisicalOrganization -Id 'org-missing' -ErrorVariable errs -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $errs | Should -HaveCount 1
            $errs[0].FullyQualifiedErrorId | Should -Match 'InfisicalOrganizationNotFound'
        }
    }
}
