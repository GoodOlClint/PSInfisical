using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Add-InfisicalIdentityAuth' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Attach Universal Auth' {
        It 'Attaches auth with defaults' {
            Mock Invoke-RestMethod {
                return @{ identityUniversalAuth = @{ accessTokenTTL = 2592000 } }
            } -ModuleName PSInfisical

            { Add-InfisicalIdentityAuth -IdentityId 'identity-001' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It 'Passes TTL settings to body' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.accessTokenTTL | Should -Be 3600
                return @{ identityUniversalAuth = @{} }
            } -ModuleName PSInfisical

            { Add-InfisicalIdentityAuth -IdentityId 'identity-001' -AccessTokenTTL 3600 -Confirm:$false } | Should -Not -Throw
        }

        It '-PassThru returns auth config' {
            Mock Invoke-RestMethod {
                return @{ identityUniversalAuth = @{ accessTokenTTL = 3600 } }
            } -ModuleName PSInfisical

            $result = Add-InfisicalIdentityAuth -IdentityId 'identity-001' -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return @{} } -ModuleName PSInfisical
            Add-InfisicalIdentityAuth -IdentityId 'identity-001' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
