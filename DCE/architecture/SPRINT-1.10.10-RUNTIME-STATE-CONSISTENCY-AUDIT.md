# Sprint 1.10.10 — Runtime State Consistency Audit

## Root Cause Analysis

---

### Observation 1: Service Detection vs Runtime Report Mismatch

**Runtime Evidence:**
- Verification Framework detects services: Logger, Registry, EventBus, Scheduler, CoreRegistry
- Runtime Report prints: `Services: 0/0`

**Root Cause:**
The Runtime Report (`report.lua`) does NOT query the Registry or CoreRegistry for service counts. Instead, it queries `_G.DCEServiceValidator:GetSummary()`. If the ServiceValidator hasn't been initialized (or its state has been reset), it returns zero values because its results table is empty.

The critical path is:
1. `report.lua:collectReport()` calls `_G.DCEServiceValidator:GetSummary()`
2. `service-validator.lua:GetSummary()` reads from `svState.results.services.list`
3. If `ServiceValidator.ValidateServices()` was never called, `results.services.list` is nil
4. `#(results.services.list or {})` returns 0

Meanwhile, the verifier (`verifier/init.lua:runServiceVerifier()`) queries `_G.DCE` or `_G.DCERegistry` directly — which always works because the Registry exists at runtime.

**Fix:** The Runtime Report must query the canonical Registry (`_G.DCERegistry:List()`) directly, not depend on ServiceValidator's cached results.

---

### Observation 2: API Verifier Reports SDK APIs as Invalid

**Runtime Evidence:**
- APIs like `GetService`, `RegisterService`, `GetVersion`, `Emit`, `Schedule`, `RegisterPlugin`, `ValidateConfig` reported as invalid
- Yet these APIs exist in the source

**Root Cause:**
The API Verifier (`verifier/init.lua:runAPIVerifier()`) at line 193 does:
```lua
local ok, result = pcall(function()
    return exports['dce-core']:GetDCEAPI()
end)
```

If the verifier runs BEFORE `init.lua` sets up the exports (during the Verification phase which is Phase 2, but exports are only set up when the file completes execution), `exports['dce-core']:GetDCEAPI()` returns nil. Then the fallback at line 201 checks `_G.DCE_FROZEN_SDK`.

**However, the real problem:** At line 202, fallback is `_G.DCE_FROZEN_SDK` which IS the correct table. But the verifier then checks the canonical SDK for functions like `GetService`, `RegisterService`, etc. — which DO exist on the frozen SDK.

**The actual divergence:** Look at line 251-255:
```lua
local isReadyFn = canonicalDCE.IsReady
v.Check("Canonical SDK: IsReady", type(isReadyFn) == "function", ...)
```

