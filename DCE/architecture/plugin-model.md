# Plugin Architecture — Sprint 1.9 Freeze

**Version:** 1.0.0
**Status:** FROZEN

## Plugin Lifecycle

```
UNKNOWN → DISCOVERED → VALIDATED → RESOLVED → LOADING → INITIALIZED → READY
                                                                           ↓
                                                                      SHUTDOWN
                                                                           ↓
                                                                      UNLOADED
                                                                      FAILED
```

## Required Manifest Fields

| Field | Type | Description |
|-------|------|-------------|
| name | string | Unique plugin name |
| version | string | Semver version |
| description | string | Human-readable description |
| author | string | Plugin author |

## Optional Manifest Fields

| Field | Type | Description |
|-------|------|-------------|
| dependencies | table | List of plugin dependencies |
| capabilities | table | List of capabilities this plugin provides |
| sdkVersion | string | Required SDK version |
| runtime | string | "server" \| "client" \| "shared" |
| interfaces | table | Interfaces this plugin implements |

## Capability Discovery

Plugins can be discovered by capability:
- `PluginArchitecture.DiscoverByCapability(capability)` — returns all plugins with a given capability
- `PluginArchitecture.ListCapabilities()` — returns all available capabilities

## Version Compatibility

Plugin SDK version is validated against DCE.GetVersion() at registration time.
Mismatch prevents the plugin from reaching VALIDATED state.

## Dependency Resolution

Dependencies are resolved at the RESOLVED stage:
- Dependencies must be in READY or INITIALIZED state
- Unresolved dependencies prevent transition to LOADING
- Circular dependencies are detected and rejected

## No Plugins Required

The architecture is complete and frozen. No plugins need to exist.
Future plugins can be built against this architecture without modification.