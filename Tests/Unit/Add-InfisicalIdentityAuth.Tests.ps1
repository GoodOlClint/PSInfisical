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
                return Get-SampleIdentityAuthResponse
            } -ModuleName PSInfisical

            { Add-InfisicalIdentityAuth -IdentityId 'identity-001' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It 'Passes TTL settings to body' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.accessTokenTTL | Should -Be 3600
                return Get-SampleIdentityAuthResponse
            } -ModuleName PSInfisical

            { Add-InfisicalIdentityAuth -IdentityId 'identity-001' -AccessTokenTTL 3600 -Confirm:$false } | Should -Not -Throw
        }

        It '-PassThru returns typed InfisicalIdentityAuth object' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentityAuthResponse
            } -ModuleName PSInfisical

            $result = Add-InfisicalIdentityAuth -IdentityId 'identity-001' -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames | Should -Contain 'InfisicalIdentityAuth'
            $result.Id | Should -Be 'auth-config-001'
            $result.IdentityId | Should -Be 'identity-001'
            $result.AuthMethod | Should -Be 'universal-auth'
            $result.ClientId | Should -Be 'client-id-001'
            $result.AccessTokenTTL | Should -Be 2592000
            $result.AccessTokenMaxTTL | Should -Be 2592000
            $result.AccessTokenNumUsesLimit | Should -Be 0
        }

        It '-PassThru returns correct auth method for non-universal auth' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentityAuthResponse -AuthMethod 'aws-auth'
            } -ModuleName PSInfisical

            $result = Add-InfisicalIdentityAuth -IdentityId 'identity-001' -AuthMethod 'aws-auth' -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.AuthMethod | Should -Be 'aws-auth'
        }

        It 'Returns nothing without -PassThru' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentityAuthResponse
            } -ModuleName PSInfisical

            $result = Add-InfisicalIdentityAuth -IdentityId 'identity-001' -Confirm:$false
            $result | Should -BeNullOrEmpty
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
