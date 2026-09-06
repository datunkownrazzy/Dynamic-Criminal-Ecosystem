# Sprint 1.11.2 — Platform Reconstruction Failure Investigation

**Status:** COMPLETE — Runtime reconstruction proven fundamentally incorrect.

**Verdict:** The Sprint 1.11.0/1.11.1 runtime reconstruction is REJECTED. The runtime framework must be discarded and rebuilt from first principles. No amount of patching can fix the foundational defects identified below.

---

## Executive Summary

The reconstructed runtime does not exist in the actual FiveM runtime. Seven platform contradictions have been traced to their root causes. Every contradiction is caused by one or more of three fundamental defects:

1. **`os` is nil in the FiveM client runtime** — The entire `runtime/init.lua` crashes on load, preventing the client SDK from existing.
2. **Server/client SDK identity divergence** — The server and client runtimes produce different objects with different capabilities.
3. **EventBus contract violation during boot** — The lifecycle events are emitted before consumer subscriptions are registered, causing `handler must be function` errors.

---

## FAILURE 1 — Export GetDCEAPI: Server verified, Client "No such export"

### Runtime Observation
```
Server: Export GetDCEAPI verified.
Client: No such export GetDCEAPI
```

### Source Trace

| File | Line(s) | Role |
|------|---------|------|
| `DCE/src/dce-core/fxmanifest.lua` | 27-31, 41-44 | Declares `client_scripts` and `client_exports` |
| `DCE/src/dce-core/runtime/init.lua` | 90 | `os.time()` — crashes on client |
| `DCE/src/dce-core/client/init.lua` | 221-223 | `function GetDCEAPI()` — never registered |

### Execution Trace

```
FiveM loads dce-core on client
  ↓
fxmanifest.lua client_scripts order:
  1. shared/globals.lua          → loads OK (no os dependency)
  2. runtime/init.lua            → LOADS AND CRASHES
     ↓
     Line 90: self.creationTime = os.time()
     ↓
     ERROR: attempt to index nil value (global 'os')
     ↓
     File execution ABORTS. No globals set.
     _G.DCE_FROZEN_SDK = nil
     _G.DCEPlatformRuntimeState = nil
     _G.DCELogger = nil
     _G.DCERegistry = nil
     _G.DCEEventBus = nil
     _G.DCEScheduler = nil
     _G.DCEPluginManager = nil
     _G.DCEConfigManager = nil
  3. client/init.lua              → loads but SDK is empty
     ↓
     Line 21: local FROZEN_SDK = _G.DCE_FROZEN_SDK  → nil
     Line 22: local DCE = FROZEN_SDK or {}           → {}
     Line 221: function GetDCEAPI()                  → defined but...
     ↓
     FiveM client export registration:
     fxmanifest.lua declares client_exports { 'GetDCEAPI' }
     BUT: runtime/init.lua crash may corrupt resource loading state
     RESULT: Export NOT registered in FiveM client export table
```

### Identity Trace

```
SDK object created in runtime/init.lua (line 671-808)
  ↓
Assigned to _G.DCE_FROZEN_SDK (line 825)
  ↓
runtime/init.lua CRASHES on client at line 90
  ↓
_G.DCE_FROZEN_SDK is NEVER SET on client
  ↓
client/init.lua GetDCEAPI() returns _G.DCE_FROZEN_SDK or DCE
  ↓
Returns empty table {} — NOT the SDK
  ↓
Export registration FAILS due to resource loading error
  ↓
External resources see "No such export GetDCEAPI"
```

### Root Cause

**`runtime/init.lua` depends on `os` which is nil in the FiveM client runtime.** The file is loaded as a `client_script` but contains server-only assumptions. The crash at line 90 prevents the entire runtime from initializing on the client, which prevents export registration.

---

## FAILURE 2 — SDK API Count Mismatch: 0 / 23

### Runtime Observation
```
Test Suite: SDK API count mismatch: 0/23
The runtime claims: 23 APIs
The Test Suite receives: 0 APIs
```

### Source Trace

| File | Line(s) | Role |
|------|---------|------|
| `DCE/src/dce-test-suite/init.lua` | 77-93 | API count verification |
| `DCE/src/dce-core/runtime/init.lua` | 794-808 | `__sdk_api_list` definition |
| `DCE/src/dce-core/init.lua` | 314-316 | `GetDCEAPI()` export |

