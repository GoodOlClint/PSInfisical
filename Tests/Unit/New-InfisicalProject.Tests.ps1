using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'New-InfisicalProject' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Create project' {
        It 'Creates project successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectResponse
            } -ModuleName PSInfisical

            { New-InfisicalProject -Name 'my-app' -OrganizationId 'org-123' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns created project' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectResponse
            } -ModuleName PSInfisical

            $result = New-InfisicalProject -Name 'my-app' -OrganizationId 'org-123' -PassThru -Confirm:$false
            $result.PSTypeNames | Should -Contain 'InfisicalProject'
            $result.Name | Should -Be 'My Project'
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleProjectResponse } -ModuleName PSInfisical
            New-InfisicalProject -Name 'test' -OrganizationId 'org-123' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
