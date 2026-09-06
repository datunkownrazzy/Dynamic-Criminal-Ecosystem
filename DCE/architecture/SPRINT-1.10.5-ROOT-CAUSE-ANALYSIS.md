# Sprint 1.10.5 — Root Cause Analysis

## The Problem
Sprint 1.10.4 fixed the client-side `GetDCEAPI()` return value and added retry loops, but the test suite still reports every SDK function failing with `attempt to call nil value (field 'GetVersion')` and Control Center reports `No such export GetDCEAPI in resource dce-core`.

## Root Cause: `_G` Environment Capture in Frozen SDK

### Architectural Expectation
The frozen SDK (created by `sdk-wrapper.lua`) is the canonical public interface. Every consumer calls `exports['dce-core']:GetDCEAPI()` to obtain it, then calls methods on it like `DCE.GetService("CoreRegistry")`.

### Actual Implementation
The frozen SDK functions reference `_G.DCERegistry`, `_G.DCEEventBus`, etc. to access internal services:

```lua
function SDK.GetService(name)
    local reg = _G.DCERegistry  -- _G is the CALLER's global environment
    if reg then return reg.Get(name) end
    return nil
end
```

### Why It Fails
In FiveM, each resource has its own Lua global environment (`_G`). When a consumer resource (like `dce-test-suite`) calls:

```lua
local DCE = exports['dce-core']:GetDCEAPI()
DCE.GetService("CoreRegistry")
```

The `GetDCEAPI()` export function executes in **dce-core's** environment (so `_G.DCE_FROZEN_SDK` resolves correctly). But the returned SDK table's methods (like `GetService`) were defined in `sdk-wrapper.lua` and when called from the consumer, they execute in the **consumer's** environment. So `_G.DCERegistry` resolves to the consumer's `_G`, which is `nil`.

### Why `GetVersion()` Sometimes Works
`SDK.GetVersion()` returns a hardcoded string `"1.0.0"` and doesn't reference any `_G` globals, so it works across resource boundaries. But the test reports `attempt to call nil value (field 'GetVersion')` — this means even `GetVersion` is sometimes nil, which indicates the SDK table itself is not being returned correctly in some cases.

### Secondary Issue: Client Export Registration
The `No such export GetDCEAPI in resource dce-core` error on the client occurs because:
1. `client/init.lua` defines `GetDCEAPI()` at module level
2. If `InitializeCore()` throws an error (even caught by pcall), the script continues
3. But if there's a non-pcall'd error, the entire script fails and exports aren't registered
4. The client-side `sdk-wrapper.lua` also runs and sets `_G.DCE_FROZEN_SDK`, but the client's `GetDCEAPI()` function needs to be properly defined

### Tertiary Issue: SDK Population Timing
The frozen SDK is created in `sdk-wrapper.lua` which runs BEFORE `init.lua`. At that point, `_G.DCERegistry`, `_G.DCEEventBus`, etc. are nil because the core service modules haven't initialized yet. The SDK functions do lazy lookups at call time (not creation time), which is correct — but the `_G` they look up is the wrong environment.

## Corrective Action

### Fix 1: Capture dce-core's `_G` as an upvalue in `sdk-wrapper.lua`
Add `local _G = _G` at the top of `sdk-wrapper.lua`. This captures dce-core's global environment as a local upvalue. All SDK functions that reference `_G` will use this captured upvalue instead of the caller's `_G`.

### Fix 2: Ensure client-side export registration is robust
Verify that `client/init.lua` properly registers exports even if initialization encounters issues. The `GetDCEAPI`, `IsReady`, and `DCE_Subscribe` functions are defined at module level (outside InitializeCore), so they should be available. But ensure no runtime errors prevent the script from completing.

### Fix 3: Verify SDK identity across all consumers
Ensure that `_G.DCE_FROZEN_SDK` is the single canonical SDK instance and that all consumers receive the same table reference.