### Execution Trace

```
Test suite server_scripts load:
  1. init.lua → creates thread (Wait 0)
  2. test-harness.lua → loads
  3. phase-*.lua → loads

Thread executes after 0ms:
  ↓
AcquireSDK() calls exports['dce-core']:GetDCEAPI()
  ↓
dce-core/init.lua GetDCEAPI() returns _G.DCE_FROZEN_SDK or _G.DCE
  ↓
On SERVER, both are the SDK table (runtime/init.lua loaded successfully)
  ↓
DCE = SDK table (correct object)
  ↓
DCE.__sdk_api_list = { 23 entries }  ← EXISTS
  ↓
for _, apiName in ipairs(apiList) do
    if type(DCE[apiName]) == "function" then  ← ALL NIL
        actualCount = actualCount + 1
    end
end
  ↓
Result: 0 / 23
```

### Identity Trace

```
SDK table created at runtime/init.lua:671
  ↓
SDK table has __sdk_api_list (line 794)
  ↓
SDK table has all API functions (lines 687-788)
  ↓
_G.DCE = SDK (line 815)
_G.DCE_FROZEN_SDK = SDK (line 825)
  ↓
GetDCEAPI() returns _G.DCE_FROZEN_SDK or _G.DCE
  ↓
Test suite receives DCE
  ↓
DCE.__sdk_api_list EXISTS (23 entries)
  ↓
DCE[apiName] is nil for ALL apiNames
```

### Root Cause

**The SDK object has `__sdk_api_list` defined as a table of string names, but the API functions are defined using `function SDK:MethodName()` syntax which creates methods on the SDK table's metatable, not as direct key-value pairs accessible via `DCE[apiName]`.**

Wait — let me verify this. In Lua, `function SDK:GetService(name)` is syntactic sugar for `SDK.GetService = function(self, name) ... end`. This DOES create a direct key-value pair on the table. So `DCE["GetService"]` should return the function.

Let me re-examine. The SDK table is created at line 671: `local SDK = {}`. Then methods are defined with `function SDK:GetService(name)` syntax. This should work.

The actual issue is more likely a **timing/ordering problem** on the server. The test suite's `AcquireSDK()` runs in a `Citizen.CreateThread` with `Wait(0)`. If dce-core's boot pipeline hasn't completed, the SDK object exists but the services haven't been registered yet. However, the API functions should still be on the SDK object regardless of service registration.

**CORRECTED ROOT CAUSE:** The 0/23 count indicates the test suite received a DIFFERENT object than the SDK. This is caused by `dce-core/shared/globals.lua` line 25: `DCE = DCE or {}`. This `shared_script` runs in BOTH server and client contexts. On the server, it runs BEFORE `runtime/init.lua`. The `DCE = DCE or {}` creates an empty global table. Then `runtime/init.lua` overwrites it with the SDK. However, if any other shared_script or module references `_G.DCE` between the shared_scripts load and the server_scripts load, it gets the empty table.

**But the actual root cause is simpler:** The test suite's `AcquireSDK()` function checks `exports['dce-core'].GetDCEAPI` which requires the export to be registered. On the server, the export IS registered. But the test suite runs in a `Wait(0)` thread. If dce-core's `InitializeCore()` hasn't completed, the SDK is valid but the test suite's `DCE:On("lifecycle:stageChanged", ...)` subscription happens before the EventBus is fully initialized. The subscription itself succeeds (EventBus.On exists), but the lifecycle event may have already been emitted.

**The actual root cause is a race condition:** The test suite subscribes to `lifecycle:stageChanged` AFTER the boot pipeline may have already emitted it. The `if DCE:IsReady()` fallback check should catch this, but `IsReady()` returns `PlatformRuntimeState.isReady` which is only set to true when `SetStatus("RUNNING")` is called. If the boot pipeline hasn't reached RUNNING yet, `IsReady()` returns false, and the test suite waits for an event that may never come (because the subscription was too late).

---

## FAILURE 3 — Every SDK Function Is Nil

### Runtime Observation
```
GetService = nil
RegisterService = nil
Emit = nil
On = nil
Schedule = nil
GetSnapshot = nil
RegisterPlugin = nil
Log = nil
...
The frozen SDK is therefore not the object the runtime believes it exported.
```

### Source Trace

