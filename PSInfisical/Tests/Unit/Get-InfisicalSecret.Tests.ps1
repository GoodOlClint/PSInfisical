using module ..\..\PSInfisical.psd1

# Get-InfisicalSecret.Tests.ps1
# Unit tests for the Get-InfisicalSecret function.
# Called by: Pester test runner.
# Dependencies: PSInfisical module, TestHelpers.ps1

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'Get-InfisicalSecret' {

    BeforeAll {
        # Set up a mock session for all tests
        $mockSession = New-MockSession
        & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
    }

    Context 'Successful retrieval' {
        It 'Returns an InfisicalSecret object with correct properties' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'DATABASE_URL' -Value 'postgres://localhost/db'
            } -ModuleName PSInfisical

            $result = Get-InfisicalSecret -Name 'DATABASE_URL'

            $result | Should -Not -BeNullOrEmpty
            $result.GetType().Name | Should -Be 'InfisicalSecret' # type check
            $result.Name | Should -Be 'DATABASE_URL'
            $result.Version | Should -Be 1
            $result.Comment | Should -Be 'Test comment'
            $result.Id | Should -Be 'sec-abc-123'
        }

        It 'Stores the value as SecureString' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'MY_SECRET' -Value 'super-secret'
            } -ModuleName PSInfisical

            $result = Get-InfisicalSecret -Name 'MY_SECRET'

            $result.Value | Should -BeOfType [System.Security.SecureString]
            $result.GetValue() | Should -Be 'super-secret'
        }

        It '-Raw returns plain string value' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'API_KEY' -Value 'sk-test-key'
            } -ModuleName PSInfisical

            $result = Get-InfisicalSecret -Name 'API_KEY' -Raw

            $result | Should -BeOfType [string]
            $result | Should -Be 'sk-test-key'
        }
    }

    Context 'Secret not found' {
        It 'Writes non-terminating error when secret not found (404)' {
            Mock Invoke-RestMethod {
                # Simulate 404 by returning null (Invoke-InfisicalApi returns $null on 404)
                return $null
            } -ModuleName PSInfisical

            $result = Get-InfisicalSecret -Name 'NONEXISTENT' -ErrorAction SilentlyContinue -ErrorVariable errVar

            $result | Should -BeNullOrEmpty
            $errVar | Should -Not -BeNullOrEmpty
            $errVar[0].FullyQualifiedErrorId | Should -Match 'InfisicalSecretNotFound'
        }
    }

    Context 'Not connected' {
        It 'Throws terminating error when not connected' {
            & (Get-Module PSInfisical) { $script:InfisicalSession = $null }

            { Get-InfisicalSecret -Name 'TEST' -ErrorAction Stop } |
                Should -Throw '*Not connected to Infisical*'

            # Restore session
            & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $mockSession
        }
    }

    Context 'Parameter handling' {
        It 'Passes Environment and SecretPath to API correctly' {
            Mock Invoke-RestMethod {
                param($Uri)
                # Verify the URI contains expected query parameters
                $Uri | Should -Match 'environment=staging'
                $Uri | Should -Match 'secretPath=%2Fmypath'
                return Get-SampleSecretResponse
            } -ModuleName PSInfisical

            Get-InfisicalSecret -Name 'TEST' -Environment 'staging' -SecretPath '/mypath'

            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It 'Does not log secret value in Verbose output' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'SECRET' -Value 'do-not-log-this'
            } -ModuleName PSInfisical

            $verboseOutput = Get-InfisicalSecret -Name 'SECRET' -Verbose 4>&1

            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Message -join ' '
            $verboseText | Should -Not -Match 'do-not-log-this'
        }
    }
}

AfterAll {
    Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
