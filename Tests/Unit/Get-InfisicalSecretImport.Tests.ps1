using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalSecretImport' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'List secret imports' {
        It 'Returns array of InfisicalSecretImport objects' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretImportsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalSecretImport
            $results | Should -HaveCount 2
            $results[0].GetType().Name | Should -Be 'InfisicalSecretImport'
        }

        It 'Maps source environment and path correctly' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretImportsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalSecretImport
            $results[0].SourceEnvironment | Should -Be 'prod'
            $results[0].SourcePath | Should -Be '/shared'
            $results[1].SourceEnvironment | Should -Be 'staging'
            $results[1].IsReplication | Should -BeTrue
        }
    }

    Context 'Empty results' {
        It 'Returns nothing when no imports exist' {
            Mock Invoke-RestMethod {
                return @{ secretImports = @() }
            } -ModuleName PSInfisical

            $results = @(Get-InfisicalSecretImport)
            $results | Should -HaveCount 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