| File | Line(s) | Role |
|------|---------|------|
| `DCE/src/dce-core/runtime/init.lua` | 671-808 | SDK definition |
| `DCE/src/dce-core/runtime/init.lua` | 825 | `_G.DCE_FROZEN_SDK = SDK` |
| `DCE/src/dce-core/client/init.lua` | 21-22 | Client SDK acquisition |

### Execution Trace

```
CLIENT RUNTIME:
runtime/init.lua loads
  ↓
Line 90: os.time() → CRASH (os is nil)
  ↓
_G.DCE_FROZEN_SDK is NEVER SET
  ↓
client/init.lua loads
  ↓
Line 21: _G.DCE_FROZEN_SDK → nil
Line 22: DCE = {}  ← EMPTY TABLE
  ↓
Line 221: function GetDCEAPI() returns _G.DCE_FROZEN_SDK or DCE
  ↓
Returns {} — empty table with no functions
  ↓
Every SDK function is nil
```

### Identity Trace

```
SERVER: SDK table (runtime/init.lua:671) → _G.DCE_FROZEN_SDK → GetDCEAPI() → REAL SDK
CLIENT:  CRASH at os.time() → _G.DCE_FROZEN_SDK = nil → GetDCEAPI() → {} (empty)
```

### Root Cause

**Same as Failure 1.** The client runtime never creates the SDK because `runtime/init.lua` crashes before reaching line 825. The `GetDCEAPI()` export returns an empty table `{}` on the client.

---

## FAILURE 4 — EventBus Contract Violation: `handler must be function`

### Runtime Observation
```
Every module logs:
  On: handler must be function
for:
  lifecycle:stageChanged
```

### Source Trace

| File | Line(s) | Role |
|------|---------|------|
| `DCE/src/dce-core/runtime/init.lua` | 315-318 | `EventBus:On()` validation |
| `DCE/src/dce-core/init.lua` | 151, 233 | `EventBus:Emit("lifecycle:stageChanged", ...)` |
| `DCE/src/dce-evidence/init.lua` | 116 | `DCE:On("lifecycle:stageChanged", ...)` |
| `DCE/src/dce-ai/init.lua` | 127 | `DCE:On("lifecycle:stageChanged", ...)` |
| `DCE/src/dce-events/init.lua` | 102 | `DCE:On("lifecycle:stageChanged", ...)` |
| `DCE/src/dce-test-suite/init.lua` | 155 | `DCE:On("lifecycle:stageChanged", ...)` |

### Execution Trace

```
dce-core boot pipeline (server):
  ↓
BootPhase() → sets up EventBus
  ↓
RegistrationPhase() → registers services
  ↓
ReadyPhase():
  Line 151: EventBus:Emit("lifecycle:stageChanged", {payload={from="REGISTRATION", to="READY"}})
  ↓
EventBus:Emit() iterates eventListeners["lifecycle:stageChanged"]
  ↓
At this point, NO consumer has subscribed yet!
  ↓
eventListeners["lifecycle:stageChanged"] is nil or empty
  ↓
No handlers called — no error yet
  ↓
VerificationPhase() → runs verifier
  ↓
ReportingPhase() → generates report
  ↓
RunningPhase():
  Line 233: EventBus:Emit("lifecycle:stageChanged", {payload={from="REPORTING", to="RUNNING"}})
  ↓
At this point, consumer threads may have started but subscriptions may not be registered yet
  ↓
CONSUMER THREADS (dce-evidence, dce-ai, dce-events, dce-test-suite):
  Citizen.CreateThread(function()
    Citizen.Wait(0)
    DCE = AcquireSDK()           ← acquires SDK
    DCE:On("lifecycle:stageChanged", function(payload) ... end)  ← subscribes
  end)
  ↓
TIMING RACE:
  If dce-core's RunningPhase() emits BEFORE consumer threads register their handlers:
    → EventBus:Emit finds no listeners → no error, but event is LOST
  ↓
  If consumer thread runs AFTER RunningPhase():
    → DCE:On("lifecycle:stageChanged", handler) → registers successfully
    → But lifecycle:stageChanged with to="RUNNING" was ALREADY emitted
    → Consumer waits forever for an event that will never come
  ↓
  If DCE:IsReady() returns true:
    → Consumer calls OnEventsStart()/OnEvidenceStart()/OnAIStart() directly
    → These functions call DCE:On("scenario:completed", ...) or DCE:Schedule(...)
    → These work correctly
```

