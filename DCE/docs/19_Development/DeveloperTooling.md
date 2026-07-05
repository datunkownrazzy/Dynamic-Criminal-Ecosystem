# DCE Developer Tooling Guide

**Status:** Active  
**Version:** 1.0  
**Owner:** Architecture

---

## Overview

DCE uses LuaLS (Lua Language Server) for IDE integration, providing IntelliSense, hover documentation, and type checking. This guide explains how the type system is organized and how to work with it effectively.

---

## Type Declaration Architecture

### Directory Structure (Hierarchical)

```
DCE/src/types/
├── index.lua              # Main entry point - loads all types
├── runtime/
│   ├── citizen.lua        # Citizen FX runtime (CreateThread, Wait, etc.)
│   └── fivem.lua          # FiveM natives (RegisterNetEvent, GetEntityCoords, etc.)
├── framework/
│   ├── core.lua           # DCEFramework (core runtime API)
│   └── sdk.lua            # DCEPluginSDK (plugin registration API)
├── services/
│   ├── base.lua           # IService base interface
│   ├── logger.lua         # ILogger interface
│   ├── registry.lua       # IRegistry interface
│   ├── scheduler.lua      # IScheduler interface
│   ├── eventbus.lua       # IEventBus interface
│   └── plugin-manager.lua # IPluginManager interface
├── domains/
│   ├── organizations.lua  # IOrganizationService interface
│   ├── dispatch.lua       # IDispatchService interface
│   ├── evidence.lua       # IEvidenceService interface
│   ├── scenario.lua       # IScenarioEngine interface
│   ├── world.lua          # IWorldService interface
│   └── admin.lua          # IAdminService interface
├── models/
│   ├── region.lua         # Region model types
│   ├── organization.lua   # Organization entity types
│   └── dispatch-call.lua  # DispatchCallSummary types
├── events/
│   ├── envelope.lua       # DCEEventEnvelope format
│   ├── organization.lua   # Organization event payloads
│   ├── dispatch.lua       # Dispatch event payloads
│   ├── evidence.lua       # Evidence event payloads
│   ├── scenario.lua       # Scenario event payloads
│   ├── world.lua          # World event payloads
│   ├── sdk.lua            # SDK registration event payloads
│   └── admin.lua          # Admin event payloads
├── adapters/
│   ├── dispatch.lua       # IDispatchAdapter interface
│   ├── evidence.lua       # IEvidenceAdapter interface
│   ├── mdt.lua            # IMDTAdapter interface
│   ├── analytics.lua      # IAnalyticsAdapter interface
│   └── scenario.lua       # IScenarioAdapter interface
└── enums/                 # Enum collections (future)
```

**Compatibility shims** in `DCE/src/types/*.lua` re-export hierarchical types for backward compatibility during migration. These will be removed after all modules are updated.

### Declaration Rules

| Allowed | Forbidden |
|---------|-----------|
| `@class` - Interface/class definitions | Business logic |
| `@field` - Field annotations | Event publishing |
| `@type` - Type aliases | Data mutation |
| `@alias` - Literal type aliases | Gameplay logic |
| `@param` / `@return` - Function annotations | Service registration |
| Enums and constants | Runtime code |

---

## LuaLS Configuration

### .luarc.json

The workspace configuration is at the repository root:

```json
{
    "runtime": { "version": "Lua 5.4" },
    "workspace": {
        "library": ["DCE/src/types"]
    },
    "diagnostics": {
        "globals": ["fx_version", "game", "author", ...],
        "unusedLocal": false,
        "unusedFunction": false
    }
}
```

### FiveM Manifest DSL

FiveM manifest keywords (`fx_version`, `game`, etc.) are declared as globals in `.luarc.json`. These are **not** Lua functions - they are processed by the FiveM resource compiler.

### Diagnostic Suppressions

The `globals.lua` file uses `---@diagnostic off/on` blocks for intentional patterns:
- `Config` mutation for shared_scripts merging
- FiveM native globals that exist at runtime

---

## Service Interfaces

All DCE services implement `IService` and are accessed via `DCE.GetService()`:

```lua
-- Get a service
local world = DCE.GetService("World")

-- Use the service interface
local regionState = world.GetRegionState("downtown")
```

### Available Services

| Service Name | Interface | Module |
|--------------|-----------|--------|
| `CoreRegistry` | `ICoreRegistry` | Core introspection |
| `World` | `IWorldService` | World simulation |
| `Organizations` | `IOrganizationService` | Org management |
| `ScenarioEngine` | `IScenarioEngine` | Scenario lifecycle |
| `Dispatch` | `IDispatchService` | Call management |
| `Evidence` | `IEvidenceService` | Evidence tracking |
| `Admin` | `IAdminService` | Admin dashboard |

---

## Adapter Interfaces

Adapters connect DCE to external systems (CAD/MDT, inventory). They follow the Adapter pattern:

```lua
-- Register a dispatch adapter
DCE.RegisterDispatchAdapter({
    Name = "MyCAD",
    Priority = 50,
    CreateCall = function(data)
        -- Create call in external system
    end,
    UpdateCall = function(data)
        -- Update call in external system
    end,
    ResolveCall = function(data)
        -- Close call in external system
    end,
})
```

---

## SDK Registration

Plugins use the SDK registration functions defined in `framework.lua`:

```lua
-- Register organization (in plugin code)
exports.dce:RegisterOrganization({
    id = "my_gang",
    displayName = "My Gang",
    personality = { ... },
})
```

---

## Common Troubleshooting

### "Undefined global" warnings

1. Check if the global is a FiveM native - it should be in `fivem.lua`
2. Check if the global is a DCE service module - it should be declared in the appropriate type file
3. Check if the global is from shared_scripts - FiveM loads these at runtime

### "Missing fields" warnings on tables

DCE uses defensive coding patterns. Functions often return tables with optional fields:

```lua
-- If a field may be nil, use defensive access
local orgState = DCE.GetService("Organizations").GetState("gang") or {}
print(orgState.state or "Unknown")  -- Good
print(orgState.state)               -- May warn if GetState returns {}
```

### Hover documentation not showing

1. Ensure `.luarc.json` is at the repository root
2. Ensure the types directory is listed in `workspace.library`
3. Some editors may need a restart to pick up changes

---

## Adding New Types

When adding a new service, model, or adapter:

1. Add declarations to the appropriate file in `DCE/src/types/`
2. Use `I` prefix for interfaces (`IServiceName`)
3. Include JSDoc-style comments with `@param` and `@return`
4. Update this documentation if adding a new category

---

## Type Version Policy

Type declarations track the **runtime API contract**. Breaking changes to APIs require:
1. An ADR documenting the change
2. Updates to the type declarations
3. Updates to this documentation

Type declarations themselves never break runtime behavior - they are documentation for developers and AI coding assistants.