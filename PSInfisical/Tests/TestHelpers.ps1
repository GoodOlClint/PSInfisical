# TestHelpers.ps1
# Shared test utilities for PSInfisical Pester tests.
# Provides mock session creation, sample API response data, and SecureString helpers.
# Called by: All unit test files (after 'using module' has already loaded classes).
# Dependencies: InfisicalSession class, InfisicalSecret class (loaded via 'using module' in callers)

# Helper to create a SecureString from plaintext — for test use only.
# Suppress PSScriptAnalyzer warning as this is intentional for tests.
function New-TestSecureString {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
    [OutputType([System.Security.SecureString])]
    param(
        [Parameter(Mandatory)]
        [string] $PlainText
    )
    return (ConvertTo-SecureString -String $PlainText -AsPlainText -Force)
}

# Creates a valid mock InfisicalSession for use in tests.
# Classes are globally available via ScriptsToProcess in the manifest.
function New-MockSession {
    [OutputType([InfisicalSession])]
    param(
        [string] $ApiUrl = 'https://app.infisical.com',
        [string] $ProjectId = 'test-project-id',
        [string] $Environment = 'dev',
        [string] $AuthMethod = 'UniversalAuth',
        [string] $TokenValue = 'mock-access-token-value'
    )

    $session = [InfisicalSession]::new()
    $session.ApiUrl = $ApiUrl
    $session.ProjectId = $ProjectId
    $session.DefaultEnvironment = $Environment
    $session.AuthMethod = $AuthMethod
    $session.AccessToken = New-TestSecureString -PlainText $TokenValue
    $session.TokenExpiry = [datetime]::UtcNow.AddHours(2)
    $session.Connected = $true
    return $session
}

# Sample API response for a single secret (as returned by /v3/secrets/raw/{name})
function Get-SampleSecretResponse {
    param(
        [string] $Name = 'TEST_SECRET',
        [string] $Value = 'secret-value-123',
        [int] $Version = 1
    )
    return @{
        secret = @{
            id              = 'sec-abc-123'
            _id             = 'sec-abc-123'
            workspace       = 'test-project-id'
            environment     = 'dev'
            secretKey       = $Name
            secretValue     = $Value
            secretComment   = 'Test comment'
            secretPath      = '/'
            version         = $Version
            type            = 'shared'
            createdAt       = '2024-01-15T10:30:00Z'
            updatedAt       = '2024-01-15T10:30:00Z'
        }
    }
}

# Sample API response for listing multiple secrets (as returned by /v3/secrets/raw)
function Get-SampleSecretsListResponse {
    return @{
        secrets = @(
            @{
                id            = 'sec-001'
                _id           = 'sec-001'
                workspace     = 'test-project-id'
                environment   = 'dev'
                secretKey     = 'DB_HOST'
                secretValue   = 'localhost'
                secretComment = ''
                secretPath    = '/'
                version       = 3
                type          = 'shared'
                createdAt     = '2024-01-10T08:00:00Z'
                updatedAt     = '2024-01-14T12:00:00Z'
            },
            @{
                id            = 'sec-002'
                _id           = 'sec-002'
                workspace     = 'test-project-id'
                environment   = 'dev'
                secretKey     = 'DB_PORT'
                secretValue   = '5432'
                secretComment = 'PostgreSQL default port'
                secretPath    = '/'
                version       = 1
                type          = 'shared'
                createdAt     = '2024-01-10T08:00:00Z'
                updatedAt     = '2024-01-10T08:00:00Z'
            },
            @{
                id            = 'sec-003'
                _id           = 'sec-003'
                workspace     = 'test-project-id'
                environment   = 'dev'
                secretKey     = 'API_KEY'
                secretValue   = 'sk-test-key'
                secretComment = ''
                secretPath    = '/'
                version       = 2
                type          = 'shared'
                createdAt     = '2024-01-11T09:00:00Z'
                updatedAt     = '2024-01-13T15:00:00Z'
            }
        )
    }
}

# Sample auth response (as returned by /v1/auth/universal-auth/login)
function Get-SampleAuthResponse {
    return @{
        accessToken       = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock-token'
        expiresIn         = 7200
        accessTokenMaxTTL = 86400
        tokenType         = 'Bearer'
    }
}
