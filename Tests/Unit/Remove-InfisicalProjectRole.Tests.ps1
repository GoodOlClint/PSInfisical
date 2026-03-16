using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Remove-InfisicalProjectRole' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Remove role' {
        It 'Deletes role successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectRoleResponse
            } -ModuleName PSInfisical

            { Remove-InfisicalProjectRole -RoleId 'role-custom-001' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }
    }

    Context 'Not found' {
        It 'Writes non-terminating error if role not found' {
            Mock Invoke-RestMethod { return $null } -ModuleName PSInfisical
            $result = Remove-InfisicalProjectRole -RoleId 'nonexistent' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable errVar
            $errVar | Should -Not -BeNullOrEmpty
            $errVar[0].FullyQualifiedErrorId | Should -Match 'InfisicalProjectRoleNotFound'
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleProjectRoleResponse } -ModuleName PSInfisical
            Remove-InfisicalProjectRole -RoleId 'role-001' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'ConfirmImpact' {
        It 'Has ConfirmImpact set to High' {
            $cmd = Get-Command Remove-InfisicalProjectRole
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High'
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
