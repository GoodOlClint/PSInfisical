using module ..\..\PSInfisical.psd1

# Set-InfisicalProject.Tests.ps1
# Unit tests for the Set-InfisicalProject function.

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Set-InfisicalProject' {

    BeforeEach {
        $mockSession = New-MockSession
        Mock Get-InfisicalSession { return $mockSession } -ModuleName PSInfisical
    }

    Context 'Rename project' {
        It 'Calls PATCH with new name' {
            Mock Invoke-InfisicalApi {
                return @{
                    workspace = @{
                        id        = 'proj-001'
                        name      = 'new-name'
                        slug      = 'new-name'
                        createdAt = '2025-01-01T00:00:00Z'
                        updatedAt = '2025-06-01T00:00:00Z'
                    }
                }
            } -ModuleName PSInfisical

            Set-InfisicalProject -Id 'proj-001' -Name 'new-name'

            Should -Invoke Invoke-InfisicalApi -ModuleName PSInfisical -ParameterFilter {
                $Method -eq 'PATCH' -and $Endpoint -eq '/api/v2/workspace/proj-001'
            }
        }

        It '-PassThru returns updated project' {
            Mock Invoke-InfisicalApi {
                return @{
                    workspace = @{
                        id        = 'proj-001'
                        name      = 'renamed'
                        slug      = 'renamed'
                        createdAt = '2025-01-01T00:00:00Z'
                        updatedAt = '2025-06-01T00:00:00Z'
                    }
                }
            } -ModuleName PSInfisical

            $result = Set-InfisicalProject -Id 'proj-001' -Name 'renamed' -PassThru
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'renamed'
            $result.PSObject.TypeNames | Should -Contain 'InfisicalProject'
        }
    }

    Context 'Set AutoCapitalization' {
        It 'Sends autoCapitalization in body' {
            Mock Invoke-InfisicalApi {
                return @{ workspace = @{ id = 'proj-001'; name = 'test'; slug = 'test'; createdAt = '2025-01-01T00:00:00Z'; updatedAt = '2025-06-01T00:00:00Z' } }
            } -ModuleName PSInfisical

            Set-InfisicalProject -Id 'proj-001' -AutoCapitalization $true

            Should -Invoke Invoke-InfisicalApi -ModuleName PSInfisical -ParameterFilter {
                $Method -eq 'PATCH' -and $Body.autoCapitalization -eq $true
            }
        }
    }

    Context 'No properties' {
        It 'Warns when no properties specified' {
            Set-InfisicalProject -Id 'proj-001' 3>&1 | Should -BeLike '*No properties*'
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-InfisicalApi {} -ModuleName PSInfisical

            Set-InfisicalProject -Id 'proj-001' -Name 'test' -WhatIf

            Should -Not -Invoke Invoke-InfisicalApi -ModuleName PSInfisical
        }
    }

    Context 'ShouldProcess' {
        It 'Has SupportsShouldProcess' {
            (Get-Command Set-InfisicalProject).Parameters.Keys | Should -Contain 'WhatIf'
        }
    }

    Context 'Pipeline' {
        It 'Accepts Id from pipeline by property name' {
            Mock Invoke-InfisicalApi {
                return @{ workspace = @{ id = 'proj-pipe'; name = 'piped'; slug = 'piped'; createdAt = '2025-01-01T00:00:00Z'; updatedAt = '2025-06-01T00:00:00Z' } }
            } -ModuleName PSInfisical

            [PSCustomObject]@{ Id = 'proj-pipe' } | Set-InfisicalProject -Name 'piped'

            Should -Invoke Invoke-InfisicalApi -ModuleName PSInfisical -ParameterFilter {
                $Endpoint -eq '/api/v2/workspace/proj-pipe'
            }
        }
    }
}
