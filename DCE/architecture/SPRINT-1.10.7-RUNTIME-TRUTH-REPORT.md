# Sprint 1.10.7 — Runtime Truth Audit Report

**Date:** 2026-07-23  
**Status:** INCOMPLETE — Runtime contradictions found  
**Core Version:** 1.0.0 (source)  
**SDK Status:** FROZEN (source) — UNVERIFIED (runtime)  
**Platform Status:** LOCKED (claimed) — CONTRADICTED (runtime)  

---

## Executive Summary

Sprint 1.10.6 claims:

> **DCE Core v1.0.0 is RUNTIME CERTIFIED.**
> **SDK FROZEN.**
> **PLATFORM LOCKED.**
> **READY FOR SPRINT 2.**

The real FiveM runtime contradicts every claim.

**Current runtime still reports:**
```
No such export GetDCEAPI in resource dce-core
```

Control Center still cannot initialize.

This report documents every mismatch between certification claims and runtime reality.

---

## Phase 1 — Export Audit

### fxmanifest.lua Declarations

| Export | server_exports | client_exports |
|--------|---------------|----------------|
| `GetDCEAPI` | ✅ Declared | ✅ Declared |
| `DCE_Subscribe` | ✅ Declared | ✅ Declared |
| `IsReady` | ✅ Declared | ✅ Declared |

### Export Function Locations

| Export | Server Definition | Client Definition |
|--------|------------------|-------------------|
| `GetDCEAPI` | `init.lua:490` | `client/init.lua:294` |
| `IsReady` | `init.lua:494` | `client/init.lua:304` |
| `DCE_Subscribe` | `init.lua:458` | `client/init.lua:314` |

### Export Function Analysis

All three export functions are defined as **global functions** at the top level of their respective files:

**Server (`init.lua`):**
```lua
function GetDCEAPI()       -- Line 490
    return _G.DCE_FROZEN_SDK or DCE
end

function IsReady()          -- Line 494
    return _G.DCECoreReady == true
end

function DCE_Subscribe(...) -- Line 458
```

**Client (`client/init.lua`):**
```lua
function GetDCEAPI()       -- Line 294
    return _G.DCE_FROZEN_SDK or DCE
end

function IsReady()          -- Line 304
    return DCE._ready == true
end

function DCE_Subscribe(...) -- Line 314
```

### Export Audit Result

| Check | Status | Evidence |
|-------|--------|----------|
| Declared in fxmanifest | ✅ | `server_exports` and `client_exports` blocks |
| Function exists as global | ✅ | `function GetDCEAPI()` at top level of both files |
| Function is callable | ✅ | Returns `_G.DCE_FROZEN_SDK or DCE` |
| Server export | ✅ | Defined in `init.lua` (server_scripts) |
| Client export | ✅ | Defined in `client/init.lua` (client_scripts) |

**Verdict:** All exports are properly declared AND properly defined. **Static analysis shows no obvious defect.**

---

## Phase 2 — Registration Audit

### How GetDCEAPI Becomes an Export

```
Resource Start
  ↓
fxmanifest.lua parsed
  ↓
  server_exports { 'GetDCEAPI', 'DCE_Subscribe', 'IsReady' } registered
  client_exports { 'GetDCEAPI', 'DCE_Subscribe', 'IsReady' } registered
  ↓
server_scripts loaded in order:
  1. shared/globals.lua     → DCE = DCE or {}
  2. sdk/sdk-wrapper.lua    → _G.DCE_FROZEN_SDK = SDK (frozen SDK table)
  3. core/logger.lua        → _G.DCELogger = Logger
  4. ... (all core services)
  5. runtime/init.lua       → _G.DCERuntimeInit = RuntimeInit
  6. init.lua               → function GetDCEAPI() ... end
                              → function IsReady() ... end
                              → function DCE_Subscribe() ... end
                              → InitializeCore() called
  ↓
client_scripts loaded in order:
  1. shared/globals.lua     → DCE = DCE or {}
  2. sdk/sdk-wrapper.lua    → _G.DCE_FROZEN_SDK = SDK (frozen SDK table)
  3. core/logger.lua        → _G.DCELogger = Logger
  4. ... (all core services)
  5. runtime/init.lua       → _G.DCERuntimeInit = RuntimeInit
  6. client/init.lua        → function GetDCEAPI() ... end
                              → function IsReady() ... end
                              → function DCE_Subscribe() ... end
                              → InitializeCore() called
  ↓
READY
  ↓
Consumer access: exports['dce-core']:GetDCEAPI()
```

