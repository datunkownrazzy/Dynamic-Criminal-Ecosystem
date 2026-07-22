# ADR-0029 — Canonical SDK Access

**Status:** ACCEPTED
**Date:** Sprint 1.10.2
**Author:** DCE Architecture Team
**Type:** Architecture Decision Record

---

## Context

The DCE platform has reached Platform Certified status; however, Sprint 1.10 validation exposed a platform-wide architectural inconsistency.

The platform currently exposes multiple ways to access Core:

- `_G.DCE`
- Individual globals (`_G.DCERegistry`, `_G.DCEEventBus`, etc.)
- Direct service globals
- Exports that vary between resources
- `GetDCEAPI()` expected by some modules but missing from Core

A platform-certified SDK must expose **one canonical entry point**.

## Decision

**The exported SDK is the sole supported public interface.**

Every external DCE resource shall obtain Core exclusively through:

```lua
local DCE = exports["dce-core"]:GetDCEAPI()
```

No external resource should rely on:

- `_G.DCE`
- `_G.DCERegistry`
- `_G.DCEEventBus`
- Any other internal global

Internal globals become **Core implementation details**.

The SDK becomes the **only supported public interface**.

## Consequences

### Positive

1. **Single entry point**: All external resources use the same canonical access pattern.
2. **Stable contract**: The frozen SDK table contains only documented public APIs.
3. **Encapsulation**: Internal implementation details are hidden from consumers.
4. **Testability**: The test suite validates the public contract, not internals.
5. **Future-proof**: SDK evolution preserves the canonical entry point.

### Negative

1. **Backward compatibility**: Existing globals remain temporarily but are marked INTERNAL/UNSUPPORTED.
2. **Migration effort**: All platform resources must be audited and updated.

### Neutral

1. Internal globals remain for backward compatibility during Sprint 1.
2. They are documented as unsupported and may change without notice.

## Implementation

### Phase 1 — Canonical SDK Export

```lua
exports("GetDCEAPI", function()
    return _G.DCE_FROZEN_SDK or DCE
end)
```

### Phase 2 — SDK Freeze Enforcement

The exported SDK (`sdk/sdk-wrapper.lua`) contains every frozen public API documented in `sdk/public-api.md`.

### Phase 3 — Internal vs Public Boundary

Separated into:

**Internal (implementation details):**
- `_G.DCERegistry`
- `_G.DCEEventBus`
- `_G.DCEScheduler`
- `_G.DCEPluginManager`
- `_G.DCEVerifier`
- All other `_G.DCE*` globals

**Public (supported interface):**
- `exports["dce-core"]:GetDCEAPI()`
- `exports["dce-core"]:IsReady()`
- `exports["dce-core"]:DCE_Subscribe()`

### Phase 4 — Resource Migration

All DCE resources use:
```lua
local DCE = exports["dce-core"]:GetDCEAPI()
```

### Phase 5 — Backward Compatibility

Existing globals remain temporarily but are:
- Marked INTERNAL
- Documented as unsupported
- Not referenced by platform resources

### Phase 6 — SDK Validation

The validation framework validates the exported SDK rather than internal globals.

## Compliance

All platform resources must comply with this ADR before Sprint 2 development begins.

**Non-compliance** is a breaking change and requires an ADR amendment.

## References

- `sdk/public-api.md` — Frozen SDK documentation
- `sdk/sdk-wrapper.lua` — Frozen SDK implementation
- `DCE/src/dce-core/init.lua` — Server entry point with canonical export
- `DCE/src/dce-core/client/init.lua` — Client entry point with canonical export
- `DCE/src/dce-core/verifier/init.lua` — Verifier validates exported SDK