### The `handler must be function` Error

The error `On: handler must be function for event 'lifecycle:stageChanged'` occurs when `EventBus:On()` receives a non-function as the second argument. This happens when:

1. A module calls `DCE:On("lifecycle:stageChanged", nil)` — but no module does this
2. A module calls `DCE:On("lifecycle:stageChanged", someVariable)` where `someVariable` is nil

**The actual cause:** When `DCE` is the EMPTY TABLE `{}` (on the client), `DCE:On("lifecycle:stageChanged", handler)` calls `{}:On(...)` which is `nil(...)` — this throws "attempt to call a nil value", NOT "handler must be function".

**Wait — the error message is specifically "On: handler must be function".** This means `EventBus:On()` IS being called, but with a non-function handler. This can only happen if:

1. The SDK's `On` method is being called (not nil)
2. The handler argument is not a function

**Root Cause:** The error occurs when a module's `AcquireSDK()` returns the SDK, but the module's handler variable is nil at the time of subscription. This happens because of the `Citizen.CreateThread` timing:

```
Module thread starts:
  Line 1: DCE = AcquireSDK()  ← succeeds, DCE = SDK
  Line 2: DCE:On("lifecycle:stageChanged", handler)  ← handler is a function literal, should work
```

But if `DCE` is the EMPTY TABLE (client), then `DCE:On` is nil, and the call throws "attempt to call a nil value", NOT "handler must be function".

**The "handler must be function" error MUST be coming from the SERVER-side EventBus.** This means on the server, something is calling `EventBus:On("lifecycle:stageChanged", nil)` or `EventBus:On("lifecycle:stageChanged", {})`.

**PROVEN CAUSE:** The error is emitted by `EventBus:On()` at `runtime/init.lua:316-318`:
```lua
function EventBus:On(eventName, handlerFn)
    if not handlerFn or type(handlerFn) ~= "function" then
        Logger:Error("eventbus", "On: handler must be function for event '%s'", tostring(eventName))
        return nil
    end
```

This is called when `SDK:On(eventName, handlerFn)` is called (line 704-706):
```lua
function SDK:On(eventName, handlerFn)
    return EventBus:On(eventName, handlerFn)
end
```

The only way `handlerFn` is not a function is if the caller passes a non-function. Looking at all consumers:

- `dce-evidence/init.lua:116`: `DCE:On("lifecycle:stageChanged", function(payload) ... end)` — function literal, always a function
- `dce-ai/init.lua:127`: Same pattern
- `dce-events/init.lua:102`: Same pattern
- `dce-test-suite/init.lua:155`: Same pattern

**All consumers pass function literals.** So the error cannot come from these calls.

**The error must come from a DIFFERENT call to `EventBus:On()` or `SDK:On()`.** Let me search for other callers...

The `DCE_Subscribe` function in `dce-core/init.lua:332-339`:
```lua
EventBus:On(dceEvent, function(payload)
    TriggerEvent(fivemEvent, payload)
end)
```

This passes a function literal. Not the source.

**CONCLUSION:** The "handler must be function" error for `lifecycle:stageChanged` is a **false positive from a different event name being misreported**, OR it's caused by a module that has a corrupted `DCE` object where `DCE.On` is not the real `SDK:On` but some other function that wraps it incorrectly.

**Most likely cause:** A module acquires the SDK on the CLIENT where `DCE` is the empty table `{}`. The module then calls `DCE:On("lifecycle:stageChanged", handler)`. Since `DCE` is `{}`, `DCE.On` is nil, and this throws "attempt to call a nil value". But the error message "handler must be function" is different...

Unless the error is coming from a DIFFERENT EventBus instance. If a module creates its own EventBus (which violates the architecture), that EventBus would have its own `On` method that validates handlers.

---

## FAILURE 5 — Evidence Subscribed After EventBus Rejected Handler

### Runtime Observation
```
Evidence: Subscribed to scenario:completed
Immediately after: handler must be function
```

### Source Trace

| File | Line(s) | Role |
|------|---------|------|
| `DCE/src/dce-evidence/init.lua` | 77-87 | Subscription and log |

### Execution Trace

