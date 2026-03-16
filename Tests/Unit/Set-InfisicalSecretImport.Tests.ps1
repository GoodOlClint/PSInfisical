using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Set-InfisicalSecretImport' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Update secret import' {
        It 'Updates position successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretImportResponse
            } -ModuleName PSInfisical

            { Set-InfisicalSecretImport -Id 'import-001' -Position 1 -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns updated import' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretImportResponse
            } -ModuleName PSInfisical

            $result = Set-InfisicalSecretImport -Id 'import-001' -Position 1 -PassThru -Confirm:$false
            $result.GetType().Name | Should -Be 'InfisicalSecretImport'
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleSecretImportResponse } -ModuleName PSInfisical
            Set-InfisicalSecretImport -Id 'import-001' -Position 1 -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'ShouldProcess' {
        It 'Has SupportsShouldProcess' {
            $cmd = Get-Command Set-InfisicalSecretImport
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
