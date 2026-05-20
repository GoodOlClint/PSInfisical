using module ..\..\PSInfisical.psd1

# PSInfisical.Extension.Integration.Tests.ps1
# Integration tests for the SecretManagement vault extension.
# Runs against a live self-hosted Infisical instance via Docker Compose.
# Called by: Pester test runner (Invoke-Build Test-Integration).
# Dependencies: PSInfisical module, Microsoft.PowerShell.SecretManagement

BeforeAll {
    # SecretManagement is required for the extension module
    if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement)) {
        throw 'Microsoft.PowerShell.SecretManagement module is required. Install with: Install-Module Microsoft.PowerShell.SecretManagement -Force'
    }

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force
    Import-Module Microsoft.PowerShell.SecretManagement -Force

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

Describe 'SecretManagement Extension Integration Tests' -Tag 'Integration' {

    BeforeAll {
        # Generate a unique prefix for test secret isolation
        $script:testPrefix = "SMINT_$([guid]::NewGuid().ToString('N').Substring(0, 8).ToUpper())"
        $script:vaultName = "IntegrationTestVault_$($script:testPrefix)"

        # Register the vault for SecretManagement
        $vaultParams = @{
            ApiUrl       = $testUrl
            ClientId     = $clientId
            ClientSecret = $clientSecret
            ProjectId    = $projectId
            Environment  = 'dev'
            SecretPath   = '/'
        }

        Register-SecretVault `
            -Name $script:vaultName `
            -ModuleName (Resolve-Path $modulePath).Path `
            -VaultParameters $vaultParams
    }

    AfterAll {
        # Clean up test secrets via PSInfisical public API
        try {
            $secureSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
            Connect-Infisical `
                -ClientId $clientId `
                -ClientSecret $secureSecret `
                -ProjectId $projectId `
                -ApiUrl $testUrl `
                -Environment 'dev'

            $allSecrets = Get-InfisicalSecrets -ErrorAction SilentlyContinue
            if ($allSecrets) {
                $testSecrets = $allSecrets | Where-Object { $_.Name -like "$($script:testPrefix)*" }
                if ($testSecrets) {
                    $testSecrets | Remove-InfisicalSecret -Confirm:$false -ErrorAction SilentlyContinue
                }
            }

            Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "AfterAll cleanup failed: $($_.Exception.Message)"
        }

        # Unregister the vault
        Unregister-SecretVault -Name $script:vaultName -ErrorAction SilentlyContinue
    }

    Context 'Test-SecretVault' {

        It 'Returns $true for a valid vault' {
            $result = Test-SecretVault -Name $script:vaultName

            $result | Should -BeTrue
        }

        It 'Returns $false with invalid credentials' {
            $badVaultName = "BadVault_$($script:testPrefix)"
            $badParams = @{
                ApiUrl       = $testUrl
                ClientId     = 'invalid-client-id'
                ClientSecret = 'invalid-client-secret'
                ProjectId    = $projectId
                Environment  = 'dev'
            }

            # Register-SecretVault re-validates the module in its own runspace.
            # When the module is already loaded in the session, this can fail
            # with a cryptic error. Use -AllowClobber and ignore registration
            # errors — the actual test is Test-SecretVault, not registration.
            try {
                Register-SecretVault `
                    -Name $badVaultName `
                    -ModuleName (Resolve-Path $modulePath).Path `
                    -VaultParameters $badParams `
                    -AllowClobber
            }
            catch {
                # If registration fails (SecretManagement internal module loading),
                # skip this test as the vault couldn't be registered.
                Set-ItResult -Skipped -Because "Register-SecretVault failed: $($_.Exception.Message)"
                return
            }

            try {
                $result = Test-SecretVault -Name $badVaultName
                $result | Should -BeFalse
            }
            finally {
                Unregister-SecretVault -Name $badVaultName -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'CRUD Lifecycle via SecretManagement' {

        BeforeAll {
            $script:secretName = "$($script:testPrefix)_CRUD"
            $script:secretValue = "initial-value-$([guid]::NewGuid().ToString('N'))"
            $script:updatedValue = "updated-value-$([guid]::NewGuid().ToString('N'))"
        }

        It 'Set-Secret creates a new secret' {
            Set-Secret -Name $script:secretName -Secret $script:secretValue -Vault $script:vaultName

            # Verify via PSInfisical public API
            $secureSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
            Connect-Infisical `
                -ClientId $clientId `
                -ClientSecret $secureSecret `
                -ProjectId $projectId `
                -ApiUrl $testUrl `
                -Environment 'dev'

            $secret = Get-InfisicalSecret -Name $script:secretName
            $secret | Should -Not -BeNullOrEmpty
            $secret.GetValue() | Should -Be $script:secretValue
        }

        It 'Get-Secret retrieves the secret as SecureString' {
            $result = Get-Secret -Name $script:secretName -Vault $script:vaultName

            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [System.Security.SecureString]

            $plaintext = [System.Net.NetworkCredential]::new('', $result).Password
            $plaintext | Should -Be $script:secretValue
        }

        It 'Get-Secret -AsPlainText retrieves plaintext value' {
            $result = Get-Secret -Name $script:secretName -Vault $script:vaultName -AsPlainText

            $result | Should -Be $script:secretValue
        }

        It 'Set-Secret updates an existing secret' {
            Set-Secret -Name $script:secretName -Secret $script:updatedValue -Vault $script:vaultName

            $result = Get-Secret -Name $script:secretName -Vault $script:vaultName -AsPlainText
            $result | Should -Be $script:updatedValue
        }

        It 'Remove-Secret deletes the secret' {
            Remove-Secret -Name $script:secretName -Vault $script:vaultName

            # Verify the secret is gone
            $result = Get-Secret -Name $script:secretName -Vault $script:vaultName -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Get-SecretInfo' {

        BeforeAll {
            # Create several secrets for listing
            $script:listSecrets = @(
                "$($script:testPrefix)_LIST_A"
                "$($script:testPrefix)_LIST_B"
                "$($script:testPrefix)_LIST_C"
            )

            foreach ($name in $script:listSecrets) {
                Set-Secret -Name $name -Secret "value-for-$name" -Vault $script:vaultName
            }
        }

        It 'Returns SecretInformation objects including created secrets' {
            $result = @(Get-SecretInfo -Vault $script:vaultName)

            $result | Should -Not -BeNullOrEmpty
            foreach ($name in $script:listSecrets) {
                $match = $result | Where-Object { $_.Name -eq $name }
                $match | Should -Not -BeNullOrEmpty -Because "Expected to find secret '$name'"
            }
        }

        It 'Reports SecretType as String for plain-string payloads' {
            # As of v0.5.0 the extension records the original SecretType in
            # secret metadata so Get-Secret can rebuild the same shape. Set-Secret
            # with a plain string is therefore tagged as String, not SecureString.
            $result = @(Get-SecretInfo -Vault $script:vaultName)
            $testInfo = $result | Where-Object { $_.Name -eq $script:listSecrets[0] }

            $testInfo | Should -Not -BeNullOrEmpty
            $testInfo.Type | Should -Be ([Microsoft.PowerShell.SecretManagement.SecretType]::String)
        }

        It 'Reports SecretType as SecureString for SecureString payloads' {
            $secureName = "$($script:testPrefix)_SECURESTRING"
            $secureValue = ConvertTo-SecureString -String 'covered-by-securestring-tag' -AsPlainText -Force
            try {
                Set-Secret -Name $secureName -Secret $secureValue -Vault $script:vaultName

                $info = (Get-SecretInfo -Vault $script:vaultName) | Where-Object { $_.Name -eq $secureName }

                $info | Should -Not -BeNullOrEmpty
                $info.Type | Should -Be ([Microsoft.PowerShell.SecretManagement.SecretType]::SecureString)

                $roundTrip = Get-Secret -Name $secureName -Vault $script:vaultName
                $roundTrip | Should -BeOfType [System.Security.SecureString]
            }
            finally {
                Remove-Secret -Name $secureName -Vault $script:vaultName -ErrorAction SilentlyContinue
            }
        }

        It 'Reports correct VaultName' {
            $result = @(Get-SecretInfo -Vault $script:vaultName)
            $testInfo = $result | Where-Object { $_.Name -eq $script:listSecrets[0] }

            $testInfo.VaultName | Should -Be $script:vaultName
        }

        It 'Applies wildcard filter' {
            $result = @(Get-SecretInfo -Name "$($script:testPrefix)_LIST_*" -Vault $script:vaultName)

            $result.Count | Should -Be 3
            $result.Name | Should -Contain "$($script:testPrefix)_LIST_A"
            $result.Name | Should -Contain "$($script:testPrefix)_LIST_B"
            $result.Name | Should -Contain "$($script:testPrefix)_LIST_C"
        }

        AfterAll {
            # Clean up list test secrets
            foreach ($name in $script:listSecrets) {
                Remove-Secret -Name $name -Vault $script:vaultName -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Vault Registration Lifecycle' {

        It 'Registered vault is visible in Get-SecretVault' {
            $vault = Get-SecretVault -Name $script:vaultName -ErrorAction SilentlyContinue

            $vault | Should -Not -BeNullOrEmpty
            $vault.Name | Should -Be $script:vaultName
        }
    }
}

AfterAll {
    Remove-Module -Name 'PSInfisical.Extension' -Force -ErrorAction SilentlyContinue
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
