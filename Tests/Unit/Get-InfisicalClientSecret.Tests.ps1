using module ..\..\PSInfisical.psd1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalClientSecret' {

    BeforeAll {
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'List client secrets' {
        It 'Returns client secret metadata' {
            Mock Invoke-RestMethod {
                return Get-SampleClientSecretsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalClientSecret -IdentityId 'identity-001'
            $results | Should -HaveCount 2
            $results[0].PSTypeNames | Should -Contain 'InfisicalClientSecret'
        }

        It 'Maps IsActive from revocation status' {
            Mock Invoke-RestMethod {
                return Get-SampleClientSecretsListResponse
            } -ModuleName PSInfisical

            $results = Get-InfisicalClientSecret -IdentityId 'identity-001'
            $results[0].IsActive | Should -BeTrue
            $results[0].Description | Should -Be 'CI runner'
            $results[1].IsActive | Should -BeFalse
        }
    }

    Context 'Empty results' {
        It 'Returns nothing when no client secrets exist' {
            Mock Invoke-RestMethod { return @{ clientSecretData = @() } } -ModuleName PSInfisical
            $results = @(Get-InfisicalClientSecret -IdentityId 'identity-001')
            $results | Should -HaveCount 0
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
