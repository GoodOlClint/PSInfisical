using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalEnvironment' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'List environments' {
        It 'Returns array of environment objects' {
            Mock Invoke-RestMethod {
                return Get-SampleEnvironmentsResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalEnvironment
            $results | Should -HaveCount 3
        }

        It 'Returns objects with correct properties' {
            Mock Invoke-RestMethod {
                return Get-SampleEnvironmentsResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalEnvironment
            $results[0].Slug | Should -Be 'dev'
            $results[1].Name | Should -Be 'Staging'
            $results[2].Position | Should -Be 3
        }

        It 'Objects have InfisicalEnvironment type name' {
            Mock Invoke-RestMethod {
                return Get-SampleEnvironmentsResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalEnvironment
            $results[0].PSTypeNames | Should -Contain 'InfisicalEnvironment'
        }
    }

    Context 'Empty results' {
        It 'Returns nothing when no environments exist' {
            Mock Invoke-RestMethod {
                return @{ environments = @() }
            } -ModuleName PSInfisical

            $results = @(Get-InfisicalEnvironment)
            $results | Should -HaveCount 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
