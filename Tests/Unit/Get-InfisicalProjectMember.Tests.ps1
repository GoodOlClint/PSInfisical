using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalProjectMember' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'List members' {
        It 'Returns array of membership objects' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectMembersResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalProjectMember
            $results | Should -HaveCount 2
            $results[0].PSTypeNames | Should -Contain 'InfisicalProjectMember'
        }

        It 'Maps identity name and role correctly' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectMembersResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalProjectMember
            $results[0].IdentityName | Should -Be 'deploy-agent'
            $results[0].Role | Should -Be 'member'
            $results[1].IdentityName | Should -Be 'ci-runner'
            $results[1].Role | Should -Be 'viewer'
        }
    }

    Context 'Empty results' {
        It 'Returns nothing when no members exist' {
            Mock Invoke-RestMethod { return @{ identityMemberships = @() } } -ModuleName PSInfisical
            $results = @(Get-InfisicalProjectMember)
            $results | Should -HaveCount 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
