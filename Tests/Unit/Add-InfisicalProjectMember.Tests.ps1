using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Add-InfisicalProjectMember' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Grant access' {
        It 'Adds identity to project silently without -PassThru' {
            Mock Invoke-RestMethod {
                return Get-SampleAddProjectMemberResponse
            } -ModuleName PSInfisical

            $result = Add-InfisicalProjectMember -IdentityId 'identity-001' -Role 'member' -Confirm:$false
            $result | Should -BeNullOrEmpty
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns typed InfisicalProjectMembership object' {
            Mock Invoke-RestMethod {
                return Get-SampleAddProjectMemberResponse
            } -ModuleName PSInfisical

            $result = Add-InfisicalProjectMember -IdentityId 'identity-001' -Role 'member' -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames | Should -Contain 'InfisicalProjectMembership'
            $result.Id | Should -Be 'membership-001'
            $result.ProjectId | Should -Be 'test-project-id'
            $result.IdentityId | Should -Be 'identity-001'
            $result.Role | Should -Be 'member'
            $result.CreatedAt | Should -BeOfType [datetime]
            $result.UpdatedAt | Should -BeOfType [datetime]
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return @{} } -ModuleName PSInfisical
            Add-InfisicalProjectMember -IdentityId 'identity-001' -Role 'member' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