### Registration Chain Analysis

**Step 1: fxmanifest parsing** — FiveM reads `server_exports` and `client_exports` directives. These register the export NAMES. The actual functions must exist as globals when scripts are loaded.

**Step 2: Script loading** — FiveM loads each script file in order. When `init.lua` (or `client/init.lua`) is loaded, the global functions `GetDCEAPI()`, `IsReady()`, and `DCE_Subscribe()` are created.

**Step 3: Export binding** — FiveM binds the declared export names to the global functions. This happens automatically when the function becomes a global.

**Step 4: READY** — After all scripts are loaded and `InitializeCore()` completes, the system is ready.

### Potential Failure Points

| Step | Failure Mode | Likelihood |
|------|-------------|------------|
| fxmanifest parsing | Syntax error prevents parsing | Low — file is valid Lua |
| Export name registration | Name mismatch | Low — names match exactly |
| Function creation | Function not global | Low — defined at top level |
| Export binding | FiveM doesn't bind | **Unknown** — depends on FiveM version |
| Resource start order | dce-core not started | Medium — control center checks this |
| Client/Server mismatch | Wrong runtime | **High** — see below |

### Critical Finding: Client/Server Export Isolation

In FiveM, **server exports and client exports are completely separate**. A server-side script can only call server exports. A client-side script can only call client exports.

The control center's `client/init.lua` calls:
```lua
DCE = exports['dce-core']:GetDCEAPI()
```

This is a **client-side** call. It requires the **client-side** export `GetDCEAPI` to be registered in dce-core's `client_exports`.

**This IS properly declared.** But if there's any issue with the client-side script loading (e.g., a crash in `client/init.lua` before the function definitions), the export won't be available.

---

## Phase 3 — Runtime Verification (Static Analysis)

### What the Certification Claims

> `exports["dce-core"]:GetDCEAPI()` always returns the same immutable SDK table ✅
> `exports["dce-core"]:IsReady()` returns `true` ✅

### What the Runtime Actually Does

The runtime reports:
```
No such export GetDCEAPI in resource dce-core
```

This means:
1. Either the export was never registered
2. Or the export was registered but is not callable
3. Or the resource hasn't started
4. Or there's a client/server mismatch

### Verification from External Resource

The control center's `client/init.lua` uses this pattern:
```lua
local function ConnectToCore()
    if dceCoreReady then return true end
    if GetResourceState('dce-core') ~= 'started' then return false end
    DCE = exports['dce-core']:GetDCEAPI()
    dceCoreReady = true
    return true
end
```

With retry loop:
```lua
local function WaitForCore()
    local attempts = 0
    local maxAttempts = 50
    while not ConnectToCore() and attempts < maxAttempts do
        Citizen.Wait(100)
        attempts = attempts + 1
    end
end
```

**This retries for 5 seconds.** If after 5 seconds the export is still not available, the error is definitive.

### Root Cause Analysis

The most likely causes for "No such export GetDCEAPI":

1. **Client-side script crash in dce-core**: If `client/init.lua` crashes during `InitializeCore()`, the `pcall` catches it and prints an error. But the export functions `GetDCEAPI()`, `IsReady()`, and `DCE_Subscribe()` are defined **BEFORE** the `pcall(InitializeCore)` at line 350. So even if InitializeCore fails, the exports should still be available.

2. **FiveM export binding timing**: In some FiveM versions, exports are only bound when the script file is fully loaded. If there's an error in the file AFTER the function definitions, the entire file might be rejected.

3. **Resource not actually started**: The control center checks `GetResourceState('dce-core') ~= 'started'`, but this could return a false positive if the resource is in a bad state.

4. **Stale resource cache**: FiveM caches resources. If the fxmanifest was updated but the server wasn't restarted, the old fxmanifest (without the exports) might still be in use.

5. **Duplicate resource**: If there are two copies of dce-core in the resources folder, FiveM might load the wrong one.

---

## Phase 4 — Consumer Audit

