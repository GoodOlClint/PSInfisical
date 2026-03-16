using module ..\..\PSInfisical.psd1

# Remove-InfisicalSecret.Tests.ps1
# Unit tests for the Remove-InfisicalSecret function.
# Called by: Pester test runner.
# Dependencies: PSInfisical module, TestHelpers.ps1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Remove-InfisicalSecret' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Remove secret by name' {
        It 'Removes secret successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'OLD_SECRET'
            } -ModuleName PSInfisical

            { Remove-InfisicalSecret -Name 'OLD_SECRET' -Confirm:$false } | Should -Not -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }
    }

    Context 'v4 parameters' {
        It 'Passes -Type through to API body' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.type | Should -Be 'personal'
                return Get-SampleSecretResponse -Name 'PERSONAL'
            } -ModuleName PSInfisical

            { Remove-InfisicalSecret -Name 'PERSONAL' -Type 'personal' -Confirm:$false } | Should -Not -Throw
        }
    }

    Context 'Pipeline input' {
        It 'Accepts pipeline input from Get-InfisicalSecrets' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical -ParameterFilter { $Method -eq 'GET' -or $null -eq $Method }

            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse
            } -ModuleName PSInfisical -ParameterFilter { $Method -eq 'DELETE' }

            { Get-InfisicalSecrets | Remove-InfisicalSecret -Confirm:$false } | Should -Not -Throw
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse
            } -ModuleName PSInfisical

            Remove-InfisicalSecret -Name 'TEST' -WhatIf

            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'Secret not found' {
        It 'Writes non-terminating error if not found' {
            Mock Invoke-RestMethod {
                return $null
            } -ModuleName PSInfisical

            $result = Remove-InfisicalSecret -Name 'NONEXISTENT' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable errVar

            $errVar | Should -Not -BeNullOrEmpty
            $errVar[0].FullyQualifiedErrorId | Should -Match 'InfisicalSecretNotFound'
        }
    }

    Context 'ConfirmImpact' {
        It 'Has ConfirmImpact set to High' {
            $cmd = Get-Command Remove-InfisicalSecret
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High'
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
