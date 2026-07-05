# ADR-014: Type System and Developer Tooling

**Status:** Accepted  
**Version:** 1.0  
**Owner:** Architecture  
**Created:** 2026-07-04  
**Contributors:** Architecture Team

---

## Context

DCE reached a point where maintaining a clean architecture is more valuable than adding gameplay features. The codebase needed:

1. Proper type declarations for LuaLS IntelliSense
2. Clear separation between runtime code and type declarations
3. Documentation for developers and AI coding assistants
4. A predictable foundation for future contributors

Before this ADR, type hints were scattered:
- In `globals.lua` mixed with runtime compatibility code
- Inline in implementation files
- Missing entirely for FiveM/Citizen APIs

This created inconsistent developer experience and warnings that obscured real issues.

---

## Decision

### 1. Type Declaration Layer Location

**Decision:** All DCE type declarations live in `DCE/src/types/`

This directory contains **declarations only** - no runtime logic. This separation:
- Keeps implementation files clean
- Provides single source of truth for types
- Allows editors to load types as workspace libraries

**File organization (hierarchical):**
| Directory/File | Purpose |
|----------------|---------|
| `runtime/citizen.lua` | Citizen FX runtime APIs |
| `runtime/fivem.lua` | FiveM native APIs |
| `framework/core.lua` | DCEFramework (core runtime API) |
| `framework/sdk.lua` | DCEPluginSDK (plugin registration API) |
| `services/base.lua` | IService base interface |
| `services/logger.lua` | ILogger interface |
| `services/registry.lua` | IRegistry interface |
| `services/scheduler.lua` | IScheduler interface |
| `services/eventbus.lua` | IEventBus interface |
| `services/plugin-manager.lua` | IPluginManager interface |
| `domains/organizations.lua` | Organization/Organizations domain |
| `domains/dispatch.lua` | Dispatch domain |
| `domains/evidence.lua` | Evidence domain |
| `domains/scenario.lua` | Scenario domain |
| `domains/world.lua` | World domain |
| `domains/admin.lua` | Admin domain |
| `models/region.lua` | Region model types |
| `models/organization.lua` | Organization entity types |
| `models/dispatch-call.lua` | DispatchCallSummary types |
| `events/envelope.lua` | Event envelope format |
| `events/organization.lua` | Organization event payloads |
| `events/dispatch.lua` | Dispatch event payloads |
| `events/evidence.lua` | Evidence event payloads |
| `events/scenario.lua` | Scenario event payloads |
| `events/world.lua` | World event payloads |
| `events/sdk.lua` | SDK registration event payloads |
| `adapters/dispatch.lua` | IDispatchAdapter interface |
| `adapters/evidence.lua` | IEvidenceAdapter interface |
| `adapters/mdt.lua` | IMDTAdapter interface |
| `adapters/analytics.lua` | IAnalyticsAdapter interface |
| `adapters/scenario.lua` | IScenarioAdapter interface |

**Compatibility shims (flat files for backward compatibility):**
Flat files in `DCE/src/types/*.lua` re-export hierarchical types and will be deprecated after migration.

### 2. globals.lua is Runtime Compatibility Only

**Decision:** `DCE/src/dce-core/shared/globals.lua` contains ONLY:
- `Config` global declaration (required for FiveM shared_scripts)
- `DCE` global declaration (required for cross-resource access)
- Minimal diagnostic suppressions

All other declarations moved to `DCE/src/types/`.

### 3. Single .luarc.json Configuration

**Decision:** Exactly one `.luarc.json` exists at repository root.

```json
{
    "runtime": { "version": "Lua 5.4" },
    "workspace": {
        "library": ["DCE/src/types"]
    },
    "diagnostics": {
        "globals": ["fx_version", "game", ...]
    }
}
```

This prevents conflicting configurations across resources.

### 4. Interface Naming Convention

**Decision:** All interfaces use `I` prefix:
- `IService` - Base service interface
- `IWorldService`, `IOrganizationService`, `IDispatchService`, etc.
- `ILogger`, `IRegistry`, `IEventBus`, `IScheduler`

This follows TypeScript/C# convention and makes it clear what is an interface vs. a concrete type.

### 5. LuaLS Compatibility as Architectural Concern

**Decision:** Zero-warning policy for type declarations.

- All real globals must be declared
- All service interfaces must have complete method signatures
- All return types must match runtime behavior
- No diagnostic suppression for "I don't know how to type this"

This ensures contributors get immediate feedback on API usage.

---

## Consequences

### Positive

- Developers get accurate IntelliSense without opening implementation files
- Hover documentation works consistently across the codebase
- New services have a clear template for type declarations
- AI coding assistants (Copilot, Cline, Claude Code, Cursor, Gemini CLI) can understand DCE APIs
- No false-positive warnings obscure real issues

### Negative

- Slight indirection for contributors unfamiliar with EmmyLua annotations
- Additional files to maintain when adding new APIs
- Types must be updated when APIs change

### Mitigations

- `DeveloperTooling.md` explains the type system
- ADR documents the architectural decision
- Types are simple declarations - no logic to maintain

---

## Implementation Checklist

- [x] Create `DCE/src/types/` directory
- [x] Create `framework.lua` with DCE global declarations
- [x] Create `citizen.lua` with Citizen APIs
- [x] Create `fivem.lua` with FiveM natives
- [x] Create `services.lua` with core interfaces
- [x] Create domain-specific type files
- [x] Clean up `globals.lua` to runtime-only
- [x] Update `.luarc.json` configuration
- [x] Create `DeveloperTooling.md`
- [x] Create this ADR

---

## References

- Event Catalog v1: `architecture/Event_Catalog_v1.md`
- Plugin SDK: `docs/03_Core/Plugin_SDK.md`
- Architecture Audit Report: `docs/19_Development/Architecture_Audit_Report.md`