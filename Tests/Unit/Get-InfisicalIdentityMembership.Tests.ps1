using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalIdentityMembership' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'List memberships' {
        It 'Returns project membership objects' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentityMembershipsResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalIdentityMembership -IdentityId 'identity-001'
            $results | Should -HaveCount 2
            $results[0].PSTypeNames | Should -Contain 'InfisicalIdentityMembership'
        }

        It 'Maps project name and role correctly' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentityMembershipsResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalIdentityMembership -IdentityId 'identity-001'
            $results[0].ProjectName | Should -Be 'Project Alpha'
            $results[0].Role | Should -Be 'member'
            $results[1].ProjectName | Should -Be 'Project Beta'
            $results[1].Role | Should -Be 'viewer'
        }
    }

    Context 'Empty results' {
        It 'Returns nothing when identity has no memberships' {
            Mock Invoke-RestMethod { return @{ identityMemberships = @() } } -ModuleName PSInfisical
            $results = @(Get-InfisicalIdentityMembership -IdentityId 'identity-001')
            $results | Should -HaveCount 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
