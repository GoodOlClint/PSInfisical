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
# Classes are available via type accelerators registered in the psm1.
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

# Sample API response for a single secret (as returned by /v4/secrets/raw/{name})
function Get-SampleSecretResponse {
    param(
        [string] $Name = 'TEST_SECRET',
        [string] $Value = 'secret-value-123',
        [int] $Version = 1
    )
    return @{
        secret = @{
            id                        = 'sec-abc-123'
            _id                       = 'sec-abc-123'
            workspace                 = 'test-project-id'
            environment               = 'dev'
            secretKey                 = $Name
            secretValue               = $Value
            secretComment             = 'Test comment'
            secretPath                = '/'
            version                   = $Version
            type                      = 'shared'
            tags                      = @()
            secretMetadata            = @()
            secretReminderRepeatDays  = $null
            secretReminderNote        = $null
            createdAt                 = '2024-01-15T10:30:00Z'
            updatedAt                 = '2024-01-15T10:30:00Z'
        }
    }
}

# Sample API response for a secret with v4 metadata (tags, metadata, reminders)
function Get-SampleSecretResponseWithMetadata {
    param(
        [string] $Name = 'TAGGED_SECRET',
        [string] $Value = 'tagged-value'
    )
    return @{
        secret = @{
            id                        = 'sec-meta-001'
            _id                       = 'sec-meta-001'
            workspace                 = 'test-project-id'
            environment               = 'dev'
            secretKey                 = $Name
            secretValue               = $Value
            secretComment             = 'Has metadata'
            secretPath                = '/'
            version                   = 1
            type                      = 'personal'
            tags                      = @(
                @{ id = 'tag-001'; slug = 'production'; color = '#FF0000' }
                @{ id = 'tag-002'; slug = 'database'; color = '#00FF00' }
            )
            secretMetadata            = @(
                @{ key = 'team'; value = 'backend' }
                @{ key = 'rotation'; value = 'quarterly' }
            )
            secretReminderRepeatDays  = 90
            secretReminderNote        = 'Rotate this secret quarterly'
            createdAt                 = '2024-01-15T10:30:00Z'
            updatedAt                 = '2024-01-15T10:30:00Z'
        }
    }
}

# Sample API response for listing multiple secrets (as returned by /v4/secrets/raw)
function Get-SampleSecretsListResponse {
    return @{
        secrets = @(
            @{
                id                       = 'sec-001'
                _id                      = 'sec-001'
                workspace                = 'test-project-id'
                environment              = 'dev'
                secretKey                = 'DB_HOST'
                secretValue              = 'localhost'
                secretComment            = ''
                secretPath               = '/'
                version                  = 3
                type                     = 'shared'
                tags                     = @()
                secretMetadata           = @()
                secretReminderRepeatDays = $null
                secretReminderNote       = $null
                createdAt                = '2024-01-10T08:00:00Z'
                updatedAt                = '2024-01-14T12:00:00Z'
            },
            @{
                id                       = 'sec-002'
                _id                      = 'sec-002'
                workspace                = 'test-project-id'
                environment              = 'dev'
                secretKey                = 'DB_PORT'
                secretValue              = '5432'
                secretComment            = 'PostgreSQL default port'
                secretPath               = '/'
                version                  = 1
                type                     = 'shared'
                tags                     = @()
                secretMetadata           = @()
                secretReminderRepeatDays = $null
                secretReminderNote       = $null
                createdAt                = '2024-01-10T08:00:00Z'
                updatedAt                = '2024-01-10T08:00:00Z'
            },
            @{
                id                       = 'sec-003'
                _id                      = 'sec-003'
                workspace                = 'test-project-id'
                environment              = 'dev'
                secretKey                = 'API_KEY'
                secretValue              = 'sk-test-key'
                secretComment            = ''
                secretPath               = '/'
                version                  = 2
                type                     = 'shared'
                tags                     = @(@{ id = 'tag-001'; slug = 'api'; color = '#0000FF' })
                secretMetadata           = @(@{ key = 'owner'; value = 'platform-team' })
                secretReminderRepeatDays = $null
                secretReminderNote       = $null
                createdAt                = '2024-01-11T09:00:00Z'
                updatedAt                = '2024-01-13T15:00:00Z'
            }
        )
    }
}

