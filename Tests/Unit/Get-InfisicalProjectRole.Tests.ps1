using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalProjectRole' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'List roles' {
        It 'Returns array of role objects' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectRolesResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalProjectRole
            $results | Should -HaveCount 3
            $results[0].PSTypeNames | Should -Contain 'InfisicalProjectRole'
        }

        It 'Returns roles with correct properties' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectRolesResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalProjectRole
            $results[0].Slug | Should -Be 'admin'
            $results[1].Name | Should -Be 'Member'
            $results[2].Description | Should -Be 'Read-only access'
        }
    }

    Context 'Empty results' {
        It 'Returns nothing when no roles exist' {
            Mock Invoke-RestMethod { return @{ roles = @() } } -ModuleName PSInfisical
            $results = @(Get-InfisicalProjectRole)
            $results | Should -HaveCount 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
