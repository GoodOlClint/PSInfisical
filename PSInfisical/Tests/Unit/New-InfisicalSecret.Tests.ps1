using module ..\..\PSInfisical.psd1

# New-InfisicalSecret.Tests.ps1
# Unit tests for the New-InfisicalSecret function.
# Called by: Pester test runner.
# Dependencies: PSInfisical module, TestHelpers.ps1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'New-InfisicalSecret' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Create with SecureString value' {
        It 'Creates secret with SecureString value' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'NEW_SECRET' -Value 'new-value'
            } -ModuleName PSInfisical

            $value = New-TestSecureString -PlainText 'new-value'
            { New-InfisicalSecret -Name 'NEW_SECRET' -Value $value -Confirm:$false } | Should -Not -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns created secret' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'NEW_SECRET' -Value 'new-value'
            } -ModuleName PSInfisical

            $value = New-TestSecureString -PlainText 'new-value'
            $result = New-InfisicalSecret -Name 'NEW_SECRET' -Value $value -PassThru -Confirm:$false

            $result.GetType().Name | Should -Be 'InfisicalSecret'
            $result.Name | Should -Be 'NEW_SECRET'
        }
    }

    Context '-PlainTextValue' {
        It 'Emits Write-Warning when using -PlainTextValue' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'PLAIN_SECRET' -Value 'plain-value'
            } -ModuleName PSInfisical

            $warnings = New-InfisicalSecret -Name 'PLAIN_SECRET' -PlainTextValue 'plain-value' -Confirm:$false 3>&1

            $warningMessages = ($warnings | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }).Message -join ' '
            $warningMessages | Should -Match 'PlainTextValue'
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse
            } -ModuleName PSInfisical

            $value = New-TestSecureString -PlainText 'test'
            New-InfisicalSecret -Name 'TEST' -Value $value -WhatIf

            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'Error handling' {
        It 'Throws if API returns error (e.g. secret already exists)' {
            Mock Invoke-RestMethod {
                $response = [System.Net.HttpWebResponse]::new()
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Conflict', $response)
            } -ModuleName PSInfisical -ParameterFilter { $Uri -match 'secrets/raw' }

            # The function may throw depending on the error type; ensure it does not silently succeed
            $value = New-TestSecureString -PlainText 'test'
            { New-InfisicalSecret -Name 'EXISTING' -Value $value -Confirm:$false -ErrorAction Stop } |
                Should -Throw
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
