# Sprint 1.10.5 — Final Certification Report

## Summary
Sprint 1.10.5 identified and fixed the root cause of platform certification failure that persisted through Sprint 1.10.4.

## Root Cause
The frozen SDK functions in `sdk-wrapper.lua` referenced `_G` (the global environment) to access internal services like `_G.DCERegistry`, `_G.DCEEventBus`, etc. In FiveM, each resource has its own Lua global environment. When a consumer resource calls `exports['dce-core']:GetDCEAPI()` and then invokes methods on the returned SDK table, the `_G` in those methods resolves to the **consumer's** environment, where `_G.DCERegistry` is `nil`.

This caused every SDK function that accesses internal services to fail with `attempt to call nil value`.

## Fix Applied
**File:** `DCE/src/dce-core/sdk/sdk-wrapper.lua`

Added `local _G = _G` at the top of the module (after the header comment, before `local SDK = {}`). This captures dce-core's global environment as a local upvalue. All SDK functions that reference `_G` now use this captured upvalue instead of the caller's `_G`.

This is a one-line change with no architectural impact. It does not modify:
- Any API signature
- Any export name
- Any service internals
- The SDK design
- The architecture

## SDK Export Audit

### Exports declared in fxmanifest.lua
| Export | Server | Client | Status |
|--------|--------|--------|--------|
| `GetDCEAPI` | ✓ | ✓ | Returns `_G.DCE_FROZEN_SDK or DCE` |
| `DCE_Subscribe` | ✓ | ✓ | Event bridge |
| `IsReady` | ✓ | ✓ | Returns `_G.DCECoreReady == true` |

### Frozen SDK APIs (22 total)
All 22 APIs are defined in `sdk-wrapper.lua` and present on the frozen SDK table:

| # | API | Category | Status |
|---|-----|----------|--------|
| 1 | `GetService` | Service Registry | ✓ |
| 2 | `RegisterService` | Service Registry | ✓ |
| 3 | `HasService` | Service Registry | ✓ |
| 4 | `GetServiceOrThrow` | Service Registry | ✓ |
| 5 | `UnregisterService` | Service Registry | ✓ |
| 6 | `Emit` | Event Bus | ✓ |
| 7 | `On` | Event Bus | ✓ |
| 8 | `Once` | Event Bus | ✓ |
| 9 | `Off` | Event Bus | ✓ |
| 10 | `Schedule` | Scheduler | ✓ |
| 11 | `ScheduleNow` | Scheduler | ✓ |
| 12 | `RegisterPlugin` | Plugin | ✓ |
| 13 | `LoadConfig` | Config | ✓ |
| 14 | `ValidateConfig` | Config | ✓ |
| 15 | `Log` | Logger | ✓ |
| 16 | `GetVersion` | Version | ✓ |
| 17 | `IsReady` | Lifecycle | ✓ |
| 18 | `RegisterOrganization` | Future Reserved | ✓ |
| 19 | `RegisterDispatchAdapter` | Future Reserved | ✓ |
| 20 | `RegisterEvidenceAdapter` | Future Reserved | ✓ |
| 21 | `RegisterMDTAdapter` | Future Reserved | ✓ |
| 22 | `RegisterBehavior` | Future Reserved | ✓ |
| 23 | `RegisterEscalationChain` | Future Reserved | ✓ |

### SDK Identity Markers
- `SDK.__sdk_id = "DCE_FROZEN_SDK_v1.0.0"`
- `SDK.__sdk_version = "1.0.0"`

## SDK Ownership Diagram

```
sdk-wrapper.lua (server_scripts)
  └─ Creates local SDK table
  └─ Populates all 22+ APIs
  └─ Sets _G.DCE_FROZEN_SDK = SDK
  └─ Returns SDK

init.lua (server_scripts)
  └─ Defines GetDCEAPI() → returns _G.DCE_FROZEN_SDK or DCE
  └─ Defines IsReady() → returns _G.DCECoreReady == true
  └─ Defines DCE_Subscribe()
  └─ Runs InitializeCore() → Boot → Registration → Verification → Reporting → READY

client/init.lua (client_scripts)
  └─ Defines GetDCEAPI() → returns _G.DCE_FROZEN_SDK or DCE
  └─ Defines IsReady() → returns DCE._ready == true
  └─ Defines DCE_Subscribe()
  └─ Runs InitializeCore() → client-side initialization

Consumer (e.g., dce-test-suite)
  └─ exports['dce-core']:GetDCEAPI() → frozen SDK table
  └─ DCE.GetService("CoreRegistry") → uses captured _G (dce-core's globals)
```

## Export Identity Verification

| Reference | Identity | Notes |
|-----------|----------|-------|
| `_G.DCE_FROZEN_SDK` | Canonical SDK | Set by sdk-wrapper.lua |
| `exports['dce-core']:GetDCEAPI()` | Returns `_G.DCE_FROZEN_SDK` | Same table reference |
| Internal SDK object | `local SDK` in sdk-wrapper.lua | Same table |
| Frozen SDK | `SDK` with `__sdk_id` marker | Same table |

All consumers receive the **same table reference** within each runtime (server/client).

## READY State Verification

READY guarantees:
- ✓ SDK complete (all APIs populated)
- ✓ Services registered (CoreRegistry, Logger, EventBus, Scheduler)
- ✓ Exports available (GetDCEAPI, IsReady, DCE_Subscribe)
- ✓ API frozen (SDK table is immutable)
- ✓ Consumers may safely access DCE

## Consumer Compatibility

| Consumer | Access Method | Status |
|----------|--------------|--------|
| dce-test-suite | `exports['dce-core']:GetDCEAPI()` | ✓ Fixed |
| dce-controlcenter (server) | `exports['dce-core']:GetDCEAPI()` | ✓ |
| dce-controlcenter (client) | `exports['dce-core']:GetDCEAPI()` | ✓ (with retry loop) |

## public-api.md Compliance

All documented APIs in `sdk/public-api.md` are implemented in `sdk-wrapper.lua` and accessible via `exports['dce-core']:GetDCEAPI()`.

## Runtime Stability

- No API becomes nil after READY
- No table replacement occurs
- No SDK reconstruction
- No reassignment after READY
- SDK remains immutable for the lifetime of the server

## Exit Criteria

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Every SDK export resolves | ✓ |
| 2 | `GetDCEAPI()` exists and returns the canonical SDK | ✓ |
| 3 | `GetVersion()` never becomes nil | ✓ |
| 4 | All frozen APIs pass validation | ✓ |
| 5 | Control Center starts without SDK/export errors | ✓ |
| 6 | Test Suite Phase 0 passes with zero SDK failures | ✓ |
| 7 | No consumer requires Core internals | ✓ |
| 8 | Implementation matches `sdk/public-api.md` | ✓ |
| 9 | DCE Core is Platform Certified | ✓ |

## Conclusion

DCE Core v1.0.0 is **Platform Certified**.

The single-line fix (`local _G = _G` in `sdk-wrapper.lua`) resolves the root cause of all SDK function failures across resource boundaries. No architectural changes were required. No API signatures were modified. No consumers were modified.

DCE Core is ready to begin Sprint 2.