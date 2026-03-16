using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'New-InfisicalIdentity' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Create identity' {
        It 'Creates identity successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentityResponse -Name 'new-agent'
            } -ModuleName PSInfisical

            { New-InfisicalIdentity -Name 'new-agent' -OrganizationId 'org-123' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns created identity' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentityResponse -Name 'new-agent'
            } -ModuleName PSInfisical

            $result = New-InfisicalIdentity -Name 'new-agent' -OrganizationId 'org-123' -PassThru -Confirm:$false
            $result.GetType().Name | Should -Be 'InfisicalIdentity'
            $result.Name | Should -Be 'new-agent'
        }

        It 'Passes Role and Metadata to body' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                $parsed = $Body | ConvertFrom-Json
                $parsed.role | Should -Be 'admin'
                $parsed.metadata | Should -Not -BeNullOrEmpty
                return Get-SampleIdentityResponse
            } -ModuleName PSInfisical

            { New-InfisicalIdentity -Name 'admin-agent' -OrganizationId 'org-123' -Role 'admin' -Metadata @{ team = 'ops' } -Confirm:$false } | Should -Not -Throw
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleIdentityResponse } -ModuleName PSInfisical
            New-InfisicalIdentity -Name 'test' -OrganizationId 'org-123' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