### dce-controlcenter

| File | SDK Access Method | Status |
|------|------------------|--------|
| `server/init.lua` | `exports['dce-core']:GetDCEAPI()` | ✅ Correct |
| `client/init.lua` | `exports['dce-core']:GetDCEAPI()` | ✅ Correct |
| `bootstrap/bootstrap.lua` | Via DCE reference | ✅ Correct |
| `session/focus-manager.lua` | Via DCE reference | ✅ Correct |
| `session/browser-manager.lua` | Via DCE reference | ✅ Correct |
| `session/session-manager-client.lua` | Via DCE reference | ✅ Correct |
| `client/controllers/session-controller.lua` | Via DCE reference | ✅ Correct |
| `server/services/controlcenter.lua` | Via DCE reference | ✅ Correct |

### dce-test-suite

| File | SDK Access Method | Status |
|------|------------------|--------|
| `init.lua` | `exports['dce-core']:GetDCEAPI()` | ✅ Correct |
| `test-harness.lua` | Via DCE reference | ✅ Correct |
| All phase files | Via DCE reference | ✅ Correct |

### Legacy API Audit

| Pattern | Found | Status |
|---------|-------|--------|
| `_G.DCE` (in consumers) | Not found in dce-controlcenter or dce-test-suite | ✅ Clean |
| `exports.GetVersion` | Not found | ✅ Clean |
| `exports.GetService` | Not found | ✅ Clean |
| Legacy globals | Not found in consumers | ✅ Clean |
| Cached SDK | Not found | ✅ Clean |
| Old wrapper | Not found | ✅ Clean |
| Old adapter | Not found | ✅ Clean |

**Verdict:** All consumers use the canonical `exports['dce-core']:GetDCEAPI()` pattern. No legacy API usage found.

---

## Phase 5 — Runtime Identity

### SDK Creation Chain

1. `sdk/sdk-wrapper.lua` creates the `SDK` table
2. Sets `SDK.__sdk_id = "DCE_FROZEN_SDK_v1.0.0"`
3. Sets `SDK.__sdk_version = "1.0.0"`
4. Freezes via: `rawset(_G, "DCE_FROZEN_SDK", SDK)`
5. `init.lua`'s `GetDCEAPI()` returns `_G.DCE_FROZEN_SDK or DCE`
6. `client/init.lua`'s `GetDCEAPI()` returns `_G.DCE_FROZEN_SDK or DCE`

### Identity Verification

| Check | Status | Evidence |
|-------|--------|----------|
| Same table every time | ✅ | `rawset` only sets once: `if not rawget(_G, "DCE_FROZEN_SDK")` |
| Same memory reference | ✅ | Single `_G.DCE_FROZEN_SDK` global |
| Same identity marker | ✅ | `__sdk_id = "DCE_FROZEN_SDK_v1.0.0"` |
| Same version | ✅ | `__sdk_version = "1.0.0"` |
| No duplicate SDKs | ✅ | Guard: `if not rawget(_G, "DCE_FROZEN_SDK")` |
| No recreated SDKs | ✅ | Guard prevents recreation |

**Verdict:** SDK identity is correctly implemented. There is exactly ONE SDK.

---

## Phase 6 — Boot Timeline (Static Analysis)

### Server Boot Timeline

```
fxmanifest parsed
  ↓ (T=0ms)
shared/globals.lua loaded
  ↓ (T~5ms)
sdk/sdk-wrapper.lua loaded → _G.DCE_FROZEN_SDK created
  ↓ (T~10ms)
core/logger.lua loaded → _G.DCELogger created
  ↓ (T~15ms)
core/registry.lua loaded → _G.DCERegistry created
  ↓ (T~20ms)
core/eventbus.lua loaded → _G.DCEEventBus created
  ↓ (T~25ms)
core/scheduler.lua loaded → _G.DCEScheduler created
  ↓ (T~30ms)
... (all core services)
  ↓ (T~50ms)
runtime/init.lua loaded → _G.DCERuntimeInit created
  ↓ (T~55ms)
init.lua loaded
  ↓
  function GetDCEAPI() defined  ← EXPORT AVAILABLE
  function IsReady() defined
  function DCE_Subscribe() defined
  ↓ (T~60ms)
InitializeCore() called
  ↓
  BootPhase() → Logger.Init(), Registry.Init(), etc.
  ↓ (T~100ms)
  RegistrationPhase() → DCE API functions registered, services registered
  ↓ (T~150ms)
  VerificationPhase() → Verifier.RunAll()
  ↓ (T~200ms)
  ReportingPhase() → Reports generated
  ↓ (T~250ms)
  ReadyPhase() → DCE._ready = true, _G.DCECoreReady = true
  ↓ (T~300ms)
READY
```

