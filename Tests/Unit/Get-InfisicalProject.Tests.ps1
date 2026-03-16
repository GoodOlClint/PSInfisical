using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalProject' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'List projects' {
        It 'Returns array of project objects' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalProject
            $results | Should -HaveCount 2
        }

        It 'Returns objects with correct properties' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalProject
            $results[0].Name | Should -Be 'Project Alpha'
            $results[0].Slug | Should -Be 'alpha'
            $results[1].Id | Should -Be 'proj-002'
        }

        It 'Objects have InfisicalProject type name' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalProject
            $results[0].PSTypeNames | Should -Contain 'InfisicalProject'
        }
    }

    Context 'Get project by ID' {
        It 'Returns a single project' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectResponse -Id 'proj-abc-123'
            } -ModuleName PSInfisical

            $result = Get-InfisicalProject -Id 'proj-abc-123'
            $result.Name | Should -Be 'My Project'
            $result.Id | Should -Be 'proj-abc-123'
        }

        It 'Writes non-terminating error if not found' {
            Mock Invoke-RestMethod { return $null } -ModuleName PSInfisical

            $result = Get-InfisicalProject -Id 'nonexistent' -ErrorAction SilentlyContinue -ErrorVariable errVar
            $result | Should -BeNullOrEmpty
            $errVar[0].FullyQualifiedErrorId | Should -Match 'InfisicalProjectNotFound'
        }
    }

    Context 'Empty results' {
        It 'Returns nothing when no projects exist' {
            Mock Invoke-RestMethod {
                return @{ workspaces = @() }
            } -ModuleName PSInfisical

            $results = @(Get-InfisicalProject)
            $results | Should -HaveCount 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
