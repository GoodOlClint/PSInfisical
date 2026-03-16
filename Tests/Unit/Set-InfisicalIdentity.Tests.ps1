using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Set-InfisicalIdentity' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Update identity' {
        It 'Updates identity name' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentityResponse -Name 'renamed'
            } -ModuleName PSInfisical

            { Set-InfisicalIdentity -Id 'identity-001' -Name 'renamed' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns updated identity' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentityResponse -Name 'renamed'
            } -ModuleName PSInfisical

            $result = Set-InfisicalIdentity -Id 'identity-001' -Name 'renamed' -PassThru -Confirm:$false
            $result.GetType().Name | Should -Be 'InfisicalIdentity'
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleIdentityResponse } -ModuleName PSInfisical
            Set-InfisicalIdentity -Id 'identity-001' -Name 'test' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
