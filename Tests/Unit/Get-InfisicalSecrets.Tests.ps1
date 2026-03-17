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

    Context 'v4 properties on returned objects' {
        It 'Returns TagIds from API response' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalSecrets

            # Third secret (API_KEY) has a tag in the sample response
            $results[2].TagIds | Should -HaveCount 1
            $results[2].TagIds[0] | Should -Be 'tag-001'
        }

        It 'Returns Metadata from API response' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalSecrets

            $results[2].Metadata.Keys | Should -Contain 'owner'
            $results[2].Metadata['owner'] | Should -Be 'platform-team'
        }

        It 'Returns Type from API response' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalSecrets

            $results[0].Type | Should -Be 'shared'
        }
    }

    Context 'v4 query parameters' {
        It 'Passes -TagSlugs as comma-separated query param' {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match 'tagSlugs=prod(%2C|,)db'
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            Get-InfisicalSecrets -TagSlugs @('prod', 'db') | Out-Null
        }

        It 'Passes -ExpandSecretReferences as query param' {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match 'expandSecretReferences=true'
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            Get-InfisicalSecrets -ExpandSecretReferences | Out-Null
        }

        It 'Passes -IncludeImports as query param' {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match 'includeImports=true'
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            Get-InfisicalSecrets -IncludeImports | Out-Null
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
