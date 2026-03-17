using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'New-InfisicalClientSecret' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Generate client secret' {
        It 'Creates client secret and returns typed object' {
            Mock Invoke-RestMethod {
                return Get-SampleClientSecretResponse
            } -ModuleName PSInfisical

            $result = New-InfisicalClientSecret -IdentityId 'identity-001' -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames | Should -Contain 'InfisicalClientSecret'
            $result.Id | Should -Be 'cs-id-001'
            $result.ClientSecret | Should -Be 'cs-generated-secret-value'
            $result.Description | Should -Be 'Test secret'
            $result.ClientSecretPrefix | Should -Be 'cs-g'
            $result.IsRevoked | Should -Be $false
            $result.CreatedAt | Should -BeOfType [datetime]
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It 'Passes Description and TTL to body' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.description | Should -Be 'CI runner'
                $parsed.ttl | Should -Be 86400
                return Get-SampleClientSecretResponse
            } -ModuleName PSInfisical

            $result = New-InfisicalClientSecret -IdentityId 'identity-001' -Description 'CI runner' -TTL 86400 -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Always returns object without requiring -PassThru' {
            Mock Invoke-RestMethod {
                return Get-SampleClientSecretResponse
            } -ModuleName PSInfisical

            $result = New-InfisicalClientSecret -IdentityId 'identity-001' -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.ClientSecret | Should -Not -BeNullOrEmpty
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleClientSecretResponse } -ModuleName PSInfisical
            New-InfisicalClientSecret -IdentityId 'identity-001' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
