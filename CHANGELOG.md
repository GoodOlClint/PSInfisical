# Changelog

All notable changes to PSInfisical will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.1] - 2026-03-23

### Fixed

- Metadata-only release to fix PSGallery tag indexing. The 0.4.0 publication did not displace the
  unlisted 0.2.0 as the gallery's "latest" version pointer, causing tag-based searches (`Find-Module -Tag Infisical`) to return no results and the package URL to redirect to 0.2.0. Publishing a new
  version forces PSGallery to re-index and update the redirect.
- Added `PSInfisical` to the module tags so `Find-Module -Tag PSInfisical` works.
- Updated `ReleaseNotes` to accurately describe changes (previously said "Initial release").

## [0.4.0] - 2026-03-17

### Added

- Email/password login: `Connect-Infisical -Email 'user@example.com' -Password $pw`
- `Set-InfisicalSession` — update OrganizationId, ProjectId, or Environment after connecting
- `Set-InfisicalProject` — rename projects, toggle auto-capitalization
- `Get-InfisicalOrganization` — list organizations accessible to current user/identity
- OrganizationId auto-resolved from JWT during connect (machine identity and user tokens)
- `-OrganizationId` parameter on `Connect-Infisical` (optional)
- `-Description` parameter on `New-InfisicalProject`
- Transparent v3 API fallback for older self-hosted Infisical instances (rewrites v4→v3 endpoints and projectId→workspaceId automatically)
- Typed response objects: `InfisicalIdentityAuth`, `InfisicalClientSecret`, `InfisicalProjectMembership`
- `-PassThru` on `Add-InfisicalIdentityAuth` and `Add-InfisicalProjectMember`
- 464 unit tests (was 412) and 32 integration tests

### Changed

- `-ProjectId` is now optional on `Connect-Infisical` (for bootstrap workflows)
- `-OrganizationId` is now optional on `New-InfisicalIdentity`, `Get-InfisicalIdentity`, `New-InfisicalProject` (falls back to session)
- `New-InfisicalClientSecret` always returns typed object (plaintext secret only available at creation)
- Integration tests now use `infisical:latest` Docker image (was `latest-postgres`)
- Corrected v4 endpoint paths: `/api/v4/secrets` (not `/raw`), `projectId` query param (not `workspaceId`)

### Fixed

- Always send JSON body on POST/PATCH/DELETE (fixes empty body 500 errors on some endpoints)
- Strict mode errors in `ConvertTo-InfisicalIdentity` when response lacks optional properties
- Identity list response unwrapping (API returns membership wrappers with nested identity objects)
- Project response key handling (`project` vs `workspace` depending on Infisical version)
- `Set-InfisicalSessionToken` strict mode error when auth response lacks `expiresIn`
- Token expiry extracted from JWT `exp` claim for email/password auth

## [0.3.0] - 2026-03-16

### Added

- `Get-InfisicalIdentity`, `New-InfisicalIdentity`, `Set-InfisicalIdentity`, `Remove-InfisicalIdentity` — full machine identity CRUD
- `Add-InfisicalIdentityAuth`, `Get-InfisicalIdentityAuth`, `Remove-InfisicalIdentityAuth` — attach/detach auth methods
- `New-InfisicalClientSecret`, `Get-InfisicalClientSecret`, `Remove-InfisicalClientSecret` — manage client secrets
- `Get-InfisicalIdentityMembership` — list identity's project memberships
- `New-InfisicalProject`, `Remove-InfisicalProject` — project create/delete
- `Get-InfisicalProjectMember`, `Add-InfisicalProjectMember`, `Remove-InfisicalProjectMember`, `Set-InfisicalProjectMember` — project membership management
- `Get-InfisicalProjectRole`, `New-InfisicalProjectRole`, `Remove-InfisicalProjectRole` — custom role management
- `New-InfisicalEnvironment`, `Set-InfisicalEnvironment`, `Remove-InfisicalEnvironment` — environment CRUD
- 412 unit tests

## [0.2.0] - 2026-03-15

### Added

- Migrated all secret endpoints from /api/v3 to /api/v4
- New secret parameters: `-TagIds`, `-Metadata`, `-ReminderRepeatDays`, `-ReminderNote`, `-Type`, `-NewName`, `-ExpandSecretReferences`, `-IncludeImports`, `-TagSlugs`, `-MetadataFilter`
- 7 additional auth methods on `Connect-Infisical`: AWS, Azure, GCP, Kubernetes, OIDC, JWT, LDAP (10 total)
- Server API version detection during connect
- `Get-InfisicalFolder`, `New-InfisicalFolder`, `Set-InfisicalFolder`, `Remove-InfisicalFolder` — folder management
- `Get-InfisicalTag`, `New-InfisicalTag`, `Set-InfisicalTag`, `Remove-InfisicalTag` — tag management
- `Get-InfisicalSecretImport`, `New-InfisicalSecretImport`, `Set-InfisicalSecretImport`, `Remove-InfisicalSecretImport` — secret imports
- `New-InfisicalSecretBulk`, `Set-InfisicalSecretBulk`, `Remove-InfisicalSecretBulk` — bulk secret operations
- `Get-InfisicalEnvironment` — list project environments
- `Get-InfisicalProject` — list projects or get by ID
- 168 unit tests

## [0.1.0] - 2026-03-02

### Added

- `Connect-Infisical` — authenticate via Universal Auth, static token, or pre-obtained access token
- `Disconnect-Infisical` — clear session state with ShouldProcess support
- `Get-InfisicalSecret` — retrieve a single secret by name with `-Raw` option
- `Get-InfisicalSecrets` — list all secrets with `-Filter`, `-Recursive`, and `-AsHashtable` support
- `New-InfisicalSecret` — create secrets with SecureString or plaintext values
- `Set-InfisicalSecret` — update existing secrets with version tracking
- `Remove-InfisicalSecret` — delete secrets with pipeline support and High confirm impact
- `Get-InfisicalSecretVersion` — list secret version history
- SecureString-first design for all secret values
- Automatic token refresh for Universal Auth sessions
- Exponential backoff retry on rate limiting (429)
- `PSInfisical.Extension` nested module — Microsoft.PowerShell.SecretManagement vault extension
- `Get-Secret`, `Set-Secret`, `Remove-Secret`, `Get-SecretInfo`, `Test-SecretVault` via SecretManagement
- Session caching per vault name for efficient multi-vault scenarios
- Support for multiple vault registrations (different projects, environments, or folder paths)
- `Set-Secret` upsert behavior (creates if missing, updates if exists)
- Full Pester 5 unit test suite (116 tests including extension tests)
- Integration tests for extension functions against live Infisical
- PSScriptAnalyzer compliance
- InvokeBuild build script
- Comprehensive documentation with examples
