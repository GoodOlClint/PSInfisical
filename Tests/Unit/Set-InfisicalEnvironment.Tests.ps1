using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Set-InfisicalEnvironment' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Update environment' {
        It 'Updates environment name' {
            Mock Invoke-RestMethod {
                return Get-SampleEnvironmentResponse
            } -ModuleName PSInfisical

            { Set-InfisicalEnvironment -Id 'env-001' -Name 'Pre-Production' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns updated environment' {
            Mock Invoke-RestMethod {
                return Get-SampleEnvironmentResponse -Slug 'pre-prod'
            } -ModuleName PSInfisical

            $result = Set-InfisicalEnvironment -Id 'env-001' -Slug 'pre-prod' -PassThru -Confirm:$false
            $result.PSTypeNames | Should -Contain 'InfisicalEnvironment'
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleEnvironmentResponse } -ModuleName PSInfisical
            Set-InfisicalEnvironment -Id 'env-001' -Name 'test' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'ShouldProcess' {
        It 'Has SupportsShouldProcess' {
            $cmd = Get-Command Set-InfisicalEnvironment
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
