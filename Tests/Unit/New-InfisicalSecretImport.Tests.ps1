using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'New-InfisicalSecretImport' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Create secret import' {
        It 'Creates import successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretImportResponse
            } -ModuleName PSInfisical

            { New-InfisicalSecretImport -SourceEnvironment 'prod' -SourcePath '/shared' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns created import' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretImportResponse
            } -ModuleName PSInfisical

            $result = New-InfisicalSecretImport -SourceEnvironment 'prod' -SourcePath '/shared' -PassThru -Confirm:$false
            $result.GetType().Name | Should -Be 'InfisicalSecretImport'
            $result.SourcePath | Should -Be '/shared'
        }

        It 'Passes IsReplication to body' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.isReplication | Should -BeTrue
                return Get-SampleSecretImportResponse
            } -ModuleName PSInfisical

            { New-InfisicalSecretImport -SourceEnvironment 'prod' -SourcePath '/' -IsReplication -Confirm:$false } | Should -Not -Throw
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleSecretImportResponse } -ModuleName PSInfisical
            New-InfisicalSecretImport -SourceEnvironment 'prod' -SourcePath '/' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
