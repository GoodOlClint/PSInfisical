using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Remove-InfisicalIdentity' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Remove by ID' {
        It 'Removes identity successfully' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentityResponse
            } -ModuleName PSInfisical

            { Remove-InfisicalIdentity -Id 'identity-001' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }
    }

    Context 'Identity not found' {
        It 'Writes non-terminating error if not found' {
            Mock Invoke-RestMethod { return $null } -ModuleName PSInfisical
            $result = Remove-InfisicalIdentity -Id 'nonexistent' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable errVar
            $errVar | Should -Not -BeNullOrEmpty
            $errVar[0].FullyQualifiedErrorId | Should -Match 'InfisicalIdentityNotFound'
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return Get-SampleIdentityResponse } -ModuleName PSInfisical
            Remove-InfisicalIdentity -Id 'identity-001' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }

    Context 'ConfirmImpact' {
        It 'Has ConfirmImpact set to High' {
            $cmd = Get-Command Remove-InfisicalIdentity
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High'
        }
    }

    Context 'Pipeline input' {
        It 'Accepts pipeline input from Get-InfisicalIdentity' {
            Mock Invoke-RestMethod {
                return Get-SampleIdentitiesListResponse
            } -ModuleName PSInfisical -ParameterFilter { $null -eq $Method -or $Method -eq 'GET' }

            Mock Invoke-RestMethod {
                return Get-SampleIdentityResponse
            } -ModuleName PSInfisical -ParameterFilter { $Method -eq 'DELETE' }

            { Get-InfisicalIdentity -OrganizationId 'org-123' | Remove-InfisicalIdentity -Confirm:$false } | Should -Not -Throw
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
