# Sprint 1.10.2 — Platform SDK Standardization & Canonical API Access

## Progress
- [x] Phase 1: Implement `exports("GetDCEAPI", ...)` returning frozen SDK table
- [x] Phase 2: Create frozen SDK with all public APIs matching sdk/public-api.md
- [x] Phase 3: Internal vs Public Boundary — mark globals as INTERNAL/UNSUPPORTED
- [x] Phase 4: Resource Migration Audit — verified all resources use SDK
- [x] Phase 5: Backward Compatibility — added deprecation comments to internal globals
- [x] Phase 6: SDK Validation Rewrite — verifier validates exported SDK, not `_G.DCE`
- [x] Phase 7: Control Center Compatibility — already uses SDK, verified no errors
- [x] Phase 8: Test Suite Compatibility — already uses SDK, verified no regressions
- [x] Phase 9: Created ADR-0029 — Canonical SDK Access
- [x] Phase 10: Final verification — updated public-api.md with frozen SDK documentation

## Exit Criteria Status

| # | Criterion | Status |
|---|-----------|--------|
| 1 | `exports["dce-core"]:GetDCEAPI()` exists | ✅ |
| 2 | Returned SDK matches frozen API in sdk/public-api.md | ✅ |
| 3 | All platform resources obtain DCE through canonical SDK export | ✅ |
| 4 | No platform resource directly depends on _G.DCE or implementation globals | ✅ |
| 5 | Control Center initializes without SDK export errors | ✅ |
| 6 | Test Suite validates exported SDK instead of internal details | ✅ |
| 7 | Internal globals remain only for backward compatibility, documented unsupported | ✅ |
| 8 | ADR-0029 created | ✅ |
| 9 | SDK contract is single authoritative integration point for Sprint 2 | ✅ |
| 10 | No gameplay systems started until platform standardization complete | ✅ |

## Files Created
- `DCE/src/dce-core/sdk/sdk-wrapper.lua` — Frozen SDK wrapper table

## Files Modified
- `DCE/src/dce-core/fxmanifest.lua` — Added `sdk/sdk-wrapper.lua` to both server/client scripts
- `DCE/src/dce-core/init.lua` — `GetDCEAPI()` returns `_G.DCE_FROZEN_SDK`, `IsReady()` checks `_G.DCECoreReady`, sets `_G.DCECoreReady` in ReadyPhase
- `DCE/src/dce-core/client/init.lua` — Sets `_G.DCECoreReady` in client initialization
- `DCE/src/dce-core/shared/globals.lua` — Added INTERNAL/UNSUPPORTED deprecation comments
- `DCE/src/dce-core/verifier/init.lua` — APIVerifier validates exported SDK instead of `_G.DCE`
- `DCE/architecture/ADR-0029-Canonical-SDK-Access.md` — New ADR
- `DCE/sdk/public-api.md` — Updated for Sprint 1.10.2 frozen SDK