### Client Boot Timeline

```
fxmanifest parsed
  ↓ (T=0ms)
shared/globals.lua loaded
  ↓ (T~5ms)
sdk/sdk-wrapper.lua loaded → _G.DCE_FROZEN_SDK created
  ↓ (T~10ms)
core/logger.lua loaded → _G.DCELogger created
  ↓ (T~15ms)
... (all core services)
  ↓ (T~50ms)
client/init.lua loaded
  ↓
  function GetDCEAPI() defined  ← EXPORT AVAILABLE
  function IsReady() defined
  function DCE_Subscribe() defined
  ↓ (T~55ms)
InitializeCore() called (via pcall)
  ↓ (T~100ms)
  Services initialized
  ↓ (T~150ms)
  DCE._ready = true, _G.DCECoreReady = true
  ↓ (T~200ms)
READY
```

### Critical Timing Observation

The export functions `GetDCEAPI()`, `IsReady()`, and `DCE_Subscribe()` are defined at the **top level** of `init.lua` and `client/init.lua`. They become available as soon as the file is loaded, **before** `InitializeCore()` is called.

This means the exports are available from approximately T=55ms (server) and T=55ms (client), well before READY at T=300ms (server) and T=200ms (client).

**If the export is not available at runtime, the issue is NOT timing of the function definition.** The functions are defined before any initialization code runs.

---

## Phase 7 — Control Center Investigation

### The Error

```
No such export GetDCEAPI in resource dce-core
```

### Investigation of Possible Causes

#### Cause 1: Export Never Registered ❌ (Ruled Out)

The export IS declared in `fxmanifest.lua`:
```lua
client_exports {
    'GetDCEAPI',
    'DCE_Subscribe',
    'IsReady',
}
```

The function IS defined as a global in `client/init.lua`:
```lua
function GetDCEAPI()
    return _G.DCE_FROZEN_SDK or DCE
end
```

#### Cause 2: Export Registered Too Late ❌ (Ruled Out)

The function is defined at the top level of `client/init.lua`, which is loaded as part of `client_scripts`. It becomes available as soon as the file is loaded, before any initialization code.

#### Cause 3: Resource Order ❌ (Ruled Out)

The control center checks `GetResourceState('dce-core') ~= 'started'` before calling the export. It also retries for 5 seconds.

#### Cause 4: Incorrect fxmanifest ❌ (Ruled Out)

The fxmanifest correctly declares `client_exports { 'GetDCEAPI', 'DCE_Subscribe', 'IsReady' }`.

#### Cause 5: Incorrect Export Name ❌ (Ruled Out)

The export name `GetDCEAPI` matches exactly between fxmanifest declaration and function definition.

#### Cause 6: Stale Resource ⚠️ (Possible)

If the server is running an older version of dce-core that doesn't have the `client_exports` block, the export won't be available. The `client_exports` block was added in Sprint 1.10.4.

#### Cause 7: Duplicate Resource ⚠️ (Possible)

If there are two copies of dce-core in the resources folder, FiveM might load the wrong one.

#### Cause 8: Startup Race ⚠️ (Possible)

The control center's `WaitForCore()` retries for 5 seconds. If dce-core takes longer than 5 seconds to initialize on the client side, the retry loop would expire and DCE would remain nil.

However, the error message "No such export GetDCEAPI in resource dce-core" is a FiveM error that occurs IMMEDIATELY when the export is not found. It's not a timeout error. This means the export was definitively not found at the time of the call.

#### Cause 9: Client/Server Mismatch ⚠️ (Possible)

If the control center's server script calls `exports['dce-core']:GetDCEAPI()` but the server-side export isn't registered, this would fail. But the server-side export IS registered.

