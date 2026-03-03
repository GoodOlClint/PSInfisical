# Disconnect-Infisical

Disconnects from the Infisical API and clears the session.

## Syntax

```powershell
Disconnect-Infisical [-WhatIf] [-Confirm]
```

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| WhatIf | switch | No | Shows what would happen without performing the action |
| Confirm | switch | No | Prompts for confirmation before performing the action |

## Examples

### Example 1: Basic disconnect

```powershell
Disconnect-Infisical
```

Clears the current Infisical session.

### Example 2: Disconnect with confirmation suppressed

```powershell
Disconnect-Infisical -Confirm:$false
```

Clears the session without any confirmation prompt.

### Example 3: Preview disconnect

```powershell
Disconnect-Infisical -WhatIf
```

Shows what would happen without actually clearing the session.

## Notes

- This does not revoke tokens on the server. The access token simply becomes unavailable locally.
- After disconnecting, all secret commands require a new `Connect-Infisical` call.
- Safe to call even when no session exists (no-op).

## Related Commands

- [Connect-Infisical](Connect-Infisical.md)
