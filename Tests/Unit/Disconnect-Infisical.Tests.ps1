using module ..\..\PSInfisical.psd1

# Disconnect-Infisical.Tests.ps1
# Unit tests for the Disconnect-Infisical function.
# Called by: Pester test runner.
# Dependencies: PSInfisical module, TestHelpers.ps1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Disconnect-Infisical' {

    BeforeAll {
        Mock Test-InfisicalApiCapability {
            return @{ SecretsV4 = $true; SecretsV3 = $true }
        } -ModuleName PSInfisical
    }

    Context 'With active session' {
        BeforeEach {
            $token = New-TestSecureString -PlainText 'test-token'
            Connect-Infisical -Token $token -ProjectId 'proj-123'
        }

        It 'Clears the session' {
            Disconnect-Infisical -Confirm:$false

            { Get-InfisicalSecret -Name 'TEST' -ErrorAction Stop } |
                Should -Throw '*Not connected to Infisical*'
        }

        It 'Supports -WhatIf without clearing session' {
            Disconnect-Infisical -WhatIf

            # Session should still be active after -WhatIf
            $session = Connect-Infisical -Token (New-TestSecureString -PlainText 'test') -ProjectId 'proj-123' -PassThru
            $session | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Without active session' {
        It 'Does not throw when no session exists' {
            Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue

            { Disconnect-Infisical -Confirm:$false } | Should -Not -Throw
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
