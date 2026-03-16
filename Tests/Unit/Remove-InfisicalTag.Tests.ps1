using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Remove-InfisicalTag' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Remove by ID' {
        It 'Removes tag successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleTagResponse
            } -ModuleName PSInfisical

            { Remove-InfisicalTag -Id 'tag-001' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }
    }

    Context 'Tag not found' {
        It 'Writes non-terminating error if not found' {
            Mock Invoke-RestMethod { return $null } -ModuleName PSInfisical

            $result = Remove-InfisicalTag -Id 'nonexistent' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable errVar
            $errVar | Should -Not -BeNullOrEmpty
            $errVar[0].FullyQualifiedErrorId | Should -Match 'InfisicalTagNotFound'
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleTagResponse } -ModuleName PSInfisical
            Remove-InfisicalTag -Id 'tag-001' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'ConfirmImpact' {
        It 'Has ConfirmImpact set to High' {
            $cmd = Get-Command Remove-InfisicalTag
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High'
        }
    }

    Context 'Pipeline input' {
        It 'Accepts pipeline input from Get-InfisicalTag' {
            Mock Invoke-RestMethod {
                return Get-SampleTagsListResponse
            } -ModuleName PSInfisical -ParameterFilter { $null -eq $Method -or $Method -eq 'GET' }

            Mock Invoke-RestMethod {
                return Get-SampleTagResponse
            } -ModuleName PSInfisical -ParameterFilter { $Method -eq 'DELETE' }

            { Get-InfisicalTag | Remove-InfisicalTag -Confirm:$false } | Should -Not -Throw
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
