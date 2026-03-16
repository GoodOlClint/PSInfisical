using module ..\..\PSInfisical.psd1

# New-InfisicalFolder.Tests.ps1
# Unit tests for the New-InfisicalFolder function.
# Called by: Pester test runner.
# Dependencies: PSInfisical module, TestHelpers.ps1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'New-InfisicalFolder' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Create folder' {
        It 'Creates folder successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleFolderResponse -Name 'new-folder'
            } -ModuleName PSInfisical

            { New-InfisicalFolder -Name 'new-folder' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns created folder' {
            Mock Invoke-RestMethod {
                return Get-SampleFolderResponse -Name 'new-folder'
            } -ModuleName PSInfisical

            $result = New-InfisicalFolder -Name 'new-folder' -PassThru -Confirm:$false

            $result.GetType().Name | Should -Be 'InfisicalFolder'
            $result.Name | Should -Be 'new-folder'
        }

        It 'Passes Description to API body' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.description | Should -Be 'My description'
                return Get-SampleFolderResponse -Name 'described'
            } -ModuleName PSInfisical

            { New-InfisicalFolder -Name 'described' -Description 'My description' -Confirm:$false } | Should -Not -Throw
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod {
                return Get-SampleFolderResponse
            } -ModuleName PSInfisical

            New-InfisicalFolder -Name 'TEST' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
