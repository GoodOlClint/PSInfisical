using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Set-InfisicalSecretBulk' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Bulk update' {
        It 'Updates multiple secrets in one call' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.secrets | Should -HaveCount 2
                return @{ secrets = @() }
            } -ModuleName PSInfisical

            $secrets = @(
                @{ Name = 'KEY1'; Value = 'new-val1' }
                @{ Name = 'KEY2'; Value = 'new-val2' }
            )
            { Set-InfisicalSecretBulk -Secrets $secrets -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return @{ secrets = @() } } -ModuleName PSInfisical

            $secrets = @(@{ Name = 'TEST'; Value = 'val' })
            Set-InfisicalSecretBulk -Secrets $secrets -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'ShouldProcess' {
        It 'Has SupportsShouldProcess' {
            $cmd = Get-Command Set-InfisicalSecretBulk
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