# Sample API response for a single folder (as returned by /v2/folders/{id})
function Get-SampleFolderResponse {
    param(
        [string] $Name = 'test-folder',
        [string] $Id = 'folder-abc-123'
    )
    return @{
        folder = @{
            id          = $Id
            name        = $Name
            environment = 'dev'
            path        = '/'
            description = 'Test folder'
            createdAt   = '2024-02-01T10:00:00Z'
            updatedAt   = '2024-02-01T10:00:00Z'
        }
    }
}

# Sample API response for listing folders (as returned by /v2/folders)
function Get-SampleFoldersListResponse {
    return @{
        folders = @(
            @{
                id          = 'folder-001'
                name        = 'database'
                environment = 'dev'
                path        = '/'
                description = 'Database secrets'
                createdAt   = '2024-02-01T10:00:00Z'
                updatedAt   = '2024-02-01T10:00:00Z'
            },
            @{
                id          = 'folder-002'
                name        = 'api-keys'
                environment = 'dev'
                path        = '/'
                description = ''
                createdAt   = '2024-02-02T08:00:00Z'
                updatedAt   = '2024-02-02T08:00:00Z'
            }
        )
    }
}

# Sample API response for a single tag (as returned by /v1/projects/{id}/tags/{id})
function Get-SampleTagResponse {
    param(
        [string] $Slug = 'production',
        [string] $Id = 'tag-abc-123',
        [string] $Color = '#FF0000'
    )
    return @{
        tag = @{
            id        = $Id
            name      = $Slug
            slug      = $Slug
            color     = $Color
            createdAt = '2024-03-01T10:00:00Z'
            updatedAt = '2024-03-01T10:00:00Z'
        }
    }
}

# Sample API response for listing tags (as returned by /v1/projects/{id}/tags)
function Get-SampleTagsListResponse {
    return @{
        tags = @(
            @{
                id        = 'tag-001'
                name      = 'production'
                slug      = 'production'
                color     = '#FF0000'
                createdAt = '2024-03-01T10:00:00Z'
                updatedAt = '2024-03-01T10:00:00Z'
            },
            @{
                id        = 'tag-002'
                name      = 'database'
                slug      = 'database'
                color     = '#00FF00'
                createdAt = '2024-03-02T08:00:00Z'
                updatedAt = '2024-03-02T08:00:00Z'
            }
        )
    }
}

# Sample API response for a single secret import (as returned by /v2/secret-imports)
function Get-SampleSecretImportResponse {
    param(
        [string] $Id = 'import-abc-123'
    )
    return @{
        secretImport = @{
            id            = $Id
            importPath    = '/shared'
            importEnv     = @{ slug = 'prod'; name = 'Production' }
            position      = 1
            isReplication = $false
            createdAt     = '2024-04-01T10:00:00Z'
            updatedAt     = '2024-04-01T10:00:00Z'
        }
    }
}

# Sample API response for listing secret imports
function Get-SampleSecretImportsListResponse {
    return @{
        secretImports = @(
            @{
                id            = 'import-001'
                importPath    = '/shared'
                importEnv     = @{ slug = 'prod'; name = 'Production' }
                position      = 1
                isReplication = $false
                createdAt     = '2024-04-01T10:00:00Z'
                updatedAt     = '2024-04-01T10:00:00Z'
            },
            @{
                id            = 'import-002'
                importPath    = '/common'
                importEnv     = @{ slug = 'staging'; name = 'Staging' }
                position      = 2
                isReplication = $true
                createdAt     = '2024-04-02T08:00:00Z'
                updatedAt     = '2024-04-02T08:00:00Z'
            }
        )
    }
}

# Sample API response for listing environments
function Get-SampleEnvironmentsResponse {
    return @{
        environments = @(
            @{ id = 'env-001'; name = 'Development'; slug = 'dev'; position = 1 }
            @{ id = 'env-002'; name = 'Staging';     slug = 'staging'; position = 2 }
            @{ id = 'env-003'; name = 'Production';  slug = 'prod'; position = 3 }
        )
    }
}