At the time verification runs, `_G.DCECoreReady` may not yet be set (it's set in `ReadyPhase` Phase 4). But `SDK.IsReady()` only checks `_G.DCECoreReady == true` — it doesn't care about the state. The function EXISTS because it's defined in `sdk-wrapper.lua`. So this check should PASS.

**The real issue:** The API verifier checks against the canonical SDK but the ServiceValidator (`service-validator.lua:ValidateAPI()`) at line 284 does:
```lua
if DCE then
    local fn = DCE[funcName]
```

This `DCE` is the local variable from `_G.DCE`, which in `init.lua` is set to `FROZEN_SDK`. **But** — `service-validator.lua` does NOT capture the frozen SDK; it reads `_G.DCE`. If `_G.DCE` was overwritten or is a different table, the API check validates the wrong object.

**Fix:** Both verifier and service-validator must validate the SAME canonical SDK table. The canonical source is `_G.DCE_FROZEN_SDK`. The API verifier must validate this table, and the service-validator must also validate the frozen SDK.

---

### Observation 3: Export Verification Shows GetDCEAPI and DCE_Subscribe PASS, but IsReady is Absent

**Runtime Evidence:**
```
Export:
GetDCEAPI PASS
Export:
DCE_Subscribe PASS
```
IsReady is absent.

**Root Cause:**
The API Verifier (`verifier/init.lua:runAPIVerifier()`) at lines 259-265 checks exports:
```lua
local exportNames = { "GetDCEAPI", "DCE_Subscribe" }
```

**`IsReady` is NOT in this list.** The export verification only checks `GetDCEAPI` and `DCE_Subscribe`. It was never added.

Meanwhile, the ServiceValidator (`service-validator.lua:ValidateExports()`) at lines 26-29 checks `REQUIRED_EXPORTS` which also only contains `GetDCEAPI` and `DCE_Subscribe`. `IsReady` is only checked in the fallback validator chain, not in either consolidated framework.

**Fix:** Add `IsReady` to the export verification in both `verifier/init.lua` and `service-validator.lua`.

---

### Observation 4: Boot Verification Reports "Core initialized event emitted FAIL"

**Runtime Evidence:**
- Boot Verification says `Core initialized event emitted FAIL`
- Yet boot continues

**Root Cause:**
At `verifier/init.lua:runBootVerifier()` line 164:
```lua
v.Check("Core initialized event emitted", state.boot.initialized or false, ...)
```

This checks `state.boot.initialized`. What is `state.boot`? It's the verifier's OWN result from the boot verifier, which is a table with keys `passed`, `failed`, `skipped`, etc. — NOT a flag indicating whether the event was emitted. `state.boot` is set at line 173:
```lua
state.boot = summary
```

So `state.boot.initialized` would be `nil` (the summary table has no `initialized` key), making the check fail. The verifier is checking its OWN output instead of checking whether `DCE.Emit("core:initialized", ...)` was actually called in ReadyPhase.

**Additionally:** The boot verifier reads `state.boot.initialized` which was set by `runBootVerifier` itself — this is a circular self-reference. It checks whether the boot verifier's OWN result contains a field that no boot verifier result ever contains.

**Fix:** The verifier must check the ACTUAL event emission by inspecting whether `_G.DCECoreReady` or `_G.DCE._ready` is set, since `core:initialized` is emitted just before those flags are set.

---

### Observation 5: Runtime Report Prints "Events: 0 active" Despite EventBus Existing

**Runtime Evidence:**
- Runtime Report says `Events: 0 active`
- EventBus exists and has handlers registered

**Root Cause:**
The Runtime Report (`report.lua:collectReport()`) at lines 105-133 reads events from `_G.DCEServiceValidator:GetSummary()`:
```lua
report.events.active = summary.activeEvents or 0
report.events.total = summary.totalEvents or 0
```

`summary.activeEvents` comes from `service-validator.lua:GetSummary()` which counts events from `results.events.list`. If `ServiceValidator.ValidateEvents()` was never called, this list is empty.

But `_G.DCEEventBus:ListEvents()` would return the actual events. The Runtime Report NEVER queries the EventBus directly; it depends on ServiceValidator's cached results.

**Fix:** The Runtime Report must query `_G.DCEEventBus:ListEvents()` and `_G.DCEEventBus:HandlerCount()` directly instead of going through ServiceValidator.

---

## Dependency Map (Current vs Required)

### CURRENT (Fragmented)

```
RuntimeReporter (report.lua)
    ↓ (depends on)
    DCEServiceValidator (cached/computed counts)
    ↓ (may have stale data if Validate* was not called)
    DCERuntimeState.serviceValidator

APIVerifier (verifier/init.lua)
    ↓ (validates)
    exports['dce-core']:GetDCEAPI() or _G.DCE_FROZEN_SDK
    ↓ (BUT also checks)
    _G.DCE (different object)

BootVerifier (verifier/init.lua)
    ↓ (validates)
    state.boot.initialized (circular — checks itself)
    ↓ (should check)
    _G.DCECoreReady or _G.DCE._ready

ExportVerifier (verifier/init.lua)
    ↓ (hardcoded list: GetDCEAPI, DCE_Subscribe)
    Missing: IsReady

ServiceValidator (service-validator.lua)
    ↓ (validates)
    _G.DCE (whatever it points to)
    NOT _G.DCE_FROZEN_SDK (the canonical SDK)
```

### REQUIRED (All pointing to the same canonical sources)

```
RuntimeReporter (report.lua)
    ↓ (must query directly)
    _G.DCERegistry:List()              → Services count
    _G.DCE_FROZEN_SDK                  → API count
    _G.DCEEventBus:ListEvents()        → Events count
    _G.DCEEventBus:HandlerCount()      → Active events
    _G.DCE_FROZEN_SDK.IsReady          → Ready state
    _G.DCEBootTimeline                 → Boot stages
    _G.DCEDiagnostics                  → Warnings/errors

APIVerifier (verifier/init.lua)
    ↓ (must validate)
    _G.DCE_FROZEN_SDK                  → The ONE canonical SDK
    NO fallback, NO alternate tables

ServiceVerifier (verifier/init.lua)
    ↓ (must check)
    _G.DCERegistry:List()              → Actual service list
    _G.DCE_FROZEN_SDK                  → IsReady function exists

ExportVerifier (verifier/init.lua)
    ↓ (must check)
    _G.DCE_FROZEN_SDK.IsReady          → IsReady as function
    Plus GetDCEAPI and DCE_Subscribe
```

---

## Files Modified

1. **DCE/src/dce-core/verifier/init.lua** — Fix all 5 observations
2. **DCE/src/dce-core/runtime/report.lua** — Rewrite to query canonical sources directly
3. **DCE/src/dce-core/runtime/service-validator.lua** — Fix SDK validation target

---

## Why Each Inconsistency Cannot Reoccur

1. **Service count mismatch:** RuntimeReport now queries `_G.DCERegistry:List()` directly. No cached data path. ServiceValidator counters are removed as a source of truth.

2. **API verification fails:** APIVerifier now validates `_G.DCE_FROZEN_SDK` exclusively. No fallback chains, no alternate table references.

3. **IsReady absent:** Both verifier and service-validator now include `IsReady` in their export checks.

4. **Boot event check:** BootVerifier now checks `_G.DCE._ready` and `_G.DCECoreReady` directly. No self-referential state checking.

5. **Events = 0:** RuntimeReport now queries `_G.DCEEventBus` directly for active event counts. No dependency on ServiceValidator's cached event data.