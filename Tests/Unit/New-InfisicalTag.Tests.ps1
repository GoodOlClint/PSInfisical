using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'New-InfisicalTag' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Create tag' {
        It 'Creates tag successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleTagResponse -Slug 'new-tag' -Color '#00FF00'
            } -ModuleName PSInfisical

            { New-InfisicalTag -Slug 'new-tag' -Color '#00FF00' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It '-PassThru returns created tag' {
            Mock Invoke-RestMethod {
                return Get-SampleTagResponse -Slug 'new-tag' -Color '#00FF00'
            } -ModuleName PSInfisical

            $result = New-InfisicalTag -Slug 'new-tag' -Color '#00FF00' -PassThru -Confirm:$false
            $result.GetType().Name | Should -Be 'InfisicalTag'
            $result.Slug | Should -Be 'new-tag'
            $result.Color | Should -Be '#00FF00'
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleTagResponse } -ModuleName PSInfisical
            New-InfisicalTag -Slug 'test' -Color '#000' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
