using module ..\..\PSInfisical.psd1

# Get-InfisicalSecretVersion.Tests.ps1
# Unit tests for the Get-InfisicalSecretVersion function.
# Called by: Pester test runner.
# Dependencies: PSInfisical module, TestHelpers.ps1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalSecretVersion' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Successful version retrieval' {
        It 'Returns version objects for a secret with multiple versions' {
            Mock Invoke-RestMethod {
                if ($Uri -match 'version=(\d+)') {
                    $v = [int]$Matches[1]
                    return Get-SampleSecretResponse -Name 'VERSIONED' -Value "value-v$v" -Version $v
                }
                else {
                    # Initial fetch — return current version
                    return Get-SampleSecretResponse -Name 'VERSIONED' -Value 'value-v3' -Version 3
                }
            } -ModuleName PSInfisical

            $results = @(Get-InfisicalSecretVersion -Name 'VERSIONED' -Limit 3)

            $results | Should -HaveCount 3
            $results[0].Version | Should -Be 3
            $results[1].Version | Should -Be 2
            $results[2].Version | Should -Be 1
        }

        It 'Returns objects with correct properties' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'MY_SECRET' -Value 'secret-val' -Version 1
            } -ModuleName PSInfisical

            $results = @(Get-InfisicalSecretVersion -Name 'MY_SECRET' -Limit 1)

            $results | Should -HaveCount 1
            $results[0].Name | Should -Be 'MY_SECRET'
            $results[0].Version | Should -Be 1
            $results[0].PSObject.Properties.Name | Should -Contain 'Value'
            $results[0].PSObject.Properties.Name | Should -Contain 'CreatedAt'
        }

        It 'Stores version values as SecureString' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'SECURE_VER' -Value 'hidden-value' -Version 1
            } -ModuleName PSInfisical

            $results = @(Get-InfisicalSecretVersion -Name 'SECURE_VER' -Limit 1)

            $results[0].Value | Should -BeOfType [System.Security.SecureString]
        }
    }

    Context 'Secret not found' {
        It 'Writes non-terminating error when secret not found' {
            Mock Invoke-RestMethod {
                return $null
            } -ModuleName PSInfisical

            $result = Get-InfisicalSecretVersion -Name 'NONEXISTENT' -ErrorAction SilentlyContinue -ErrorVariable errVar

            $result | Should -BeNullOrEmpty
            $errVar | Should -Not -BeNullOrEmpty
            $errVar[0].FullyQualifiedErrorId | Should -Match 'InfisicalSecretNotFound'
        }
    }

    Context 'Not connected' {
        It 'Throws terminating error when not connected' {
            & (Get-Module PSInfisical) { $script:InfisicalSession = $null }

            { Get-InfisicalSecretVersion -Name 'TEST' -ErrorAction Stop } |
                Should -Throw '*Not connected to Infisical*'

            # Restore session
            & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
        }
    }

    Context 'Limit parameter' {
        It 'Respects the Limit parameter' {
            Mock Invoke-RestMethod {
                if ($Uri -match 'version=(\d+)') {
                    $v = [int]$Matches[1]
                    return Get-SampleSecretResponse -Name 'LIMITED' -Value "val-v$v" -Version $v
                }
                else {
                    return Get-SampleSecretResponse -Name 'LIMITED' -Value 'val' -Version 10
                }
            } -ModuleName PSInfisical

            $results = @(Get-InfisicalSecretVersion -Name 'LIMITED' -Limit 2)

            # Should get 2 versions (plus 1 initial fetch = 3 total API calls)
            $results | Should -HaveCount 2
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