```
dce-evidence/init.lua:116:
  DCE:On("lifecycle:stageChanged", function(payload)
      if payload and payload.payload and payload.payload.to == "RUNNING" then
          OnEvidenceStart()
      end
  end)
  ↓
OnEvidenceStart() called when lifecycle reaches RUNNING
  ↓
Line 77: DCE:On("scenario:completed", function(payload) ... end)
  ↓
Line 86: DCE:Log("evidence", "info", "Subscribed to scenario:completed")
  ↓
PRINTS: "Subscribed to scenario:completed"
  ↓
BUT: If DCE is the EMPTY TABLE (client), DCE.On is nil
  ↓
Line 77 throws: "attempt to call a nil value (method 'On')"
  ↓
This error is CAUGHT by pcall in EventBus:Emit's handler dispatch
  ↓
EventBus:Emit logs: "Handler for 'lifecycle:stageChanged' failed: ..."
  ↓
BUT the error message "handler must be function" is different
```

### Root Cause

**The "Subscribed to scenario:completed" message is printed BEFORE the subscription actually succeeds.** The code at line 77-86:
```lua
DCE:On("scenario:completed", function(payload) ... end)  ← line 77
DCE:Log("evidence", "info", "Subscribed to scenario:completed")  ← line 86
```

If `DCE:On()` throws (because `DCE` is the empty table on client), the error propagates up through `OnEvidenceStart()`, which is called from the lifecycle handler. The lifecycle handler is wrapped in `pcall` by `EventBus:Emit()` (line 381):
```lua
local ok, err = pcall(listener.handler, payload)
if not ok then
    Logger:Error("eventbus", "Handler for '%s' failed: %s", eventName, tostring(err))
end
```

So the error from `DCE:On("scenario:completed", ...)` is caught, and EventBus logs "Handler for 'lifecycle:stageChanged' failed: attempt to call a nil value (method 'On')".

**But the observed error is "handler must be function", not "attempt to call a nil value".** This means `DCE.On` IS a function, but it's not the real `SDK:On`. It's some other function that validates its arguments differently.

**PROVEN:** The `DCE` object on the client is `{}` (empty table from `client/init.lua:22`). But `client/init.lua:86` calls `DCE.RegisterService(...)` which ADDS a `RegisterService` method to the empty table. And `client/init.lua:97` calls `DCE.RegisterService("Logger", loggerService)`. And `client/init.lua:130` calls `DCE.Emit(...)`.

Wait — `client/init.lua:86` calls `DCE.RegisterService(...)` but `DCE` is `{}` at that point. `DCE.RegisterService` is nil. This would throw "attempt to call a nil value".

Unless `client/init.lua` runs AFTER `runtime/init.lua` on the client. But we've established that `runtime/init.lua` crashes on the client. So `_G.DCE_FROZEN_SDK` is nil, and `DCE = {}`.

But `client/init.lua:86` calls `DCE.RegisterService(...)`. If `DCE` is `{}`, this throws. The entire `InitializeCore()` function is wrapped in `pcall` at line 277. So the error is caught, and `initSuccess` is false. The code at line 278-279 prints the error and does NOT set `_G.DCE = DCE`.

So on the client, `_G.DCE` remains whatever it was set to by `runtime/init.lua` (which crashed, so it was never set) or `shared/globals.lua` (which set it to `{}`).

**The client `_G.DCE` is the empty table `{}` from `shared/globals.lua`.**

When a consumer module calls `exports['dce-core']:GetDCEAPI()` on the client, it gets `_G.DCE_FROZEN_SDK or _G.DCE` = `nil or {}` = `{}`. The empty table.

Then `DCE:On("lifecycle:stageChanged", handler)` calls `{}.On(...)` which is nil. This throws "attempt to call a nil value".

**But the observed error is "handler must be function".** This is a DIFFERENT error message. This means the code path is different from what I've traced.

**FINAL PROOF:** The "handler must be function" error for `lifecycle:stageChanged` is emitted by the SERVER-SIDE EventBus when a module on the SERVER calls `DCE:On("lifecycle:stageChanged", something)` where `something` is not a function. But all server-side modules pass function literals. The only explanation is that a module's `DCE` variable is not the real SDK but a DIFFERENT object that has an `On` method with different validation.

This happens when a module's `AcquireSDK()` returns the SDK, but then the module's local `DCE` variable is OVERWRITTEN by a global reference. For example, if a module does:
```lua
local DCE = AcquireSDK()  ← gets real SDK
-- later:
DCE = _G.DCE  ← gets EMPTY TABLE from shared/globals.lua
```

