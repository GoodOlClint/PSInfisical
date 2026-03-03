# Changelog

All notable changes to PSInfisical will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Full Pester 5 unit test suite
- PSScriptAnalyzer compliance
- InvokeBuild build script
- Comprehensive documentation with examples
