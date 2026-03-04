using module ..\..\PSInfisical.psd1

# Get-InfisicalSecrets.Tests.ps1
# Unit tests for the Get-InfisicalSecrets function.
# Called by: Pester test runner.
# Dependencies: PSInfisical module, TestHelpers.ps1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalSecrets' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Successful retrieval' {
        It 'Returns array of InfisicalSecret objects' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalSecrets

            $results | Should -HaveCount 3
            $results[0].GetType().Name | Should -Be 'InfisicalSecret'
        }

        It 'Returns secrets with correct names' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalSecrets

            $results[0].Name | Should -Be 'DB_HOST'
            $results[1].Name | Should -Be 'DB_PORT'
            $results[2].Name | Should -Be 'API_KEY'
        }

        It 'Emits objects individually (pipeline-friendly)' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $count = 0
            Get-InfisicalSecrets | ForEach-Object { $count++ }

            $count | Should -Be 3
        }
    }

    Context '-AsHashtable' {
        It 'Returns hashtable with Name as key' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $result = Get-InfisicalSecrets -AsHashtable

            $result | Should -BeOfType [hashtable]
            $result.Keys | Should -Contain 'DB_HOST'
            $result.Keys | Should -Contain 'DB_PORT'
            $result['DB_HOST'] | Should -Be 'localhost'
            $result['DB_PORT'] | Should -Be '5432'
        }
    }

    Context '-Filter' {
        It 'Applies client-side filter correctly' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalSecrets -Filter { $_.Name -like 'DB_*' }

            $results | Should -HaveCount 2
            $results[0].Name | Should -Be 'DB_HOST'
            $results[1].Name | Should -Be 'DB_PORT'
        }
    }

    Context 'Empty results' {
        It 'Returns empty results correctly' {
            Mock Invoke-RestMethod {
                return @{ secrets = @() }
            } -ModuleName PSInfisical

            $results = @(Get-InfisicalSecrets)

            $results | Should -HaveCount 0
        }

        It 'Returns empty hashtable when -AsHashtable and no secrets' {
            Mock Invoke-RestMethod {
                return @{ secrets = @() }
            } -ModuleName PSInfisical

            $result = Get-InfisicalSecrets -AsHashtable

            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
