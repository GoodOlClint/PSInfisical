using module ..\..\PSInfisical.psd1

# PSInfisical.Extension.Tests.ps1
# Unit tests for the SecretManagement vault extension functions.
# Called by: Pester test runner.
# Dependencies: PSInfisical module, Microsoft.PowerShell.SecretManagement, TestHelpers.ps1

BeforeAll {
    # SecretManagement is required for the extension module
    if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement)) {
        throw 'Microsoft.PowerShell.SecretManagement module is required. Install with: Install-Module Microsoft.PowerShell.SecretManagement -Force'
    }

    Import-Module Microsoft.PowerShell.SecretManagement -Force

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../..'
    Import-Module $modulePath -Force

    $extensionPath = Join-Path -Path $PSScriptRoot -ChildPath '../../PSInfisical.Extension/PSInfisical.Extension.psd1'
    Import-Module $extensionPath -Force

    . (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers.ps1')
}

Describe 'PSInfisical.Extension' {

    BeforeAll {
        # Standard vault parameters used across tests
        $script:vaultParams = @{
            ApiUrl       = 'https://app.infisical.com'
            ClientId     = 'test-client-id'
            ClientSecret = 'test-client-secret'
            ProjectId    = 'test-project-id'
            Environment  = 'dev'
            SecretPath   = '/'
        }
        $script:vaultName = 'TestVault'
    }

    BeforeEach {
        # Clear session cache and module session before each test.
        # Use InModuleScope — the combination of 'using module' and Pester 5
        # scope isolation prevents '& (Get-Module ...)' from working reliably.
        InModuleScope PSInfisical.Extension { $script:SessionCache = @{} }
        InModuleScope PSInfisical { $script:InfisicalSession = $null }
    }

    Context 'Test-SecretVault' {

        It 'Returns $true when vault is accessible' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -match 'universal-auth/login') {
                    return Get-SampleAuthResponse
                }
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $result = Test-SecretVault -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            $result | Should -BeTrue
        }

        It 'Returns $false when authentication fails' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('401 Unauthorized')
            } -ModuleName PSInfisical

            $result = Test-SecretVault -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            $result | Should -BeFalse
        }

        It 'Returns $false when ProjectId is missing from VaultParameters' {
            $badParams = @{
                ClientId     = 'test-client-id'
                ClientSecret = 'test-client-secret'
            }

            $result = Test-SecretVault -VaultName $script:vaultName -AdditionalParameters $badParams

            $result | Should -BeFalse
        }

        It 'Returns $false when no auth credentials are provided' {
            $badParams = @{
                ProjectId = 'test-project-id'
            }

            $result = Test-SecretVault -VaultName $script:vaultName -AdditionalParameters $badParams

            $result | Should -BeFalse
        }
    }

    Context 'Get-Secret' {

        BeforeEach {
            # Pre-populate session cache to avoid auth round-trip in secret tests
            $mockSession = New-MockSession
            InModuleScope PSInfisical.Extension -Parameters @{ name = $script:vaultName; s = $mockSession } {
                param($name, $s)
                $script:SessionCache[$name] = $s
            }
            InModuleScope PSInfisical -Parameters @{ s = $mockSession } {
                param($s)
                $script:InfisicalSession = $s
            }
        }

        It 'Returns SecureString for existing secret' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'DATABASE_URL' -Value 'postgres://localhost/db'
            } -ModuleName PSInfisical

            $result = Get-Secret -Name 'DATABASE_URL' -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            $result | Should -BeOfType [System.Security.SecureString]
            $plaintext = [System.Net.NetworkCredential]::new('', $result).Password
            $plaintext | Should -Be 'postgres://localhost/db'
        }

        It 'Returns $null for non-existent secret' {
            Mock Invoke-RestMethod {
                return $null
            } -ModuleName PSInfisical

            # Get-InfisicalSecret writes a non-terminating error on null, suppress it
            $result = Get-Secret -Name 'NONEXISTENT' -VaultName $script:vaultName -AdditionalParameters $script:vaultParams -ErrorAction SilentlyContinue

            $result | Should -BeNullOrEmpty
        }

        It 'Uses SecretPath from VaultParameters' {
            $paramsWithPath = $script:vaultParams.Clone()
            $paramsWithPath['SecretPath'] = '/database'

            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match 'secretPath=%2Fdatabase'
                return Get-SampleSecretResponse -Name 'DB_HOST' -Value 'localhost'
            } -ModuleName PSInfisical

            $result = Get-Secret -Name 'DB_HOST' -VaultName $script:vaultName -AdditionalParameters $paramsWithPath

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }
    }

    Context 'Set-Secret' {

        BeforeEach {
            $mockSession = New-MockSession
            InModuleScope PSInfisical.Extension -Parameters @{ name = $script:vaultName; s = $mockSession } {
                param($name, $s)
                $script:SessionCache[$name] = $s
            }
            InModuleScope PSInfisical -Parameters @{ s = $mockSession } {
                param($s)
                $script:InfisicalSession = $s
            }
        }

        It 'Creates a new secret when it does not exist' {
            $callCount = 0
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                $callCount++
                if ($Method -eq 'GET') {
                    # Secret not found
                    return $null
                }
                if ($Method -eq 'POST') {
                    return Get-SampleSecretResponse -Name 'NEW_KEY' -Value 'new-value'
                }
                return $null
            } -ModuleName PSInfisical

            $result = Set-Secret -Name 'NEW_KEY' -Secret 'new-value' -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            $result | Should -BeTrue
            # Should have called GET (to check existence) then POST (to create)
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 2 -Exactly
        }

        It 'Updates an existing secret' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'GET') {
                    return Get-SampleSecretResponse -Name 'EXISTING_KEY' -Value 'old-value'
                }
                if ($Method -eq 'PATCH') {
                    return Get-SampleSecretResponse -Name 'EXISTING_KEY' -Value 'updated-value'
                }
                return $null
            } -ModuleName PSInfisical

            $result = Set-Secret -Name 'EXISTING_KEY' -Secret 'updated-value' -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            $result | Should -BeTrue
            # Should have called GET (to check existence) then PATCH (to update)
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 2 -Exactly
        }

        It 'Accepts SecureString input' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'GET') {
                    return $null
                }
                return Get-SampleSecretResponse -Name 'SECURE_KEY' -Value 'secure-val'
            } -ModuleName PSInfisical

            $secureValue = New-TestSecureString -PlainText 'secure-val'

            $result = Set-Secret -Name 'SECURE_KEY' -Secret $secureValue -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            $result | Should -BeTrue
        }

        It 'Accepts plain string input' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'GET') {
                    return $null
                }
                return Get-SampleSecretResponse -Name 'PLAIN_KEY' -Value 'plain-val'
            } -ModuleName PSInfisical

            $result = Set-Secret -Name 'PLAIN_KEY' -Secret 'plain-val' -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            $result | Should -BeTrue
        }
    }

    Context 'Remove-Secret' {

        BeforeEach {
            $mockSession = New-MockSession
            InModuleScope PSInfisical.Extension -Parameters @{ name = $script:vaultName; s = $mockSession } {
                param($name, $s)
                $script:SessionCache[$name] = $s
            }
            InModuleScope PSInfisical -Parameters @{ s = $mockSession } {
                param($s)
                $script:InfisicalSession = $s
            }
        }

        It 'Removes an existing secret and returns $true' {
            Mock Invoke-RestMethod {
                return @{ secret = @{ secretKey = 'OLD_KEY' } }
            } -ModuleName PSInfisical

            $result = Remove-Secret -Name 'OLD_KEY' -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            $result | Should -BeTrue
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1 -Exactly
        }

        It 'Throws when secret does not exist' {
            Mock Invoke-RestMethod {
                return $null
            } -ModuleName PSInfisical

            # Remove-InfisicalSecret writes an error when the API returns null
            { Remove-Secret -Name 'NONEXISTENT' -VaultName $script:vaultName -AdditionalParameters $script:vaultParams -ErrorAction Stop } |
                Should -Throw
        }
    }

    Context 'Get-SecretInfo' {

        BeforeEach {
            $mockSession = New-MockSession
            InModuleScope PSInfisical.Extension -Parameters @{ name = $script:vaultName; s = $mockSession } {
                param($name, $s)
                $script:SessionCache[$name] = $s
            }
            InModuleScope PSInfisical -Parameters @{ s = $mockSession } {
                param($s)
                $script:InfisicalSession = $s
            }
        }

        It 'Returns SecretInformation objects for all secrets' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $result = @(Get-SecretInfo -VaultName $script:vaultName -AdditionalParameters $script:vaultParams)

            $result.Count | Should -Be 3
            $result[0].Name | Should -Be 'DB_HOST'
            $result[1].Name | Should -Be 'DB_PORT'
            $result[2].Name | Should -Be 'API_KEY'
        }

        It 'Sets SecretType to SecureString on each SecretInformation' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $result = @(Get-SecretInfo -VaultName $script:vaultName -AdditionalParameters $script:vaultParams)

            foreach ($info in $result) {
                $info.Type | Should -Be ([Microsoft.PowerShell.SecretManagement.SecretType]::SecureString)
            }
        }

        It 'Sets VaultName correctly on each SecretInformation' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $result = @(Get-SecretInfo -VaultName $script:vaultName -AdditionalParameters $script:vaultParams)

            foreach ($info in $result) {
                $info.VaultName | Should -Be $script:vaultName
            }
        }

        It 'Applies wildcard filter correctly' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $result = @(Get-SecretInfo -Filter 'DB_*' -VaultName $script:vaultName -AdditionalParameters $script:vaultParams)

            $result.Count | Should -Be 2
            $result[0].Name | Should -Be 'DB_HOST'
            $result[1].Name | Should -Be 'DB_PORT'
        }

        It 'Returns empty array when no secrets exist' {
            Mock Invoke-RestMethod {
                return @{ secrets = @() }
            } -ModuleName PSInfisical

            $result = @(Get-SecretInfo -VaultName $script:vaultName -AdditionalParameters $script:vaultParams)

            $result.Count | Should -Be 0
        }
    }

    Context 'Session Caching' {

        It 'Reuses cached session for same vault name' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -match 'universal-auth/login') {
                    return Get-SampleAuthResponse
                }
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            # First call — authenticates
            Test-SecretVault -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            # Second call — should reuse cached session (no additional auth call)
            Test-SecretVault -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            # Auth endpoint should be called only once
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'universal-auth/login'
            } -Times 1 -Exactly
        }

        It 'Creates separate sessions for different vault names' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -match 'universal-auth/login') {
                    return Get-SampleAuthResponse
                }
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $vaultParams2 = $script:vaultParams.Clone()
            $vaultParams2['ProjectId'] = 'other-project-id'

            Test-SecretVault -VaultName 'Vault1' -AdditionalParameters $script:vaultParams
            Test-SecretVault -VaultName 'Vault2' -AdditionalParameters $vaultParams2

            # Auth endpoint should be called twice — once per vault
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'universal-auth/login'
            } -Times 2 -Exactly
        }

        It 'Re-authenticates when session expires' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -match 'universal-auth/login') {
                    return Get-SampleAuthResponse
                }
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            # First call — authenticates
            Test-SecretVault -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            # Expire the cached session
            $vn = $script:vaultName
            $cachedSession = InModuleScope PSInfisical.Extension -Parameters @{ name = $vn } {
                param($name)
                $script:SessionCache[$name]
            }
            $cachedSession.TokenExpiry = [datetime]::UtcNow.AddSeconds(-1)
            $cachedSession.Connected = $false

            # Second call — should re-authenticate
            Test-SecretVault -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            # Auth endpoint should be called twice
            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'universal-auth/login'
            } -Times 2 -Exactly
        }
    }

    Context 'Parameter Validation' {

        It 'Throws when ProjectId is missing' {
            $badParams = @{
                ClientId     = 'test-client-id'
                ClientSecret = 'test-client-secret'
            }

            { Get-Secret -Name 'TEST' -VaultName $script:vaultName -AdditionalParameters $badParams -ErrorAction Stop } |
                Should -Throw "*ProjectId*"
        }

        It 'Throws when no auth credentials are provided' {
            $badParams = @{
                ProjectId = 'test-project-id'
            }

            { Get-Secret -Name 'TEST' -VaultName $script:vaultName -AdditionalParameters $badParams -ErrorAction Stop } |
                Should -Throw "*authentication credentials*"
        }

        It 'Uses default ApiUrl when not specified' {
            $paramsNoUrl = @{
                ClientId     = 'test-client-id'
                ClientSecret = 'test-client-secret'
                ProjectId    = 'test-project-id'
            }

            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -match 'universal-auth/login') {
                    $Uri | Should -Match 'https://app.infisical.com'
                    return Get-SampleAuthResponse
                }
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $result = Test-SecretVault -VaultName $script:vaultName -AdditionalParameters $paramsNoUrl
            $result | Should -BeTrue
        }

        It 'Uses default Environment when not specified' {
            $paramsNoEnv = $script:vaultParams.Clone()
            $paramsNoEnv.Remove('Environment')

            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -match 'universal-auth/login') {
                    return Get-SampleAuthResponse
                }
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $result = Test-SecretVault -VaultName $script:vaultName -AdditionalParameters $paramsNoEnv
            $result | Should -BeTrue

            # Verify the session was created with 'prod' as default environment
            $vn = $script:vaultName
            $cachedSession = InModuleScope PSInfisical.Extension -Parameters @{ name = $vn } {
                param($name)
                $script:SessionCache[$name]
            }
            $cachedSession.DefaultEnvironment | Should -Be 'prod'
        }

        It 'Uses default SecretPath when not specified' {
            $paramsNoPath = $script:vaultParams.Clone()
            $paramsNoPath.Remove('SecretPath')

            $mockSession = New-MockSession
            InModuleScope PSInfisical.Extension -Parameters @{ name = $script:vaultName; s = $mockSession } {
                param($name, $s)
                $script:SessionCache[$name] = $s
            }
            InModuleScope PSInfisical -Parameters @{ s = $mockSession } {
                param($s)
                $script:InfisicalSession = $s
            }

            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match 'secretPath=%2F'
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            Get-SecretInfo -VaultName $script:vaultName -AdditionalParameters $paramsNoPath

            Should -Invoke Invoke-RestMethod -ModuleName PSInfisical -Times 1
        }

        It 'Handles SecureString credentials in VaultParameters' {
            $paramsSecure = @{
                ClientId     = 'test-client-id'
                ClientSecret = New-TestSecureString -PlainText 'test-client-secret'
                ProjectId    = 'test-project-id'
            }

            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -match 'universal-auth/login') {
                    return Get-SampleAuthResponse
                }
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $result = Test-SecretVault -VaultName $script:vaultName -AdditionalParameters $paramsSecure
            $result | Should -BeTrue
        }

        It 'Supports Token auth in VaultParameters' {
            $tokenParams = @{
                Token     = 'static-api-token'
                ProjectId = 'test-project-id'
            }

            $mockSession = New-MockSession -AuthMethod 'Token'
            InModuleScope PSInfisical.Extension -Parameters @{ name = $script:vaultName; s = $mockSession } {
                param($name, $s)
                $script:SessionCache[$name] = $s
            }
            InModuleScope PSInfisical -Parameters @{ s = $mockSession } {
                param($s)
                $script:InfisicalSession = $s
            }

            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $result = Test-SecretVault -VaultName $script:vaultName -AdditionalParameters $tokenParams
            $result | Should -BeTrue
        }

        It 'Supports AccessToken auth in VaultParameters' {
            $accessTokenParams = @{
                AccessToken = 'pre-obtained-jwt'
                ProjectId   = 'test-project-id'
            }

            $mockSession = New-MockSession -AuthMethod 'AccessToken'
            InModuleScope PSInfisical.Extension -Parameters @{ name = $script:vaultName; s = $mockSession } {
                param($name, $s)
                $script:SessionCache[$name] = $s
            }
            InModuleScope PSInfisical -Parameters @{ s = $mockSession } {
                param($s)
                $script:InfisicalSession = $s
            }

            Mock Invoke-RestMethod {
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            $result = Test-SecretVault -VaultName $script:vaultName -AdditionalParameters $accessTokenParams
            $result | Should -BeTrue
        }
    }
}

AfterAll {
    Remove-Module -Name PSInfisical.Extension -Force -ErrorAction SilentlyContinue
    if (Get-Command -Name Disconnect-Infisical -ErrorAction SilentlyContinue) {
        Disconnect-Infisical -Confirm:$false -ErrorAction SilentlyContinue
    }
    Remove-Module -Name PSInfisical -Force -ErrorAction SilentlyContinue
}
