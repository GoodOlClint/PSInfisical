using module ..\..\PSInfisical.psd1

# Set-InfisicalFolder.Tests.ps1
# Unit tests for the Set-InfisicalFolder function.
# Called by: Pester test runner.
# Dependencies: PSInfisical module, TestHelpers.ps1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Set-InfisicalFolder' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Update folder' {
        It 'Renames folder successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleFolderResponse -Name 'renamed'
            } -ModuleName PSInfisical

            { Set-InfisicalFolder -Id 'folder-001' -NewName 'renamed' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns updated folder' {
            Mock Invoke-RestMethod {
                return Get-SampleFolderResponse -Name 'renamed'
            } -ModuleName PSInfisical

            $result = Set-InfisicalFolder -Id 'folder-001' -NewName 'renamed' -PassThru -Confirm:$false

            $result.GetType().Name | Should -Be 'InfisicalFolder'
            $result.Name | Should -Be 'renamed'
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod {
                return Get-SampleFolderResponse
            } -ModuleName PSInfisical

            Set-InfisicalFolder -Id 'folder-001' -NewName 'test' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'ShouldProcess' {
        It 'Has SupportsShouldProcess' {
            $cmd = Get-Command Set-InfisicalFolder
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
