using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Set-InfisicalProjectMember' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Update role' {
        It 'Updates member role successfully' {
            Mock Invoke-RestMethod {
                return @{ identityMembership = @{ role = 'admin' } }
            } -ModuleName PSInfisical

            { Set-InfisicalProjectMember -IdentityId 'identity-001' -Role 'admin' -Confirm:$false } | Should -Not -Throw
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }
    }

    Context 'Pipeline input' {
        It 'Accepts pipeline input from Get-InfisicalProjectMember' {
            Mock Invoke-RestMethod {
                return Get-SampleProjectMembersResponse
            } -ModuleName PSInfisical -ParameterFilter { $null -eq $Method -or $Method -eq 'GET' }

            Mock Invoke-RestMethod {
                return @{ identityMembership = @{ role = 'viewer' } }
            } -ModuleName PSInfisical -ParameterFilter { $Method -eq 'PATCH' }

            { Get-InfisicalProjectMember | Set-InfisicalProjectMember -Role 'viewer' -Confirm:$false } | Should -Not -Throw
        }
    }

    Context '-WhatIf' {
        It 'Does not call API with -WhatIf' {
            Mock Invoke-RestMethod { return @{} } -ModuleName PSInfisical
            Set-InfisicalProjectMember -IdentityId 'identity-001' -Role 'viewer' -WhatIf
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