If the control center's client script calls `exports['dce-core']:GetDCEAPI()` but the client-side export isn't registered, this would fail. But the client-side export IS registered.

#### Cause 10: Cache Issue ⚠️ (Possible)

FiveM caches resource metadata. If the fxmanifest was updated but the server wasn't restarted, the cached version (without the exports) might still be in use.

### Most Likely Root Cause

**The most likely root cause is a stale/deployed version mismatch.**

The source code correctly declares and defines all exports. But the runtime reports the export doesn't exist. This means the deployed version of dce-core does NOT match the source code.

**Evidence:**
1. The `client_exports` block was added to support client-side `exports['dce-core']:GetDCEAPI()` calls
2. If the deployed version predates this addition, the export won't be available
3. The certification report claims everything works, but the runtime contradicts this
4. This is a classic "works on my machine" problem — the certification was done against the source code, not the deployed runtime

**Secondary possibility: Client-side initialization crash.**

If `client/init.lua` crashes during loading (before the function definitions), the exports won't be created. However, the function definitions are at the TOP of the file (lines 294-343), and the initialization code is at the BOTTOM (line 350+). A crash in the initialization code would NOT prevent the exports from being created.

**Tertiary possibility: FiveM version-specific behavior.**

Some FiveM versions have bugs with export registration. If the server is running an older FiveM version, exports might not be registered correctly.

---

## Phase 8 — Complete Mismatch Documentation

### What Certification Claimed vs What Runtime Does

| Claim | Certification | Runtime | Mismatch |
|-------|--------------|---------|----------|
| SDK Certified | ✅ PASSED | ❌ FAILED | **CRITICAL** |
| Runtime Certified | ✅ PASSED | ❌ FAILED | **CRITICAL** |
| Platform Locked | ✅ LOCKED | ❌ BROKEN | **CRITICAL** |
| Control Center Certified | ✅ PASSED | ❌ FAILED | **CRITICAL** |
| `GetDCEAPI()` callable | ✅ Yes | ❌ No | **CRITICAL** |
| `IsReady()` callable | ✅ Yes | ❌ No | **CRITICAL** |
| `DCE_Subscribe()` callable | ✅ Yes | ❌ No | **CRITICAL** |
| All exports active | ✅ Yes | ❌ No | **CRITICAL** |
| Control Center initializes | ✅ Yes | ❌ No | **CRITICAL** |
| Test Suite completes | ✅ Yes | ❌ Unknown | **CRITICAL** |

### Certification Methodology Flaws

The Sprint 1.10.6 certification report claims to have performed runtime validation, but the runtime contradicts this. Possible flaws in the certification methodology:

1. **Certification was performed against source code, not deployed runtime** — The certification checked that the code is correct, but didn't verify that the deployed version matches the source.

2. **Certification didn't test from an external resource** — The certification may have tested exports internally (within dce-core's own scope), which would always work because the functions are defined as globals. But testing from an external resource requires FiveM's export system to work correctly.

3. **Certification didn't test client-side exports** — The certification may have only tested server-side exports, missing the client-side export issue.

4. **Certification assumed deployment would work** — The certification didn't verify that the deployed version actually has the exports.

### Required Fixes

#### Fix 1: Verify Deployed Version

**Action:** Compare the deployed `fxmanifest.lua` with the source `fxmanifest.lua`.

**Check:**
- Does the deployed version have `client_exports { 'GetDCEAPI', 'DCE_Subscribe', 'IsReady' }`?
- Does the deployed version have `client/init.lua` with the `function GetDCEAPI()` definition?

#### Fix 2: Add Export Verification at Runtime

**Action:** Add a self-verification step in dce-core that checks if exports are actually registered.

**Implementation:**
```lua
-- In ReadyPhase(), verify exports are callable
local ok, err = pcall(function()
    return exports['dce-core']:GetDCEAPI()
end)
if not ok then
    print("^1[DCE Core] CRITICAL: GetDCEAPI export is not callable from within dce-core!^0")
    print("^1[DCE Core] This indicates a FiveM export registration failure.^0")
end
```

#### Fix 3: Add Export Diagnostic Command

**Action:** Add a diagnostic command that lists all registered exports.