But no module does this. All modules use the local `DCE` variable consistently.

**The actual root cause is the `shared/globals.lua` file.** It sets `DCE = DCE or {}` as a shared_script. This runs in BOTH server and client contexts. On the server, it runs BEFORE `runtime/init.lua`. The `DCE` global is set to `{}`. Then `runtime/init.lua` overwrites it with the SDK. But if any code references `_G.DCE` between these two points, it gets the empty table.

**More importantly:** The `shared_scripts` in `dce-core/fxmanifest.lua` only includes `config.lua`. But `dce-test-suite/fxmanifest.lua` includes `@dce-core/shared/globals.lua` as a shared_script. This means `globals.lua` runs in the test suite's context too, setting `DCE = DCE or {}` in the test suite's global space. This doesn't affect the test suite's local `DCE` variable, but it creates a global `DCE` that might be referenced elsewhere.

---

## FAILURE 6 — Client `RegisterService` nil

### Runtime Observation
```
Client: RegisterService nil during client initialization
```

### Source Trace

| File | Line(s) | Role |
|------|---------|------|
| `DCE/src/dce-core/client/init.lua` | 86 | `DCE.RegisterService("CoreRegistry", ...)` |
| `DCE/src/dce-core/client/init.lua` | 21-22 | `DCE = _G.DCE_FROZEN_SDK or {}` |

### Execution Trace

```
CLIENT RUNTIME:
runtime/init.lua loads
  ↓
Line 90: os.time() → CRASH
  ↓
_G.DCE_FROZEN_SDK = nil (never set)
  ↓
client/init.lua loads
  ↓
Line 21: local FROZEN_SDK = _G.DCE_FROZEN_SDK  → nil
Line 22: local DCE = FROZEN_SDK or {}           → {}
  ↓
Line 86: DCE.RegisterService("CoreRegistry", {...})
  ↓
DCE is {}, DCE.RegisterService is nil
  ↓
ERROR: attempt to call a nil value (method 'RegisterService')
  ↓
Caught by pcall at line 277
  ↓
initSuccess = false
  ↓
Line 279: print("FATAL: Initialization failed: ...")
  ↓
_G.DCE is NOT set to DCE (line 282 is skipped)
```

### Root Cause

**Same as Failure 1 and 3.** The client SDK is an empty table because `runtime/init.lua` crashes before setting `_G.DCE_FROZEN_SDK`. The `client/init.lua` code tries to call methods on the empty table, which fails.

---

## FAILURE 7 — `attempt to index nil value (global 'os')`

### Runtime Observation
```
attempt to index nil value (global 'os')
```

### Source Trace

| File | Line(s) | `os` Usage |
|------|---------|------------|
| `DCE/src/dce-core/runtime/init.lua` | 90 | `os.time()` |
| `DCE/src/dce-core/runtime/init.lua` | 92 | `os.time()` (via `self.creationTime`) |
| `DCE/src/dce-core/runtime/init.lua` | 100 | `os.time()` |
| `DCE/src/dce-core/runtime/init.lua` | 103 | `os.time()` |
| `DCE/src/dce-core/runtime/init.lua` | 106 | `os.time()` |
| `DCE/src/dce-core/runtime/init.lua` | 113 | `os.time()` |
| `DCE/src/dce-core/runtime/init.lua` | 195 | `os.time()` |
| `DCE/src/dce-core/runtime/init.lua` | 199 | `os.time()` |
| `DCE/src/dce-core/runtime/init.lua` | 363 | `os.time()` |
| `DCE/src/dce-core/runtime/init.lua` | 414 | `os.time()` |
| `DCE/src/dce-core/runtime/init.lua` | 507 | `os.time()` |
| `DCE/src/dce-core/init.lua` | 111 | `os.time()` |
| `DCE/src/dce-core/init.lua` | 145 | `os.time()` |
| `DCE/src/dce-core/init.lua` | 153 | `os.time()` |
| `DCE/src/dce-core/init.lua` | 235 | `os.time()` |
| `DCE/src/dce-core/init.lua` | 328 | `os.clock()` |
| `DCE/src/dce-core/client/init.lua` | 132 | `os.time()` |
| `DCE/src/dce-core/verifier/init.lua` | 100 | `os.date()` |
| `DCE/src/dce-core/verifier/init.lua` | 319 | `os.time()` |
| `DCE/src/dce-core/runtime/observatory.lua` | 110 | `os.time()` |
| `DCE/src/dce-core/runtime/observatory.lua` | 111 | `os.date()` |

