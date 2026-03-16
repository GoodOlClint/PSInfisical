using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'New-InfisicalSecretBulk' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Bulk create' {
        It 'Creates multiple secrets in one call' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.secrets | Should -HaveCount 2
                return @{ secrets = @() }
            } -ModuleName PSInfisical

            $secrets = @(
                @{ Name = 'KEY1'; Value = 'val1' }
                @{ Name = 'KEY2'; Value = 'val2' }
            )
            { New-InfisicalSecretBulk -Secrets $secrets -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns created secrets' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $secrets = @(
                @{ Name = 'DB_HOST'; Value = 'localhost' }
                @{ Name = 'DB_PORT'; Value = '5432' }
            )
            $results = New-InfisicalSecretBulk -Secrets $secrets -PassThru -Confirm:$false
            $results | Should -HaveCount 3  # Mock returns 3 from sample
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return @{ secrets = @() } } -ModuleName PSInfisical

            $secrets = @(@{ Name = 'TEST'; Value = 'val' })
            New-InfisicalSecretBulk -Secrets $secrets -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
