using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Remove-InfisicalProjectMember' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Revoke access' {
        It 'Removes identity from project' {
            Mock Invoke-RestMethod {
                return @{ identityMembership = @{} }
            } -ModuleName PSInfisical

            { Remove-InfisicalProjectMember -IdentityId 'identity-001' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }
    }

    Context 'Not found' {
        It 'Writes non-terminating error if not a member' {
            Mock Invoke-RestMethod { return $null } -ModuleName PSInfisical
            $result = Remove-InfisicalProjectMember -IdentityId 'nonexistent' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable errVar
            $errVar | Should -Not -BeNullOrEmpty
            $errVar[0].FullyQualifiedErrorId | Should -Match 'InfisicalProjectMemberNotFound'
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return @{} } -ModuleName PSInfisical
            Remove-InfisicalProjectMember -IdentityId 'identity-001' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'ConfirmImpact' {
        It 'Has ConfirmImpact set to High' {
            $cmd = Get-Command Remove-InfisicalProjectMember
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High'
        }
    }

    Context 'Pipeline input' {
        It 'Accepts pipeline input from Get-InfisicalProjectMember' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectMembersResponse
            } -ModuleName PSInfisical -ParameterFilter { $null -eq $Method -or $Method -eq 'GET' }

            Mock Invoke-RestMethod {
                return @{ identityMembership = @{} }
            } -ModuleName PSInfisical -ParameterFilter { $Method -eq 'DELETE' }

            { Get-InfisicalProjectMember | Remove-InfisicalProjectMember -Confirm:$false } | Should -Not -Throw
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