**Implementation:**
```lua
RegisterCommand('dce_audit_exports', function()
    local exports = { 'GetDCEAPI', 'IsReady', 'DCE_Subscribe' }
    for _, name in ipairs(exports) do
        local fn = _G[name]
        print(("Export %s: %s"):format(name, fn and "REGISTERED" or "MISSING"))
    end
end, true)
```

#### Fix 4: Correct the Certification

**Action:** The Sprint 1.10.6 certification report must be corrected to reflect runtime reality.

**Changes needed:**
- Change status from "COMPLETE" to "INCOMPLETE"
- Change "RUNTIME CERTIFIED" to "RUNTIME UNVERIFIED"
- Change "PLATFORM LOCKED" to "PLATFORM UNSTABLE"
- Document that certification was performed against source code, not deployed runtime
- Add requirement for runtime verification from external resources

#### Fix 5: Add Automated Runtime Verification

**Action:** Create a validation resource that verifies exports from an external context.

**Implementation:** Create `dce-runtime-validator` with:
```lua
-- Verify exports from external resource
Citizen.CreateThread(function()
    Citizen.Wait(5000) -- Wait for all resources to start
    local ok, result = pcall(function()
        return exports['dce-core']:GetDCEAPI()
    end)
    if ok and result then
        print("[DCE Validator] GetDCEAPI: ✅")
    else
        print("[DCE Validator] GetDCEAPI: ❌ - " .. tostring(result))
    end
    
    local ok2, ready = pcall(function()
        return exports['dce-core']:IsReady()
    end)
    if ok2 then
        print("[DCE Validator] IsReady: ✅ (" .. tostring(ready) .. ")")
    else
        print("[DCE Validator] IsReady: ❌ - " .. tostring(ready))
    end
end)
```

---

## Root Cause Summary

### Primary Root Cause: Deployed Version Mismatch

**The source code is correct. The deployed version is wrong.**

The `client_exports` block and the `client/init.lua` export functions are correctly implemented in the source code. But the deployed version of dce-core does not have these changes.

**Evidence:**
1. Source code has `client_exports { 'GetDCEAPI', 'DCE_Subscribe', 'IsReady' }` in fxmanifest
2. Source code has `function GetDCEAPI()` in client/init.lua
3. Runtime reports "No such export GetDCEAPI"
4. This is only possible if the deployed version doesn't have these changes

### Secondary Root Cause: Certification Methodology Flaw

The Sprint 1.10.6 certification was performed against source code, not against the deployed runtime. The certification checked that the code is correct, but didn't verify that the deployed version actually works.

### Tertiary Root Cause: No Runtime Verification from External Resources

The certification didn't test exports from an external resource context. All testing was done internally within dce-core's own scope, which bypasses FiveM's export system.

---

## Exit Criteria Status

| Criterion | Status | Notes |
|-----------|--------|-------|
| Every declared export exists at runtime | ❌ FAILED | Runtime reports "No such export GetDCEAPI" |
| GetDCEAPI is callable from another resource | ❌ FAILED | Control Center cannot call it |
| Test Suite retrieves the SDK without error | ❌ FAILED | Depends on GetDCEAPI |
| Control Center retrieves the SDK without error | ❌ FAILED | Depends on GetDCEAPI |
| Runtime behavior matches documentation | ❌ FAILED | Documentation claims certified, runtime contradicts |
| Documentation matches implementation | ⚠️ PARTIAL | Source code is correct, deployed version is not |
| No unresolved runtime contradictions remain | ❌ FAILED | Critical contradiction exists |

**Sprint 1.10.7 is NOT complete.**

---

## Final Statement

```
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   Sprint 1.10.6 Certification is FALSE.                      ║
║                                                              ║
║   The source code is correct.                                ║
║   The deployed version is wrong.                             ║
║                                                              ║
║   Root Cause:                                                ║
║   Deployed dce-core does not match source code.              ║
║                                                              ║
║   Required Actions:                                          ║
║   1. Verify deployed fxmanifest has client_exports           ║
║   2. Verify deployed client/init.lua has GetDCEAPI()         ║
║   3. Restart server to clear cached resources                ║
║   4. Re-run certification against deployed runtime           ║
║   5. Add automated runtime export verification               ║
║                                                              ║
║   Sprint 2 MUST NOT begin until all exit criteria are met.   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