# ADR-0027: DCE Control Center v2 - Administrative Interface Implementation

**Status:** Completed  
**Date:** 2026-07-11  
**Implementation Date:** 2026-07-11
**Author:** Lead Software Architect  
**Dependencies:** ADMINISTRATIVE-INTERFACE-CATALOG.md  

---

## Problem Statement

DCE Control Center v2 services lack standardized administrative interfaces for:
1. Runtime monitoring (status, health, metrics)
2. Configuration inspection
3. Administrative actions (enable, disable, reset, reload, maintenance mode)

This prevents the Server Monitor plugin and other administrative tools from introspecting service state.

## Decision

Implement the Administrative Contract as defined in `ADMINISTRATIVE-INTERFACE-CATALOG.md` on all Control Center services.

### Administrative Contract Methods

Every service implements:

```lua
-- Status Contract
GetStatus() → { state: "running"|"paused"|"error", lastTick: number, uptime: number }

-- Health Contract  
GetHealth() → { healthy: boolean, errorCount: number, lastError: string, errorRate: number }

-- Metrics Contract
GetMetrics() → { domain-specific metrics }

-- Statistics Contract
GetStatistics() → { totalProcessed: number, currentCount: number, peakCount: number }

-- Configuration Contract
GetConfiguration() → { config: table }  -- Returns current config without secrets

-- Capabilities Contract
GetCapabilities() → { admin: boolean, readOnly: boolean, actions: string[] }

-- Administrative Actions Contract
Enable() / Disable() / Reset() / Reload() / MaintenanceMode(enabled)
```

### Services Updated

| Service | File | Administrative Methods Added |
|---------|------|---------------------------|
| PluginRegistry | `server/services/plugin-registry.lua` | Full contract |
| LocationManager | `server/services/location-manager.lua` | Full contract |
| OrganizationEditor | `server/services/organization-editor.lua` | Full contract |
| ControlCenter | `server/services/controlcenter.lua` | Full contract |
| LocationEditor | `server/services/location-editor.lua` | Full contract (editor service) |
| SessionManager | `session/session-manager.lua` | Full contract |
| WorldAdapter (stub) | `server/adapters/world-adapter-stub.lua` | Full contract (for testing) |

### Implementation Notes

1. **State Reporting**: All services return `"running"` state when active
2. **Error Tracking**: Services track `_errorCount` and `_lastError` for health reporting
3. **Metrics**: Domain-specific metrics (plugins count, locations count, etc.)
4. **Graceful Degradation**: Services handle nil EventBus gracefully
5. **No Secrets in Config**: `GetConfiguration()` returns only safe values

## Success Criteria

- [x] All services implement GetStatus()
- [x] All services implement GetHealth()
- [x] All services implement GetMetrics()
- [x] All services implement GetStatistics()
- [x] All services implement GetConfiguration()
- [x] All services implement GetCapabilities()
- [x] All services implement Enable/Disable/Reset/Reload/MaintenanceMode()

## Consequences

- Services can be monitored via Server Monitor plugin
- Administrative tools can query service state
- API consistency across all DCE services
- Foundation for future admin dashboard features