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

    Context 'v4 parameters' {
        It 'Passes -TagIds through to API body' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.tagIds | Should -HaveCount 2
                return Get-SampleSecretResponse -Name 'TAGGED' -Value 'val'
            } -ModuleName PSInfisical

            $value = New-TestSecureString -PlainText 'val'
            { New-InfisicalSecret -Name 'TAGGED' -Value $value -TagIds @('tag-001', 'tag-002') -Confirm:$false } | Should -Not -Throw
        }

        It 'Passes -Metadata through to API body' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.secretMetadata | Should -Not -BeNullOrEmpty
                return Get-SampleSecretResponse -Name 'META' -Value 'val'
            } -ModuleName PSInfisical

            $value = New-TestSecureString -PlainText 'val'
            { New-InfisicalSecret -Name 'META' -Value $value -Metadata @{ team = 'backend' } -Confirm:$false } | Should -Not -Throw
        }

        It 'Passes -Type through to API body' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.type | Should -Be 'personal'
                return Get-SampleSecretResponse -Name 'PERSONAL' -Value 'val'
            } -ModuleName PSInfisical

            $value = New-TestSecureString -PlainText 'val'
            { New-InfisicalSecret -Name 'PERSONAL' -Value $value -Type 'personal' -Confirm:$false } | Should -Not -Throw
        }

        It 'Passes -ReminderRepeatDays and -ReminderNote through to API body' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.secretReminderRepeatDays | Should -Be 30
                $parsed.secretReminderNote | Should -Be 'Rotate monthly'
                return Get-SampleSecretResponse -Name 'REMIND' -Value 'val'
            } -ModuleName PSInfisical

            $value = New-TestSecureString -PlainText 'val'
            { New-InfisicalSecret -Name 'REMIND' -Value $value -ReminderRepeatDays 30 -ReminderNote 'Rotate monthly' -Confirm:$false } | Should -Not -Throw
        }

        It '-PassThru returns v4 metadata properties' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponseWithMetadata -Name 'FULL_META' -Value 'val'
            } -ModuleName PSInfisical

            $value = New-TestSecureString -PlainText 'val'
            $result = New-InfisicalSecret -Name 'FULL_META' -Value $value -PassThru -Confirm:$false

            $result.TagIds | Should -HaveCount 2
            $result.Metadata.Keys | Should -Contain 'team'
            $result.ReminderRepeatDays | Should -Be 90
            $result.Type | Should -Be 'personal'
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
