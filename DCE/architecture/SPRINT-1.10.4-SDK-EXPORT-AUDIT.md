# Sprint 1.10.4 — SDK Export Audit

## Summary
The SDK export architecture is fundamentally sound but had a critical identity divergence between server and client runtimes. One consumer file lacked a retry loop. The test suite was missing two API validations.

## Root Cause Analysis

### Problem 1: Client GetDCEAPI Returned the Wrong Table
| Runtime | File | GetDCEAPI Returned | Should Return |
|---------|------|-------------------|---------------|
| Server | `dce-core/init.lua` | `_G.DCE_FROZEN_SDK or DCE` | Frozen SDK ✓ |
| Client | `dce-core/client/init.lua` | `DCE` (local mutable table) | Frozen SDK ✗ |

The client-side `GetDCEAPI()` used `return DCE` which returned the local mutable DCE table, NOT the frozen SDK stored in `_G.DCE_FROZEN_SDK`. This caused consumers getting the client SDK to receive a DIFFERENT table than consumers getting the server SDK. While FiveM's per-resource globals prevent direct sharing, the identity marker check (`__sdk_id`) would have caught this.

**Fix:** Changed to `return _G.DCE_FROZEN_SDK or DCE` — identical pattern to server-side.

### Problem 2: Test Suite Missing 2 of 22 Frozen APIs
| API | public-api.md | Test Suite |
|-----|--------------|------------|
| `DCE.UnregisterService` | ✓ Documented | ✗ Missing |
| `DCE.IsReady` | ✓ Documented | ✗ Missing |

The test harness validated only 20 of the 22 frozen SDK APIs.

**Fix:** Added `UnregisterService` and `IsReady` to the test harness validation.

### Problem 3: Control Center Client Lacked Retry Loop
`dce-controlcenter/client/init.lua` called `ConnectToCore()` once synchronously. If `dce-core` hadn't initialized yet, DCE remained nil forever. The server-side `init.lua` already has a retry loop.

**Fix:** Added `WaitForCore()` with Citizen.Wait(100) up to 50 attempts.

### Problem 4: No SDK Identity Marker
No way to verify consumers received the same SDK instance.

**Fix:**
- Added `SDK.__sdk_id = "DCE_FROZEN_SDK_v1.0.0"` to the frozen SDK
- Added `SDK.__sdk_version = "1.0.0"`
- Added runtime validation in `init.lua` READY phase that verifies `GetDCEAPI()` === `_G.DCE_FROZEN_SDK`

## Files Modified
1. `DCE/src/dce-core/sdk/sdk-wrapper.lua` — Added identity markers
2. `DCE/src/dce-core/init.lua` — Added SDK identity validation in READY phase, fixed GetDCEAPI() (already correct)
3. `DCE/src/dce-core/client/init.lua` — Fixed GetDCEAPI() to return frozen SDK
4. `DCE/src/dce-controlcenter/client/init.lua` — Added retry loop for ConnectToCore()
5. `DCE/src/dce-test-suite/test-harness.lua` — Added UnregisterService and IsReady to validation

## No Changes To
- Architecture
- SDK design
- API surface
- Export signatures
- Service internals