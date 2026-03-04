using module ..\..\PSInfisical.psd1

# Secrets.Integration.Tests.ps1
# Full CRUD lifecycle integration tests for Infisical secrets.
# Runs against a live self-hosted Infisical instance.
# Called by: Pester test runner (Invoke-Build Test-Integration).

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')

    $testUrl = $env:INFISICAL_TEST_URL
    $projectId = $env:INFISICAL_TEST_PROJECT_ID
    $clientId = $env:INFISICAL_TEST_CLIENT_ID
    $clientSecret = $env:INFISICAL_TEST_CLIENT_SECRET

    if (-not $testUrl -or -not $projectId -or -not $clientId -or -not $clientSecret) {
        throw @"
Integration test environment variables are not set. Ensure the following are defined:
  INFISICAL_TEST_URL, INFISICAL_TEST_PROJECT_ID,
  INFISICAL_TEST_CLIENT_ID, INFISICAL_TEST_CLIENT_SECRET

Run Start-IntegrationEnvironment.ps1 to bootstrap the environment.
"@
    }
}

Describe 'Secrets CRUD Integration Tests' -Tag 'Integration' {

    BeforeAll {
        # Connect with UniversalAuth
        $secureSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
        Connect-Infisical `
            -ClientId $clientId `
            -ClientSecret $secureSecret `
            -ProjectId $projectId `
            -ApiUrl $testUrl `
            -Environment 'dev'

        # Generate a unique prefix to isolate test secrets from any real data.
        # All secret names start with this prefix for reliable cleanup.
        $script:testPrefix = "INTTEST_$([guid]::NewGuid().ToString('N').Substring(0, 8).ToUpper())"
        $script:secretName = "$($script:testPrefix)_SECRET"
        $script:secretValue = "initial-value-$([guid]::NewGuid().ToString('N'))"
        $script:updatedValue = "updated-value-$([guid]::NewGuid().ToString('N'))"
    }

    AfterAll {
        # Clean up ALL secrets with our test prefix, regardless of test outcome
        try {
            $allSecrets = Get-InfisicalSecrets -ErrorAction SilentlyContinue
            if ($allSecrets) {
                $testSecrets = $allSecrets | Where-Object { $_.Name -like "$($script:testPrefix)*" }
                if ($testSecrets) {
                    $testSecrets | Remove-InfisicalSecret -Confirm:$false -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            Write-Warning "AfterAll cleanup failed: $($_.Exception.Message)"
        }

        Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    }

    Context 'New-InfisicalSecret' {

        It 'Creates a secret and returns it with -PassThru' {
            $secureValue = ConvertTo-SecureString -String $script:secretValue -AsPlainText -Force

            $created = New-InfisicalSecret `
                -Name $script:secretName `
                -Value $secureValue `
                -PassThru

            $created | Should -Not -BeNullOrEmpty
            $created.Name | Should -Be $script:secretName
            $created.GetValue() | Should -Be $script:secretValue
            $created.Version | Should -Be 1
        }
    }

    Context 'Get-InfisicalSecret' {

        It 'Retrieves the secret by name and returns an InfisicalSecret object' {
            $secret = Get-InfisicalSecret -Name $script:secretName

            $secret | Should -Not -BeNullOrEmpty
            $secret.Name | Should -Be $script:secretName
            $secret.Value | Should -BeOfType [System.Security.SecureString]
        }

        It 'Returns a SecureString value by default' {
            $secret = Get-InfisicalSecret -Name $script:secretName

            $secret.Value | Should -BeOfType [System.Security.SecureString]
            # Verify the SecureString actually contains the correct value
            $plainText = [System.Net.NetworkCredential]::new('', $secret.Value).Password
            $plainText | Should -Be $script:secretValue
        }

        It 'Returns plaintext with -Raw' {
            $raw = Get-InfisicalSecret -Name $script:secretName -Raw

            $raw | Should -BeOfType [string]
            $raw | Should -Be $script:secretValue
        }
    }

    Context 'Get-InfisicalSecrets' {

        It 'Returns all secrets including the created one' {
            $allSecrets = Get-InfisicalSecrets

            $allSecrets | Should -Not -BeNullOrEmpty
            $match = $allSecrets | Where-Object { $_.Name -eq $script:secretName }
            $match | Should -Not -BeNullOrEmpty
            $match.Name | Should -Be $script:secretName
        }
    }

    Context 'Set-InfisicalSecret' {

        It 'Updates the secret value' {
            $secureUpdated = ConvertTo-SecureString -String $script:updatedValue -AsPlainText -Force

            Set-InfisicalSecret -Name $script:secretName -Value $secureUpdated

            # Verify the update
            $updated = Get-InfisicalSecret -Name $script:secretName -Raw
            $updated | Should -Be $script:updatedValue
        }
    }

    Context 'Get-InfisicalSecretVersion' {

        It 'Returns at least 2 versions after the update' {
            $versions = Get-InfisicalSecretVersion -Name $script:secretName

            $versions | Should -Not -BeNullOrEmpty
            @($versions).Count | Should -BeGreaterOrEqual 2

            # Most recent version should have the updated value
            $latest = @($versions) | Sort-Object -Property Version -Descending | Select-Object -First 1
            $latestPlainText = [System.Net.NetworkCredential]::new('', $latest.Value).Password
            $latestPlainText | Should -Be $script:updatedValue
        }

        It 'Returns versions in descending order' {
            $versions = @(Get-InfisicalSecretVersion -Name $script:secretName)

            for ($i = 0; $i -lt ($versions.Count - 1); $i++) {
                $versions[$i].Version | Should -BeGreaterThan $versions[$i + 1].Version
            }
        }
    }

    Context 'Remove-InfisicalSecret' {

        It 'Deletes the secret' {
            Remove-InfisicalSecret -Name $script:secretName -Confirm:$false

            $deleted = Get-InfisicalSecret -Name $script:secretName -ErrorAction SilentlyContinue
            $deleted | Should -BeNullOrEmpty
        }
    }

    Context 'Pipeline: Get-InfisicalSecrets | Remove-InfisicalSecret' {

        BeforeAll {
            # Create multiple secrets for pipeline testing
            $script:pipelineSecrets = @(
                "$($script:testPrefix)_PIPE_A"
                "$($script:testPrefix)_PIPE_B"
                "$($script:testPrefix)_PIPE_C"
            )

            foreach ($name in $script:pipelineSecrets) {
                $secureVal = ConvertTo-SecureString -String "pipeline-value-$name" -AsPlainText -Force
                New-InfisicalSecret -Name $name -Value $secureVal
            }
        }

        It 'Pipes Get-InfisicalSecrets output to Remove-InfisicalSecret to delete all' {
            # Filter to only our pipeline test secrets and pipe to Remove
            Get-InfisicalSecrets `
                | Where-Object { $_.Name -like "$($script:testPrefix)_PIPE_*" } `
                | Remove-InfisicalSecret -Confirm:$false

            # Verify all are gone
            $remaining = Get-InfisicalSecrets -ErrorAction SilentlyContinue
            $pipeRemaining = $null
            if ($remaining) {
                $pipeRemaining = $remaining | Where-Object { $_.Name -like "$($script:testPrefix)_PIPE_*" }
            }
            $pipeRemaining | Should -BeNullOrEmpty
        }
    }
}

AfterAll {
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
