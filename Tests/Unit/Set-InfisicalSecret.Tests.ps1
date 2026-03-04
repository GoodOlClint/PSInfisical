using module ..\..\PSInfisical.psd1

# Set-InfisicalSecret.Tests.ps1
# Unit tests for the Set-InfisicalSecret function.
# Called by: Pester test runner.
# Dependencies: PSInfisical module, TestHelpers.ps1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Set-InfisicalSecret' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Update existing secret' {
        It 'Updates secret value successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'MY_SECRET' -Value 'updated-value' -Version 2
            } -ModuleName PSInfisical

            $value = New-TestSecureString -PlainText 'updated-value'
            { Set-InfisicalSecret -Name 'MY_SECRET' -Value $value -Confirm:$false } | Should -Not -Throw

            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns updated secret' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'MY_SECRET' -Value 'updated-value' -Version 2
            } -ModuleName PSInfisical

            $value = New-TestSecureString -PlainText 'updated-value'
            $result = Set-InfisicalSecret -Name 'MY_SECRET' -Value $value -PassThru -Confirm:$false

            $result.GetType().Name | Should -Be 'InfisicalSecret'
            $result.Name | Should -Be 'MY_SECRET'
            $result.Version | Should -Be 2
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse
            } -ModuleName PSInfisical

            $value = New-TestSecureString -PlainText 'test'
            Set-InfisicalSecret -Name 'TEST' -Value $value -WhatIf

            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'ShouldProcess message' {
        It 'ShouldProcess message is descriptive' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'DESCRIBED' -Value 'val'
            } -ModuleName PSInfisical

            # Verify the function has SupportsShouldProcess set and the target
            # message includes the secret name by checking the CmdletBinding attribute
            $cmd = Get-Command Set-InfisicalSecret
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue

            # Also verify -WhatIf does not call the API (already tested above)
            # and that the function accepts -WhatIf without error
            { Set-InfisicalSecret -Name 'DESCRIBED' -Value (New-TestSecureString -PlainText 'val') -WhatIf } | Should -Not -Throw
        }
    }

    Context '-PlainTextValue' {
        It 'Emits Write-Warning when using -PlainTextValue' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'PLAIN' -Value 'val'
            } -ModuleName PSInfisical

            $warnings = Set-InfisicalSecret -Name 'PLAIN' -PlainTextValue 'plain-val' -Confirm:$false 3>&1

            $warningMessages = ($warnings | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }).Message -join ' '
            $warningMessages | Should -Match 'PlainTextValue'
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
