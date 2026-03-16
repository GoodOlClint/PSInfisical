using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Set-InfisicalTag' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Update tag' {
        It 'Updates tag color' {
            Mock Invoke-RestMethod {
                return Get-SampleTagResponse -Slug 'production' -Color '#0000FF'
            } -ModuleName PSInfisical

            { Set-InfisicalTag -Id 'tag-001' -Color '#0000FF' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns updated tag' {
            Mock Invoke-RestMethod {
                return Get-SampleTagResponse -Slug 'renamed' -Color '#0000FF'
            } -ModuleName PSInfisical

            $result = Set-InfisicalTag -Id 'tag-001' -Slug 'renamed' -PassThru -Confirm:$false
            $result.GetType().Name | Should -Be 'InfisicalTag'
            $result.Slug | Should -Be 'renamed'
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleTagResponse } -ModuleName PSInfisical
            Set-InfisicalTag -Id 'tag-001' -Color '#FFF' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'ShouldProcess' {
        It 'Has SupportsShouldProcess' {
            $cmd = Get-Command Set-InfisicalTag
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
