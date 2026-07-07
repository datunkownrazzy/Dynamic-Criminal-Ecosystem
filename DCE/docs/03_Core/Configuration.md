# DCE Configuration Reference

**Status:** Accepted
**Version:** 1.0
**Owner:** Architecture
**Applies To:** All DCE resources

---

## Purpose

This document provides the authoritative reference for all DCE configuration options. Every configuration value is documented with its purpose, default value, allowed values, and impact on the system.

Configuration follows the principle: **All tunable values live in Config, never hardcoded in logic.**

---

## Core Configuration

Located in `dce-core/config.lua`, these are the base configuration values:

### Logger Settings

| Config Path | Type | Default | Description | Hot Reload |
|---|---|---|---|---|
| `Config.Logger.Level` | `"debug" \| "info" \| "warn" \| "error" \| "off"` | `"info"` | Minimum log level to output | Yes |
| `Config.Logger.Format` | string | `"[${module}] ${message}"` | Log message format template | No |
| `Config.Logger.Timestamps` | boolean | `true` | Include timestamps in log output | Yes |

### Scheduler Settings

| Config Path | Type | Default | Description | Hot Reload |
|---|---|---|---|---|
| `Config.Scheduler.MaxTasks` | number | `128` | Maximum scheduled tasks across all services | No |
| `Config.Scheduler.DefaultInterval` | number (ms) | `60000` | Default interval if not specified | No |
| `Config.Scheduler.ErrorCooldown` | number (ms) | `10000` | Cooldown after 3 consecutive errors | Yes |

### Registry Settings

| Config Path | Type | Default | Description | Hot Reload |
|---|---|---|---|---|
| `Config.Registry.AllowOverrides` | boolean | `true` | Allow plugins to override services | No |
| `Config.Registry.LogRegistrations` | boolean | `true` | Log every service registration/unregistration | Yes |

### Plugin Manager Settings

| Config Path | Type | Default | Description | Hot Reload |
|---|---|---|---|---|
| `Config.PluginManager.Enabled` | boolean | `true` | Enable plugin system | No |
| `Config.PluginManager.FailOnMissingDependency` | boolean | `true` | Reject plugins with unmet dependencies | No |
| `Config.PluginManager.FailOnVersionMismatch` | boolean | `true` | Reject plugins with incompatible DCE version | No |

### Performance Budget Settings

| Config Path | Type | Default | Description | Hot Reload |
|---|---|---|---|---|
| `Config.Performance.IdleBudget` | number (ms) | `0.10` | CPU budget for idle server | Yes |
| `Config.Performance.RPBudget` | number (ms) | `0.75` | Budget for typical RP server | Yes |
| `Config.Performance.HeavyBudget` | number (ms) | `1.5` | Budget during heavy criminal activity | Yes |
| `Config.Performance.MaxBudget` | number (ms) | `2.5` | Absolute maximum before hard throttle | Yes |
| `Config.Performance.AlertThreshold` | number | `1.25` | Warn when approaching max budget | Yes |
| `Config.Performance.ProfilerEnabled` | boolean | `true` | Enable/disable profiler collection | Yes |
| `Config.Performance.MaxHistorySize` | number | `600` | Max metrics history entries | Yes |

### Per-Service CPU Budgets

| Config Path | Type | Default | Description |
|---|---|---|---|
| `Config.SimulationBudget.Scheduler` | number (ms) | `0.05` | Scheduler tick budget |
| `Config.SimulationBudget.AI` | number (ms) | `0.40` | AI Director budget |
| `Config.SimulationBudget.Dispatch` | number (ms) | `0.20` | Dispatch service budget |
| `Config.SimulationBudget.Evidence` | number (ms) | `0.15` | Evidence service budget |
| `Config.SimulationBudget.Economy` | number (ms) | `0.25` | Economy service budget |
| `Config.SimulationBudget.Weather` | number (ms) | `0.02` | Weather simulation budget |
| `Config.SimulationBudget.Organizations` | number (ms) | `0.30` | Organizations service budget |

### AI Update Frequencies

| Config Path | Type | Default | Description |
|---|---|---|---|
| `Config.AIUpdateFrequencies.Critical` | number (ms) | `250` | Active incidents, heat spikes |
| `Config.AIUpdateFrequencies.Nearby` | number (ms) | `500` | Organizations near players |
| `Config.AIUpdateFrequencies.Active` | number (ms) | `1000` | Normal operation |
| `Config.AIUpdateFrequencies.Passive` | number (ms) | `5000` | Idle but not dormant |
| `Config.AIUpdateFrequencies.Dormant` | number (ms) | `30000` | Sleep until event |

### Cache Defaults

| Config Path | Type | Default | Description |
|---|---|---|---|
| `Config.Cache.DefaultTTL` | number (seconds) | `300` | 5 minutes default TTL |
| `Config.Cache.DefaultMaxSize` | number | `1000` | Default max entries per cache |
| `Config.Cache.EvictionPolicy` | `"lru" \| "fifo" \| "random"` | `"lru"` | Entry eviction strategy |

### Pool Defaults

| Config Path | Type | Default | Description |
|---|---|---|---|
| `Config.Pool.DefaultMaxSize` | number | `100` | Maximum pool size |
| `Config.Pool.DefaultGrowIncrement` | number | `10` | Grow increment when exhausted |

