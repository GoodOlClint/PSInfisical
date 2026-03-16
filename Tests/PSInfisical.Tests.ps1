using module ..\PSInfisical.psd1

# PSInfisical.Tests.ps1
# Module-level tests: verifies manifest, exports, help, and output type declarations.
# Called by: Pester test runner (InvokeBuild Test task).
# Dependencies: PSInfisical module

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..'
    Import-Module $modulePath -Force
}

Describe 'PSInfisical Module' {

    Context 'Module Import' {
        It 'Imports without error' {
            { Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..') -Force } | Should -Not -Throw
        }

        It 'Has a valid module manifest' {
            $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '../PSInfisical.psd1'
            { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Manifest version is 0.2.0' {
            $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '../PSInfisical.psd1'
            $manifest = Test-ModuleManifest -Path $manifestPath
            $manifest.Version.ToString() | Should -Be '0.2.0'
        }
    }

    Context 'Exported Functions' {
        BeforeAll {
            $expectedFunctions = @(
                'Connect-Infisical'
                'Disconnect-Infisical'
                'Get-InfisicalSecret'
                'Get-InfisicalSecrets'
                'New-InfisicalSecret'
                'Set-InfisicalSecret'
                'Remove-InfisicalSecret'
                'Get-InfisicalSecretVersion'
                'Get-InfisicalFolder'
                'New-InfisicalFolder'
                'Set-InfisicalFolder'
                'Remove-InfisicalFolder'
                'Get-InfisicalTag'
                'New-InfisicalTag'
                'Set-InfisicalTag'
                'Remove-InfisicalTag'
                'Get-InfisicalSecretImport'
                'New-InfisicalSecretImport'
                'Set-InfisicalSecretImport'
                'Remove-InfisicalSecretImport'
                'New-InfisicalSecretBulk'
                'Set-InfisicalSecretBulk'
                'Remove-InfisicalSecretBulk'
            )
            $module = Get-Module -Name PSInfisical
        }

        It 'Exports all expected public functions' {
            foreach ($func in $expectedFunctions) {
                $module.ExportedFunctions.Keys | Should -Contain $func
            }
        }

        It 'Exports exactly the expected number of functions' {
            $module.ExportedFunctions.Count | Should -Be $expectedFunctions.Count
        }

        It 'Does not export private functions' {
            $privateFunctions = @(
                'Invoke-InfisicalApi'
                'Get-InfisicalSession'
                'ConvertTo-InfisicalBody'
            )
            foreach ($func in $privateFunctions) {
                $module.ExportedFunctions.Keys | Should -Not -Contain $func
            }
        }
    }

    Context 'Comment-Based Help' {
        BeforeAll {
            $exportedFunctions = (Get-Module -Name PSInfisical).ExportedFunctions.Keys
        }

        It '<_> has comment-based help with Synopsis' -ForEach @(
            'Connect-Infisical'
            'Disconnect-Infisical'
            'Get-InfisicalSecret'
            'Get-InfisicalSecrets'
            'New-InfisicalSecret'
            'Set-InfisicalSecret'
            'Remove-InfisicalSecret'
            'Get-InfisicalSecretVersion'
            'Get-InfisicalFolder'
            'New-InfisicalFolder'
            'Set-InfisicalFolder'
            'Remove-InfisicalFolder'
            'Get-InfisicalTag'
            'New-InfisicalTag'
            'Set-InfisicalTag'
            'Remove-InfisicalTag'
            'Get-InfisicalSecretImport'
            'New-InfisicalSecretImport'
            'Set-InfisicalSecretImport'
            'Remove-InfisicalSecretImport'
            'New-InfisicalSecretBulk'
            'Set-InfisicalSecretBulk'
            'Remove-InfisicalSecretBulk'
        ) {
            $help = Get-Help $_
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It '<_> has at least one example' -ForEach @(
            'Connect-Infisical'
            'Disconnect-Infisical'
            'Get-InfisicalSecret'
            'Get-InfisicalSecrets'
            'New-InfisicalSecret'
            'Set-InfisicalSecret'
            'Remove-InfisicalSecret'
            'Get-InfisicalSecretVersion'
            'Get-InfisicalFolder'
            'New-InfisicalFolder'
            'Set-InfisicalFolder'
            'Remove-InfisicalFolder'
            'Get-InfisicalTag'
            'New-InfisicalTag'
            'Set-InfisicalTag'
            'Remove-InfisicalTag'
            'Get-InfisicalSecretImport'
            'New-InfisicalSecretImport'
            'Set-InfisicalSecretImport'
            'Remove-InfisicalSecretImport'
            'New-InfisicalSecretBulk'
            'Set-InfisicalSecretBulk'
            'Remove-InfisicalSecretBulk'
        ) {
            $help = Get-Help $_
            $help.examples.example.Count | Should -BeGreaterOrEqual 1
        }
    }

    Context 'OutputType Declarations' {
        It '<_> has an OutputType attribute' -ForEach @(
            'Connect-Infisical'
            'Disconnect-Infisical'
            'Get-InfisicalSecret'
            'Get-InfisicalSecrets'
            'New-InfisicalSecret'
            'Set-InfisicalSecret'
            'Remove-InfisicalSecret'
            'Get-InfisicalSecretVersion'
            'Get-InfisicalFolder'
            'New-InfisicalFolder'
            'Set-InfisicalFolder'
            'Remove-InfisicalFolder'
            'Get-InfisicalTag'
            'New-InfisicalTag'
            'Set-InfisicalTag'
            'Remove-InfisicalTag'
            'Get-InfisicalSecretImport'
            'New-InfisicalSecretImport'
            'Set-InfisicalSecretImport'
            'Remove-InfisicalSecretImport'
            'New-InfisicalSecretBulk'
            'Set-InfisicalSecretBulk'
            'Remove-InfisicalSecretBulk'
        ) {
            $cmd = Get-Command $_
            $cmd.OutputType | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
