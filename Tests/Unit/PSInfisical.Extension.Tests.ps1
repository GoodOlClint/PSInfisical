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
        # Mock capability probe to avoid real HTTP calls during tests
        Mock Test-InfisicalApiCapability {
            return @{ SecretsV4 = $true; SecretsV3 = $true }
        } -ModuleName PSInfisical

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
                $Uri | Should -Match 'secretPath=(%2F|/)database'
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

    Context 'Hierarchical Names (slash in -Name)' {

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

        It 'Resolve-InfisicalName: no slash returns name unchanged with base path' {
            $result = InModuleScope PSInfisical.Extension {
                Resolve-InfisicalName -Name 'API_KEY' -BasePath '/'
            }

            $result.Name | Should -Be 'API_KEY'
            $result.SecretPath | Should -Be '/'
        }

        It 'Resolve-InfisicalName: splits slash-bearing name into key and sub-path under root' {
            $result = InModuleScope PSInfisical.Extension {
                Resolve-InfisicalName -Name 'worklab/winhost/admin/winvm' -BasePath '/'
            }

            $result.Name | Should -Be 'winvm'
            $result.SecretPath | Should -Be '/worklab/winhost/admin'
        }

        It 'Resolve-InfisicalName: joins slash-prefix under a non-root base path' {
            $result = InModuleScope PSInfisical.Extension {
                Resolve-InfisicalName -Name 'worklab/winvm' -BasePath '/teams'
            }

            $result.Name | Should -Be 'winvm'
            $result.SecretPath | Should -Be '/teams/worklab'
        }

        It 'Resolve-InfisicalName: leading slash on name is treated relative to base' {
            $result = InModuleScope PSInfisical.Extension {
                Resolve-InfisicalName -Name '/worklab/winvm' -BasePath '/teams'
            }

            $result.Name | Should -Be 'winvm'
            $result.SecretPath | Should -Be '/teams/worklab'
        }

        It 'Resolve-InfisicalName: throws when name ends with a slash' {
            {
                InModuleScope PSInfisical.Extension {
                    Resolve-InfisicalName -Name 'worklab/winhost/' -BasePath '/'
                }
            } | Should -Throw '*ends with*'
        }

        It 'Get-RelativeSecretName: bare name when secret sits at the base path' {
            $result = InModuleScope PSInfisical.Extension {
                Get-RelativeSecretName -BasePath '/' -SecretPath '/' -Name 'DB_HOST'
            }

            $result | Should -Be 'DB_HOST'
        }

        It 'Get-RelativeSecretName: slash-prefixed name when secret sits below the base' {
            $result = InModuleScope PSInfisical.Extension {
                Get-RelativeSecretName -BasePath '/' -SecretPath '/worklab/winhost/admin' -Name 'winvm'
            }

            $result | Should -Be 'worklab/winhost/admin/winvm'
        }

        It 'Get-RelativeSecretName: relativises against a non-root base path' {
            $result = InModuleScope PSInfisical.Extension {
                Get-RelativeSecretName -BasePath '/teams' -SecretPath '/teams/worklab' -Name 'winvm'
            }

            $result | Should -Be 'worklab/winvm'
        }

        It 'Set-Secret: routes the bare key and sub-path through the create call' {
            $capturedCreatePath = $null
            $capturedCreateName = $null
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                if ($Method -eq 'GET' -and $Uri -match '/api/v4/secrets/') {
                    return $null  # secret does not yet exist
                }
                if ($Method -eq 'POST' -and $Uri -match '/api/v2/folders') {
                    return @{ folder = @{ id = 'folder-x'; name = 'x' } }
                }
                if ($Method -eq 'POST' -and $Uri -match '/api/v4/secrets/') {
                    $parsed = $Body | ConvertFrom-Json
                    $script:capturedCreatePath = $parsed.secretPath
                    $script:capturedCreateName = ($Uri -split '/')[-1] -split '\?' | Select-Object -First 1
                    return Get-SampleSecretResponse -Name 'winvm' -Value 'host-secret'
                }
                return $null
            } -ModuleName PSInfisical

            $result = Set-Secret -Name 'worklab/winhost/admin/winvm' -Secret 'host-secret' `
                -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            $result | Should -BeTrue
            $script:capturedCreatePath | Should -Be '/worklab/winhost/admin'
            $script:capturedCreateName | Should -Be 'winvm'
        }

        It 'Set-Secret: creates each intermediate folder before writing the secret' {
            $script:folderCreates = @()
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                if ($Method -eq 'GET' -and $Uri -match '/api/v4/secrets/') {
                    return $null
                }
                if ($Method -eq 'POST' -and $Uri -match '/api/v2/folders') {
                    $parsed = $Body | ConvertFrom-Json
                    $script:folderCreates += @{ Name = $parsed.name; Path = $parsed.path }
                    return @{ folder = @{ id = "folder-$($parsed.name)"; name = $parsed.name } }
                }
                if ($Method -eq 'POST' -and $Uri -match '/api/v4/secrets/') {
                    return Get-SampleSecretResponse -Name 'winvm' -Value 'host-secret'
                }
                return $null
            } -ModuleName PSInfisical

            Set-Secret -Name 'worklab/winhost/admin/winvm' -Secret 'host-secret' `
                -VaultName $script:vaultName -AdditionalParameters $script:vaultParams | Out-Null

            $script:folderCreates.Count | Should -Be 3
            $script:folderCreates[0].Name | Should -Be 'worklab'
            $script:folderCreates[0].Path | Should -Be '/'
            $script:folderCreates[1].Name | Should -Be 'winhost'
            $script:folderCreates[1].Path | Should -Be '/worklab'
            $script:folderCreates[2].Name | Should -Be 'admin'
            $script:folderCreates[2].Path | Should -Be '/worklab/winhost'
        }

        It 'Set-Secret: does not create folders when the secret already exists at a sub-path' {
            $script:folderCalls = 0
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                if ($Method -eq 'GET' -and $Uri -match '/api/v4/secrets/') {
                    return Get-SampleSecretResponse -Name 'winvm' -Value 'old-value'
                }
                if ($Method -eq 'POST' -and $Uri -match '/api/v2/folders') {
                    $script:folderCalls++
                    return @{ folder = @{ id = 'x'; name = 'x' } }
                }
                if ($Method -eq 'PATCH') {
                    return Get-SampleSecretResponse -Name 'winvm' -Value 'new-value'
                }
                return $null
            } -ModuleName PSInfisical

            Set-Secret -Name 'worklab/winvm' -Secret 'new-value' `
                -VaultName $script:vaultName -AdditionalParameters $script:vaultParams | Out-Null

            $script:folderCalls | Should -Be 0
        }

        It 'Get-Secret: looks up the bare key at the resolved sub-path' {
            $capturedUri = $null
            Mock Invoke-RestMethod {
                param($Uri)
                $script:capturedUri = $Uri
                return Get-SampleSecretResponse -Name 'winvm' -Value 'host-secret'
            } -ModuleName PSInfisical

            Get-Secret -Name 'worklab/winhost/admin/winvm' `
                -VaultName $script:vaultName -AdditionalParameters $script:vaultParams | Out-Null

            $script:capturedUri | Should -Match '/api/v4/secrets/winvm'
            $script:capturedUri | Should -Match 'secretPath=%2Fworklab%2Fwinhost%2Fadmin'
        }

        It 'Remove-Secret: deletes the bare key at the resolved sub-path' {
            $capturedBody = $null
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                if ($Method -eq 'DELETE') {
                    $script:capturedBody = $Body | ConvertFrom-Json
                }
                return @{ secret = @{ secretKey = 'winvm' } }
            } -ModuleName PSInfisical

            Remove-Secret -Name 'worklab/winvm' `
                -VaultName $script:vaultName -AdditionalParameters $script:vaultParams | Out-Null

            $script:capturedBody.secretPath | Should -Be '/worklab'
        }

        It 'Get-SecretInfo: surfaces sub-path secrets with slash-qualified names' {
            Mock Invoke-RestMethod {
                return Get-SampleNestedSecretsListResponse
            } -ModuleName PSInfisical

            $result = @(Get-SecretInfo -VaultName $script:vaultName -AdditionalParameters $script:vaultParams)

            $names = $result.Name | Sort-Object
            $names | Should -Contain 'FLAT_KEY'
            $names | Should -Contain 'api/token'
            $names | Should -Contain 'worklab/winhost/admin/winvm'
        }

        It 'Get-SecretInfo: requests recursive listing from the API' {
            $capturedUri = $null
            Mock Invoke-RestMethod {
                param($Uri)
                $script:capturedUri = $Uri
                return Get-SampleSecretsListResponse
            } -ModuleName PSInfisical

            Get-SecretInfo -VaultName $script:vaultName -AdditionalParameters $script:vaultParams | Out-Null

            $script:capturedUri | Should -Match 'recursive=true'
        }
    }

    Context 'SecretType Round-Trip' {

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

        It 'ConvertTo-InfisicalSecretPayload: SecureString tagged as SecureString' {
            $result = InModuleScope PSInfisical.Extension {
                $ss = [System.Security.SecureString]::new()
                foreach ($c in 'hunter2'.ToCharArray()) { $ss.AppendChar($c) }
                ConvertTo-InfisicalSecretPayload -Secret $ss
            }

            $result.Type | Should -Be 'SecureString'
            $result.Value | Should -Be 'hunter2'
        }

        It 'ConvertTo-InfisicalSecretPayload: plain string tagged as String' {
            $result = InModuleScope PSInfisical.Extension {
                ConvertTo-InfisicalSecretPayload -Secret 'plain-text-value'
            }

            $result.Type | Should -Be 'String'
            $result.Value | Should -Be 'plain-text-value'
        }

        It 'ConvertTo-InfisicalSecretPayload: PSCredential serialised as JSON' {
            $result = InModuleScope PSInfisical.Extension {
                $ss = [System.Security.SecureString]::new()
                foreach ($c in 's3cret!'.ToCharArray()) { $ss.AppendChar($c) }
                $ss.MakeReadOnly()
                $cred = [System.Management.Automation.PSCredential]::new('alice', $ss)
                ConvertTo-InfisicalSecretPayload -Secret $cred
            }

            $result.Type | Should -Be 'PSCredential'
            $parsed = $result.Value | ConvertFrom-Json
            $parsed.UserName | Should -Be 'alice'
            $parsed.Password | Should -Be 's3cret!'
        }

        It 'ConvertTo-InfisicalSecretPayload: byte[] base64-encoded' {
            $result = InModuleScope PSInfisical.Extension {
                $bytes = [byte[]] @(1, 2, 3, 255)
                ConvertTo-InfisicalSecretPayload -Secret $bytes
            }

            $result.Type | Should -Be 'ByteArray'
            $result.Value | Should -Be ([System.Convert]::ToBase64String([byte[]] @(1, 2, 3, 255)))
        }

        It 'ConvertTo-InfisicalSecretPayload: hashtable with nested SecureString preserves the marker' {
            $result = InModuleScope PSInfisical.Extension {
                $ss = [System.Security.SecureString]::new()
                foreach ($c in 'inner-pw'.ToCharArray()) { $ss.AppendChar($c) }
                $ss.MakeReadOnly()
                $ht = @{ user = 'bob'; token = $ss }
                ConvertTo-InfisicalSecretPayload -Secret $ht
            }

            $result.Type | Should -Be 'Hashtable'
            $parsed = $result.Value | ConvertFrom-Json
            $parsed.user | Should -Be 'bob'
            $parsed.token.__PSInfisicalSecureString__ | Should -BeTrue
            $parsed.token.v | Should -Be 'inner-pw'
        }

        It 'ConvertTo-InfisicalSecretPayload: throws on unsupported types' {
            {
                InModuleScope PSInfisical.Extension {
                    ConvertTo-InfisicalSecretPayload -Secret ([datetime]::Now)
                }
            } | Should -Throw '*Unsupported -Secret type*'
        }

        It 'ConvertFrom-InfisicalSecretPayload: missing type tag returns SecureString (legacy)' {
            $result = InModuleScope PSInfisical.Extension {
                ConvertFrom-InfisicalSecretPayload -Value 'legacy-value' -Type ''
            }

            $result | Should -BeOfType [System.Security.SecureString]
            [System.Net.NetworkCredential]::new('', $result).Password | Should -Be 'legacy-value'
        }

        It 'ConvertFrom-InfisicalSecretPayload: PSCredential rebuilt from JSON' {
            $result = InModuleScope PSInfisical.Extension {
                $json = (@{ UserName = 'alice'; Password = 's3cret!' } | ConvertTo-Json -Compress)
                ConvertFrom-InfisicalSecretPayload -Value $json -Type 'PSCredential'
            }

            $result | Should -BeOfType [System.Management.Automation.PSCredential]
            $result.UserName | Should -Be 'alice'
            [System.Net.NetworkCredential]::new('', $result.Password).Password | Should -Be 's3cret!'
        }

        It 'ConvertFrom-InfisicalSecretPayload: Hashtable rebuilds nested SecureStrings' {
            $result = InModuleScope PSInfisical.Extension {
                $json = '{"user":"bob","token":{"__PSInfisicalSecureString__":true,"v":"inner-pw"}}'
                ConvertFrom-InfisicalSecretPayload -Value $json -Type 'Hashtable'
            }

            $result | Should -BeOfType [hashtable]
            $result['user'] | Should -Be 'bob'
            $result['token'] | Should -BeOfType [System.Security.SecureString]
            [System.Net.NetworkCredential]::new('', $result['token']).Password | Should -Be 'inner-pw'
        }

        It 'ConvertFrom-InfisicalSecretPayload: ByteArray decoded from base64' {
            # Keep assertions inside InModuleScope so the byte[] return type is
            # not unrolled into an Object[] by the pipeline.
            InModuleScope PSInfisical.Extension {
                $result = ConvertFrom-InfisicalSecretPayload -Value 'AQID/w==' -Type 'ByteArray'
                $result.GetType().Name | Should -Be 'Byte[]'
                $result.Length | Should -Be 4
                $result[0] | Should -Be 1
                $result[1] | Should -Be 2
                $result[2] | Should -Be 3
                $result[3] | Should -Be 255
            }
        }

        It 'Set-Secret: stores PSCredential as JSON and tags the metadata' {
            $script:capturedBody = $null
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                if ($Method -eq 'GET') { return $null }
                if ($Method -eq 'POST' -and $Uri -match '/api/v4/secrets/') {
                    $script:capturedBody = $Body | ConvertFrom-Json
                    return Get-SampleSecretResponse -Name 'mycred' -Value 'ignored'
                }
                return $null
            } -ModuleName PSInfisical

            $ss = New-TestSecureString -PlainText 'p@ssw0rd'
            $cred = [System.Management.Automation.PSCredential]::new('alice', $ss)
            Set-Secret -Name 'mycred' -Secret $cred -VaultName $script:vaultName -AdditionalParameters $script:vaultParams | Out-Null

            $script:capturedBody | Should -Not -BeNullOrEmpty
            $payload = $script:capturedBody.secretValue | ConvertFrom-Json
            $payload.UserName | Should -Be 'alice'
            $payload.Password | Should -Be 'p@ssw0rd'

            $typeMeta = $script:capturedBody.secretMetadata | Where-Object { $_.key -eq 'PSInfisicalSecretType' }
            $typeMeta | Should -Not -BeNullOrEmpty
            $typeMeta.value | Should -Be 'PSCredential'
        }

        It 'Set-Secret: preserves existing user metadata when updating' {
            $script:capturedBody = $null
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body)
                if ($Method -eq 'GET') {
                    return Get-SampleTypedSecretResponse -Name 'kept' -Value 'old' -Metadata @{ owner = 'team-x' }
                }
                if ($Method -eq 'PATCH') {
                    $script:capturedBody = $Body | ConvertFrom-Json
                    return Get-SampleSecretResponse -Name 'kept' -Value 'new'
                }
                return $null
            } -ModuleName PSInfisical

            Set-Secret -Name 'kept' -Secret 'new-value' -VaultName $script:vaultName -AdditionalParameters $script:vaultParams | Out-Null

            $keys = @($script:capturedBody.secretMetadata | ForEach-Object { $_.key })
            $keys | Should -Contain 'owner'
            $keys | Should -Contain 'PSInfisicalSecretType'
        }

        It 'Get-Secret: rebuilds a PSCredential when the type tag is present' {
            Mock Invoke-RestMethod {
                $json = (@{ UserName = 'alice'; Password = 's3cret!' } | ConvertTo-Json -Compress)
                return Get-SampleTypedSecretResponse -Name 'mycred' -Value $json -Metadata @{ PSInfisicalSecretType = 'PSCredential' }
            } -ModuleName PSInfisical

            $result = Get-Secret -Name 'mycred' -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            $result | Should -BeOfType [System.Management.Automation.PSCredential]
            $result.UserName | Should -Be 'alice'
            [System.Net.NetworkCredential]::new('', $result.Password).Password | Should -Be 's3cret!'
        }

        It 'Get-Secret: returns plain string when type tag is String' {
            Mock Invoke-RestMethod {
                return Get-SampleTypedSecretResponse -Name 'flat' -Value 'just-a-string' -Metadata @{ PSInfisicalSecretType = 'String' }
            } -ModuleName PSInfisical

            $result = Get-Secret -Name 'flat' -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            $result | Should -BeOfType [string]
            $result | Should -Be 'just-a-string'
        }

        It 'Get-Secret: falls back to SecureString when no type tag is present' {
            Mock Invoke-RestMethod {
                return Get-SampleSecretResponse -Name 'legacy' -Value 'untagged'
            } -ModuleName PSInfisical

            $result = Get-Secret -Name 'legacy' -VaultName $script:vaultName -AdditionalParameters $script:vaultParams

            $result | Should -BeOfType [System.Security.SecureString]
            [System.Net.NetworkCredential]::new('', $result).Password | Should -Be 'untagged'
        }

        It 'Get-SecretInfo: reports SecretType based on the stored tag' {
            Mock Invoke-RestMethod {
                return @{
                    secrets = @(
                        @{
                            id = 'a'; _id = 'a'; workspace = 'p'; environment = 'dev'
                            secretKey = 'pw'; secretValue = ''; secretComment = ''
                            secretPath = '/'; version = 1; type = 'shared'
                            tags = @()
                            secretMetadata = @(@{ key = 'PSInfisicalSecretType'; value = 'PSCredential' })
                            secretReminderRepeatDays = $null; secretReminderNote = $null
                            createdAt = '2024-01-10T08:00:00Z'; updatedAt = '2024-01-10T08:00:00Z'
                        }
                        @{
                            id = 'b'; _id = 'b'; workspace = 'p'; environment = 'dev'
                            secretKey = 'flag'; secretValue = ''; secretComment = ''
                            secretPath = '/'; version = 1; type = 'shared'
                            tags = @()
                            secretMetadata = @(@{ key = 'PSInfisicalSecretType'; value = 'String' })
                            secretReminderRepeatDays = $null; secretReminderNote = $null
                            createdAt = '2024-01-10T08:00:00Z'; updatedAt = '2024-01-10T08:00:00Z'
                        }
                        @{
                            id = 'c'; _id = 'c'; workspace = 'p'; environment = 'dev'
                            secretKey = 'legacy'; secretValue = ''; secretComment = ''
                            secretPath = '/'; version = 1; type = 'shared'
                            tags = @()
                            secretMetadata = @()
                            secretReminderRepeatDays = $null; secretReminderNote = $null
                            createdAt = '2024-01-10T08:00:00Z'; updatedAt = '2024-01-10T08:00:00Z'
                        }
                    )
                }
            } -ModuleName PSInfisical

            $result = @(Get-SecretInfo -VaultName $script:vaultName -AdditionalParameters $script:vaultParams)

            $byName = @{}
            foreach ($info in $result) { $byName[$info.Name] = $info }
            $byName['pw'].Type     | Should -Be ([Microsoft.PowerShell.SecretManagement.SecretType]::PSCredential)
            $byName['flag'].Type   | Should -Be ([Microsoft.PowerShell.SecretManagement.SecretType]::String)
            $byName['legacy'].Type | Should -Be ([Microsoft.PowerShell.SecretManagement.SecretType]::SecureString)
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
                $Uri | Should -Match 'secretPath=(%2F|/)'
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