---

## Resource-Specific Configuration

### Admin Configuration (`dce-admin/config.lua`)

| Config Path | Type | Default | Description | Hot Reload |
|---|---|---|---|---|
| `Config.Admin.PermissionCheck` | function | See below | Admin permission check function | Yes |
| `Config.Admin.Dashboard.Enabled` | boolean | `true` | Enable dashboard | Yes |
| `Config.Admin.Dashboard.RefreshInterval` | number (ms) | `5000` | Dashboard refresh rate | Yes |
| `Config.Admin.DebugConsole.Enabled` | boolean | `true` | Enable debug console | Yes |
| `Config.Admin.DebugConsole.MaxHistorySize` | number | `100` | Max console history entries | Yes |
| `Config.Admin.PerformanceMonitor.Enabled` | boolean | `true` | Enable performance monitoring | Yes |
| `Config.Admin.PerformanceMonitor.WarningThreshold` | number | `80` | Warning at % of budget | Yes |
| `Config.Admin.AuditLog.Enabled` | boolean | `true` | Enable audit logging | Yes |
| `Config.Admin.AuditLog.MaxEntries` | number | `1000` | Max audit log entries | Yes |
| `Config.Admin.ConfigRuntime.Enabled` | boolean | `true` | Allow runtime config changes | Yes |
| `Config.Admin.Keybind.Enabled` | boolean | `true` | Enable keybind | Yes |
| `Config.Admin.Keybind.Key` | string | `"KC_LMENU + K"` | Open keybind | Yes |

**Default Permission Check:**
```lua
Config.Admin.PermissionCheck = function(source)
    if source == nil then return false end
    return IsPlayerAceAllowed(source, "group.admin") or 
           IsPlayerAceAllowed(source, "group.superadmin") or 
           IsPlayerAceAllowed(source, "command.dce")
end
```

### World Configuration (referenced in `dce-world/init.lua`)

| Config Path | Type | Default | Description |
|---|---|---|---|
| `Config.World.Layer0Interval` | number (ms) | `30000` | Layer 0 tick interval |
| `Config.World.Layer1Interval` | number (ms) | `5000` | Layer 1 tick interval |
| `Config.World.Time.Enabled` | boolean | - | Time simulation enabled |
| `Config.World.Time.TickInterval` | number (ms) | - | Time tick rate |
| `Config.World.Weather.Enabled` | boolean | - | Weather simulation enabled |
| `Config.World.Weather.TickInterval` | number (ms) | - | Weather tick rate |

### Dispatch Configuration (referenced in `dce-dispatch/init.lua`)

| Config Path | Type | Default | Description |
|---|---|---|---|
| `Config.Dispatch.Integration.Mode` | `"native" \| "ers" \| "custom"` | `"native"` | Dispatch adapter mode |
| `Config.Dispatch.Integration.ResourceName` | string | `"ers"` | ERS resource name override |
| `Config.Dispatch.Integration.Adapter` | table | - | Custom adapter reference |

### Evidence Configuration (referenced in `dce-evidence/services/evidence.lua`)

| Config Path | Type | Default | Description |
|---|---|---|---|
| `Config.Evidence.Integration.Mode` | `"native" \| "ers" \| "custom"` | `"native"` | Evidence adapter mode |
| `Config.Evidence.Integration.EnableStandaloneFallback` | boolean | `true` | Fall back to native if ERS unavailable |

### AI Configuration (referenced in `dce-ai/init.lua`)

| Config Path | Type | Default | Description |
|---|---|---|---|
| `Config.AI.DirectorTickInterval` | number (ms) | `5000` | AI Director evaluation interval |

---

## FiveM Integration

### Resource Dependencies

All DCE resources declare `dce-core` as a dependency in their `fxmanifest.lua`. FiveM will load them in the correct order.

### Configuration Loading

Configuration is loaded via `shared_scripts` in fxmanifest.lua, making it available to both client and server:

```lua
shared_scripts {
    'config.lua',
}
```

### Global Configuration

The configuration table is exposed globally via `_G.Config`:

```lua
local Config = _G.Config or {}
local setting = Config.SomeModule and Config.SomeModule.SomeSetting
```

---

## Admin UI Configuration

The Admin service can modify configuration at runtime through the Admin UI. Changes are applied immediately and logged:

```lua
-- Example: Updating world tick interval
DCE.UpdateConfig("dce-world", "Layer0Interval", 25000)
```

Configuration changes that affect running systems should trigger appropriate adjustments (rescheduling, cache clearing, etc.).

---

## Plugin Configuration

Plugins may extend configuration by registering their own config sections:

```lua
-- In plugin startup
Config.MyPlugin = Config.MyPlugin or {
    Enabled = true,
    CustomValue = 100,
}
```

Plugin configuration changes follow the same hot-reload rules as core configuration.

---

## Deprecated Configuration Paths

| Old Path | New Path | Deprecated In |
|----------|----------|---------------|
| None | All paths are current | N/A |

---

## Configuration Validation

Currently, there is no runtime configuration validation. Invalid values are handled defensively in code. Future versions will include:

- Schema-based validation
- Range checking
- Type coercion
- Default value application