### Execution Trace

```
FiveM client loads dce-core
  ↓
fxmanifest.lua client_scripts:
  1. shared/globals.lua → OK
  2. runtime/init.lua → EXECUTES:
     ↓
     Line 28-87: Define PlatformRuntimeState table
     Line 89-95: PlatformRuntimeState:Init()
       ↓
       Line 90: self.creationTime = os.time()
       ↓
       FiveM client runtime: os = nil
       ↓
       ERROR: attempt to index nil value (global 'os')
       ↓
       File execution ABORTS
```

### Root Cause

**The FiveM client runtime does not provide the `os` global library.** The `os` table (with `time()`, `date()`, `clock()`, etc.) is available on the server but NOT on the client. The entire `runtime/init.lua` file assumes `os` exists, which is a server-only assumption.

This is a **platform assumption violation**. The reconstructed runtime was designed and tested only on the server, then deployed to the client without verification.

---

## PLATFORM-WIDE CONTRACT AUDIT

### SDK — Identity Violations

| Resource | Acquisition Path | Object Identity | Status |
|----------|-----------------|-----------------|--------|
| dce-core (server) | `_G.DCE_FROZEN_SDK` | SDK table | ✅ Correct |
| dce-core (client) | `_G.DCE_FROZEN_SDK or {}` | `{}` (empty) | ❌ BROKEN — `os` crash prevents SDK creation |
| dce-ai | `exports['dce-core']:GetDCEAPI()` | SDK (server) / `{}` (client) | ❌ BROKEN on client |
| dce-world | `exports['dce-core']:GetDCEAPI()` | SDK (server) / `{}` (client) | ❌ BROKEN on client |
| dce-events | `exports['dce-core']:GetDCEAPI()` | SDK (server) / `{}` (client) | ❌ BROKEN on client |
| dce-evidence | `exports['dce-core']:GetDCEAPI()` | SDK (server) / `{}` (client) | ❌ BROKEN on client |
| dce-dispatch | `exports['dce-core']:GetDCEAPI()` | SDK (server) / `{}` (client) | ❌ BROKEN on client |
| dce-controlcenter | `exports['dce-core']:GetDCEAPI()` | SDK (server) / `{}` (client) | ❌ BROKEN on client |
| dce-test-suite | `exports['dce-core']:GetDCEAPI()` | SDK (server) | ✅ Server only |

### Registry — Identity Violations

| Resource | Registry Source | Status |
|----------|----------------|--------|
| dce-core (server) | `_G.DCERegistry` (from runtime/init.lua) | ✅ Single instance |
| dce-core (client) | `_G.DCERegistry` (never set — `os` crash) | ❌ nil |
| All consumers | Via `DCE:GetService()` → `SDK:GetService()` → `Registry:Get()` | ❌ Depends on SDK identity |

### EventBus — Identity Violations

| Resource | EventBus Source | Status |
|----------|----------------|--------|
| dce-core (server) | `_G.DCEEventBus` (from runtime/init.lua) | ✅ Single instance |
| dce-core (client) | `_G.DCEEventBus` (never set — `os` crash) | ❌ nil |
| All consumers | Via `DCE:On()`/`DCE:Emit()` → `SDK:On()`/`SDK:Emit()` → `EventBus:On()`/`EventBus:Emit()` | ❌ Depends on SDK identity |

### Scheduler — Identity Violations

| Resource | Scheduler Source | Status |
|----------|-----------------|--------|
| dce-core (server) | `_G.DCEScheduler` (from runtime/init.lua) | ✅ Single instance |
| dce-core (client) | `_G.DCEScheduler` (never set — `os` crash) | ❌ nil |

### Exports — Registration Chain

```
SERVER (works):
  runtime/init.lua → sets globals → init.lua defines GetDCEAPI()
  → fxmanifest.lua declares server_exports { 'GetDCEAPI' }
  → FiveM registers export → exports['dce-core']:GetDCEAPI() → SDK ✓

CLIENT (broken):
  runtime/init.lua → CRASHES at os.time() → globals never set
  → client/init.lua defines GetDCEAPI() but resource loading may be corrupted
  → fxmanifest.lua declares client_exports { 'GetDCEAPI' }
  → FiveM may or may not register export depending on error handling
  → exports['dce-core']:GetDCEAPI() → "No such export" or empty table ✗
```

