using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Remove-InfisicalSecretBulk' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Bulk delete by array' {
        It 'Deletes multiple secrets in one call' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.secrets | Should -HaveCount 2
                return @{}
            } -ModuleName PSInfisical

            { Remove-InfisicalSecretBulk -Names @('KEY1', 'KEY2') -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }
    }

    Context 'Pipeline input' {
        It 'Accumulates names from pipeline' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical -ParameterFilter { $null -eq $Method -or $Method -eq 'GET' }

            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.secrets.Count | Should -BeGreaterOrEqual 1
                return @{}
            } -ModuleName PSInfisical -ParameterFilter { $Method -eq 'DELETE' }

            { Get-InfisicalSecrets | Remove-InfisicalSecretBulk -Confirm:$false } | Should -Not -Throw
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return @{} } -ModuleName PSInfisical

            Remove-InfisicalSecretBulk -Names @('TEST') -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'ConfirmImpact' {
        It 'Has ConfirmImpact set to High' {
            $cmd = Get-Command Remove-InfisicalSecretBulk
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High'
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
