using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'New-InfisicalProjectRole' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Create role' {
        It 'Creates role successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectRoleResponse
            } -ModuleName PSInfisical

            $perms = @(@{ subject = 'secrets'; action = @('read') })
            { New-InfisicalProjectRole -Name 'Read Only' -Slug 'read-only' -Permissions $perms -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns created role' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectRoleResponse -Slug 'custom'
            } -ModuleName PSInfisical

            $perms = @(@{ subject = 'secrets'; action = @('read') })
            $result = New-InfisicalProjectRole -Name 'Custom' -Slug 'custom' -Permissions $perms -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleProjectRoleResponse } -ModuleName PSInfisical
            $perms = @(@{ subject = 'secrets'; action = @('read') })
            New-InfisicalProjectRole -Name 'Test' -Slug 'test' -Permissions $perms -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