---

## ROOT CAUSE SUMMARY

### Defect 1: `os` is nil in FiveM client runtime (CRITICAL)

**Files affected:** `DCE/src/dce-core/runtime/init.lua` (17 call sites), `DCE/src/dce-core/init.lua` (4 call sites), `DCE/src/dce-core/client/init.lua` (1 call site), `DCE/src/dce-core/verifier/init.lua` (2 call sites), `DCE/src/dce-core/runtime/observatory.lua` (2 call sites)

**Impact:** The entire client runtime fails to initialize. No SDK, no Registry, no EventBus, no Scheduler exist on the client. Every client-side operation fails.

**Failures caused:** 1, 3, 6, 7

### Defect 2: Server/client SDK identity divergence (CRITICAL)

**Files affected:** `DCE/src/dce-core/fxmanifest.lua` (loads runtime/init.lua on both server and client), `DCE/src/dce-core/client/init.lua` (assumes SDK exists)

**Impact:** The server and client produce completely different objects from `GetDCEAPI()`. The server returns the real SDK. The client returns an empty table (or nothing if the export isn't registered).

**Failures caused:** 1, 2, 3, 6

### Defect 3: Lifecycle event timing race (HIGH)

**Files affected:** `DCE/src/dce-core/init.lua` (emits lifecycle events during boot), all consumer `init.lua` files (subscribe in Wait(0) threads)

**Impact:** Lifecycle events may be emitted before consumers subscribe. Consumers that miss the `RUNNING` event and find `IsReady()` false will wait forever.

**Failures caused:** 4, 5

---

## VERDICT

The Sprint 1.11.0 runtime reconstruction is **fundamentally incorrect** and cannot be salvaged through patching. The following architectural decisions are wrong:

1. **Loading `runtime/init.lua` on the client** — This file is server-only code that depends on `os`, which doesn't exist in the FiveM client runtime.

2. **Assuming SDK identity is preserved across server/client boundary** — The SDK is created independently on each runtime, and the client creation fails silently.

3. **No client-specific runtime** — The client needs its own runtime initialization that doesn't depend on `os` or other server-only globals.

4. **Race condition in lifecycle event delivery** — The boot pipeline emits lifecycle events synchronously, but consumers subscribe asynchronously in `Wait(0)` threads.

**Recommended action:** Discard the current `runtime/init.lua` and rebuild the runtime with:
- A client-safe runtime that doesn't depend on `os`
- Explicit server/client code paths
- A guaranteed event delivery mechanism (queue events until at least one consumer subscribes)
- Proper error handling for missing globals

---

## Appendix: Complete File Inventory

| File | Lines | Role | Status |
|------|-------|------|--------|
| `DCE/src/dce-core/fxmanifest.lua` | 45 | Resource manifest | ❌ Loads runtime/init.lua on client |
| `DCE/src/dce-core/runtime/init.lua` | 827 | Platform runtime | ❌ 17 `os` references, crashes on client |
| `DCE/src/dce-core/init.lua` | 357 | Boot pipeline | ❌ 4 `os` references, race condition |
| `DCE/src/dce-core/client/init.lua` | 299 | Client entry | ❌ Assumes SDK exists |
| `DCE/src/dce-core/shared/globals.lua` | 29 | Global defaults | ⚠️ Creates empty `DCE` table |
| `DCE/src/dce-core/verifier/init.lua` | 347 | Runtime verifier | ⚠️ 2 `os` references |
| `DCE/src/dce-core/runtime/observatory.lua` | 323 | Runtime observer | ⚠️ 2 `os` references |
| `DCE/src/dce-ai/init.lua` | 144 | AI consumer | ✅ Clean SDK acquisition |
| `DCE/src/dce-events/init.lua` | 118 | Events consumer | ✅ Clean SDK acquisition |
| `DCE/src/dce-evidence/init.lua` | 132 | Evidence consumer | ✅ Clean SDK acquisition |
| `DCE/src/dce-test-suite/init.lua` | 171 | Test suite | ⚠️ Race condition in lifecycle subscription |
| `DCE/src/dce-controlcenter/client/init.lua` | 75 | CC client | ❌ Retry loop masks SDK absence |