# Sample API response for a single project/workspace
function Get-SampleProjectResponse {
    param([string] $Id = 'proj-abc-123')
    return @{
        workspace = @{
            id        = $Id
            name      = 'My Project'
            slug      = 'my-project'
            createdAt = '2024-01-01T00:00:00Z'
            updatedAt = '2024-06-01T00:00:00Z'
        }
    }
}

# Sample API response for listing projects/workspaces
function Get-SampleProjectsListResponse {
    return @{
        workspaces = @(
            @{ id = 'proj-001'; name = 'Project Alpha'; slug = 'alpha'; createdAt = '2024-01-01T00:00:00Z'; updatedAt = '2024-06-01T00:00:00Z' }
            @{ id = 'proj-002'; name = 'Project Beta';  slug = 'beta';  createdAt = '2024-02-01T00:00:00Z'; updatedAt = '2024-06-15T00:00:00Z' }
        )
    }
}

# Sample API response for a single identity
function Get-SampleIdentityResponse {
    param(
        [string] $Name = 'test-identity',
        [string] $Id = 'identity-abc-123'
    )
    return @{
        identity = @{
            id                  = $Id
            name                = $Name
            orgId               = 'org-test-123'
            role                = 'member'
            authMethods         = @('universal-auth')
            hasDeleteProtection = $false
            metadata            = @()
            createdAt           = '2024-05-01T10:00:00Z'
            updatedAt           = '2024-05-01T10:00:00Z'
        }
    }
}

# Sample API response for listing identities
function Get-SampleIdentitiesListResponse {
    return @{
        identities = @(
            @{
                id                  = 'identity-001'
                name                = 'deploy-agent'
                orgId               = 'org-test-123'
                role                = 'member'
                authMethods         = @('universal-auth')
                hasDeleteProtection = $false
                metadata            = @()
                createdAt           = '2024-05-01T10:00:00Z'
                updatedAt           = '2024-05-01T10:00:00Z'
            },
            @{
                id                  = 'identity-002'
                name                = 'ci-runner'
                orgId               = 'org-test-123'
                role                = 'no-access'
                authMethods         = @()
                hasDeleteProtection = $true
                metadata            = @(@{ key = 'team'; value = 'platform' })
                createdAt           = '2024-05-02T08:00:00Z'
                updatedAt           = '2024-05-02T08:00:00Z'
            }
        )
    }
}

# Sample API response for client secret creation
function Get-SampleClientSecretResponse {
    return @{
        clientSecret   = 'cs-generated-secret-value'
        clientSecretId = 'cs-id-001'
    }
}

# Sample API response for listing project identity memberships
function Get-SampleProjectMembersResponse {
    return @{
        identityMemberships = @(
            @{
                identityId = 'identity-001'
                identity   = @{ id = 'identity-001'; name = 'deploy-agent' }
                role       = 'member'
                roleId     = 'role-member'
                createdAt  = '2024-06-01T10:00:00Z'
                updatedAt  = '2024-06-01T10:00:00Z'
            },
            @{
                identityId = 'identity-002'
                identity   = @{ id = 'identity-002'; name = 'ci-runner' }
                role       = 'viewer'
                roleId     = 'role-viewer'
                createdAt  = '2024-06-02T08:00:00Z'
                updatedAt  = '2024-06-02T08:00:00Z'
            }
        )
    }
}

# Sample API response for listing project roles
function Get-SampleProjectRolesResponse {
    return @{
        roles = @(
            @{ id = 'role-001'; name = 'Admin'; slug = 'admin'; description = 'Full access' }
            @{ id = 'role-002'; name = 'Member'; slug = 'member'; description = 'Read/write secrets' }
            @{ id = 'role-003'; name = 'Viewer'; slug = 'viewer'; description = 'Read-only access' }
        )
    }
}

# Sample API response for creating a project role
function Get-SampleProjectRoleResponse {
    param([string] $Slug = 'custom-role')
    return @{
        role = @{
            id          = 'role-custom-001'
            name        = 'Custom Role'
            slug        = $Slug
            description = 'A custom role'
            projectId   = 'test-project-id'
        }
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
