using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'New-InfisicalEnvironment' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Create environment' {
        It 'Creates environment successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleEnvironmentResponse
            } -ModuleName PSInfisical

            { New-InfisicalEnvironment -Name 'Staging' -Slug 'staging' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns created environment' {
            Mock Invoke-RestMethod {
                return Get-SampleEnvironmentResponse -Slug 'staging'
            } -ModuleName PSInfisical

            $result = New-InfisicalEnvironment -Name 'Staging' -Slug 'staging' -PassThru -Confirm:$false
            $result.PSTypeNames | Should -Contain 'InfisicalEnvironment'
            $result.Slug | Should -Be 'staging'
        }

        It 'Passes Position to body' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.position | Should -Be 3
                return Get-SampleEnvironmentResponse
            } -ModuleName PSInfisical

            { New-InfisicalEnvironment -Name 'QA' -Slug 'qa' -Position 3 -Confirm:$false } | Should -Not -Throw
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleEnvironmentResponse } -ModuleName PSInfisical
            New-InfisicalEnvironment -Name 'Test' -Slug 'test' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
