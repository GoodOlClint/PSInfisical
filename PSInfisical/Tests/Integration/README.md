# PSInfisical Integration Tests

Integration tests that run against a real self-hosted Infisical instance via Docker Compose.

## Prerequisites

- **Docker Desktop** (or Docker Engine + Docker Compose v2 plugin)
- **PowerShell 5.1+** (or PowerShell 7+)
- **Pester 5.x** (`Install-Module Pester -MinimumVersion 5.0 -Force`)
- **InvokeBuild** (`Install-Module InvokeBuild -Force`)

## First-Time Setup

1. Copy the example environment file and fill in values:

   ```powershell
   Copy-Item Tests/Integration/.env.example Tests/Integration/.env
   ```

   The defaults in `.env.example` work out of the box for local testing — you only
   need to copy it. Customize if you need different ports or credentials.

2. Generate real secrets for production-like testing (optional):

   ```bash
   # Generate ENCRYPTION_KEY (32 hex chars)
   openssl rand -hex 16

   # Generate AUTH_SECRET (base64)
   openssl rand -base64 32
   ```

## How to Run

### Via InvokeBuild (recommended)

```powershell
Invoke-Build Test-Integration -File PSInfisical.build.ps1
```

This will:
1. Start the Docker Compose environment
2. Bootstrap Infisical (create admin, project, machine identity)
3. Run all integration tests
4. Tear down the environment (always, even on failure)
5. Output results to `output/TestResults-Integration.xml`

### Manually

```powershell
# Start the environment
./Tests/Integration/Start-IntegrationEnvironment.ps1

# Run tests (env vars are set by the startup script)
Invoke-Pester ./Tests/Integration/ -Tag 'Integration' -Output Detailed

# Tear down
./Tests/Integration/Stop-IntegrationEnvironment.ps1
```

## Environment Variables

The startup script sets these automatically after bootstrapping. If running tests
manually against an existing instance, set them yourself:

| Variable | Description | Default |
|---|---|---|
| `INFISICAL_TEST_URL` | Base URL of the local Infisical instance | `http://localhost:8080` |
| `INFISICAL_TEST_PROJECT_ID` | Project ID to test against | Set by bootstrap |
| `INFISICAL_TEST_CLIENT_ID` | Machine identity client ID | Set by bootstrap |
| `INFISICAL_TEST_CLIENT_SECRET` | Client secret (plaintext) | Set by bootstrap |
| `MOCK_429_URL` | URL of the 429 mock server | `http://localhost:8429` |

If any required variable is missing, the test suite skips with a clear message
rather than failing with a cryptic error.

## Architecture

### Docker Compose Services

| Service | Image | Purpose |
|---|---|---|
| `db` | `postgres:14-alpine` | Database (tmpfs — ephemeral) |
| `redis` | `redis:7-alpine` | Cache/queue (tmpfs — ephemeral) |
| `infisical` | `infisical/infisical:latest-postgres` | Infisical API + UI |
| `mock-429` | `openresty/openresty:alpine` | Mock server for 429 retry testing |

### Ephemeral Data

Every run starts from a clean state. PostgreSQL and Redis use `tmpfs` mounts
instead of named volumes, so all data is lost when containers stop.
`docker compose down -v` (called by `Stop-IntegrationEnvironment.ps1`) removes
any remaining volumes.

### Bootstrap Process

`Start-IntegrationEnvironment.ps1` automates the full bootstrap:

1. Starts Docker Compose services and waits for health checks
2. Calls `POST /api/v1/admin/bootstrap` to create the first admin user and org
3. Creates a project via `POST /api/v1/projects`
4. Creates a machine identity via `POST /api/v1/identities`
5. Attaches Universal Auth via `POST /api/v1/auth/universal-auth/identities/{id}`
6. Creates a client secret via `POST /api/v1/auth/universal-auth/identities/{id}/client-secrets`
7. Grants project membership via `POST /api/v1/projects/{id}/memberships/identities/{id}`
8. Exports `INFISICAL_TEST_*` environment variables for the current session

This mirrors the flow in the homelab Ansible bootstrap playbook.

### 429 Retry Testing

The unit tests in `Tests/Unit/Invoke-InfisicalApi.Tests.ps1` cannot construct
a real `HttpWebResponse` with status code 429 — the constructors are
internal/protected in .NET. The integration test solves this with an OpenResty
(nginx + Lua) mock container that:

- Returns `429 Too Many Requests` for the first 2 requests to any `/api/*` path
- Returns `200 OK` with a valid JSON response on the 3rd request
- Exposes `/reset` to zero the counter between tests
- Exposes `/health` for Docker health checks

This proves `Invoke-InfisicalApi`'s exponential backoff retry loop works
end-to-end over real HTTP.

## Test Files

| File | Covers |
|---|---|
| `Invoke-InfisicalApi.Integration.Tests.ps1` | 429 retry, 404, 401, 403, 5xx error paths |
| `Connect-Infisical.Integration.Tests.ps1` | UniversalAuth, Token, AccessToken, invalid credentials |
| `Secrets.Integration.Tests.ps1` | Full CRUD lifecycle, versioning, pipeline support |
| `PSInfisical.Extension.Integration.Tests.ps1` | SecretManagement vault extension CRUD, Get-SecretInfo, Test-SecretVault |

## Troubleshooting

**Containers won't start**: Check `docker compose logs` from the `Tests/Integration/` directory.

**Bootstrap fails with "already bootstrapped"**: Run `Stop-IntegrationEnvironment.ps1`
first to wipe state, then re-run `Start-IntegrationEnvironment.ps1`.

**Tests skip with "environment variables not set"**: Run `Start-IntegrationEnvironment.ps1`
in the same PowerShell session before running Pester.

**Port conflicts**: Edit `.env` to change `INFISICAL_PORT` or `MOCK_429_PORT`.
