using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalIdentityAuth' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Get auth config' {
        It 'Returns auth configuration' {
            Mock Invoke-RestMethod {
                return @{ identityUniversalAuth = @{ accessTokenTTL = 2592000; accessTokenMaxTTL = 2592000 } }
            } -ModuleName PSInfisical

            $result = Get-InfisicalIdentityAuth -IdentityId 'identity-001'
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Auth not configured' {
        It 'Writes non-terminating error if not found' {
            Mock Invoke-RestMethod { return $null } -ModuleName PSInfisical

            $result = Get-InfisicalIdentityAuth -IdentityId 'identity-001' -ErrorAction SilentlyContinue -ErrorVariable errVar
            $result | Should -BeNullOrEmpty
            $errVar[0].FullyQualifiedErrorId | Should -Match 'InfisicalIdentityAuthNotFound'
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
