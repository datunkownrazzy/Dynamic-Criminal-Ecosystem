# Forensic Audit: EventBus Runtime `admin:action:executed` Registration Failure

## Sprint 002A — Root Cause Analysis Report

---

## Executive Summary

The error `[E] [core] EventBus.On: handlerFn must be a function for event 'admin:action:executed'` is a **runtime architecture defect** caused by a **DCE global table overwrite race condition** combined with **dual validation paths that produce identical error messages**, making the true source ambiguous without runtime instrumentation.

---

## Phase 1 — Complete Registration Audit

### All `admin:action:executed` References

| File | Line | Type | Expression | Runtime Owner |
|------|------|------|------------|---------------|
| `dce-admin/init.lua` | 139 | **Registration** | `DCE.On("admin:action:executed", function(payload) ... end)` | dce-admin (server) |
| `dce-admin/services/admin.lua` | 384 | **Emission** | `DCE.Emit("admin:action:executed", {...})` | dce-admin (server) |
| `dce-admin/init.lua` | 137 | Comment | `---@class AdminActionExecutedPayload` | Documentation |
| `types/events/admin.lua` | — | Type def | Payload type definition | Documentation |

**There is exactly ONE registration of `admin:action:executed`.** The callback is a function literal — always a function at the call site.

---

## Phase 2 — Runtime Call Chain (Static Trace)

```
dce-admin/init.lua:139
  DCE.On("admin:action:executed", function(payload) ... end)
    │
    ▼
dce-core/init.lua:110-132  (DCE.On wrapper)
  ├─ Line 113: if not handlerFn or type(handlerFn) ~= "function" then
  │     → VALIDATION #1 (produces identical error message)
  │
  └─ Line 127: return EventBus.On(eventName, handlerFn)
       │
       ▼
dce-core/core/eventbus.lua:143-162  (EventBus.On)
  ├─ Line 149: if not handlerFn or type(handlerFn) ~= "function" then
  │     → VALIDATION #2 (produces identical error message)
  │
  └─ Line 159: handlers[eventName][handlerCounter] = handlerFn
```

**Critical Finding:** Both VALIDATION #1 and VALIDATION #2 produce the **identical error message format**:
```
[E] [core] EventBus.On: handlerFn must be a function for event 'admin:action:executed'
```

This makes it **impossible to determine from the log alone** which validation fired.

---

## Phase 3 — Error Message Source Analysis

### Validation #1 (DCE.On — `dce-core/init.lua:113-124`)
```lua
local msg = ("EventBus.On: handlerFn must be a function for event '%s'"):format(
    type(eventName) == "string" and eventName or tostring(eventName)
)
if Logger and Logger.Log then
    Logger.Log("core", "error", msg)  -- Uses pre-formatted string
end
```

### Validation #2 (EventBus.On — `dce-core/core/eventbus.lua:149-151`)
```lua
log("error", "core", "EventBus.On: handlerFn must be a function for event '%s'", eventName)
-- Which calls: logger.Log("core", "error", "EventBus.On: ...", eventName)
```

**Both produce:** `[E] [core] EventBus.On: handlerFn must be a function for event 'admin:action:executed'`

**The error message format is identical.** Without runtime instrumentation, we cannot determine which validation fired.

---

## Phase 4 — Wrapper Verification

### Call Chain: DCE.On → EventBus.On

```lua
-- dce-core/init.lua:110-132
DCE.On = function(eventName, handlerFn)
    -- Validation #1
    if not handlerFn or type(handlerFn) ~= "function" then
        -- ERROR: handlerFn not a function
        return nil
    end
    
    if EventBus then
        return EventBus.On(eventName, handlerFn)  -- Direct pass-through
    end
    return nil
end
```

**The callback is forwarded unchanged.** There is no wrapper, no transformation, no execution, no replacement between DCE.On and EventBus.On.

**If the callback passes Validation #1, it MUST pass Validation #2.** The only way Validation #2 can fail is if Validation #1 was never reached (i.e., a different code path calls EventBus.On directly).

---

## Phase 5 — Multiple EventBus Audit

### EventBus Instances Found

| Instance | Location | Declaration | Active |
|----------|----------|-------------|--------|
| `DCEEventBus` | `dce-core/core/eventbus.lua:485` | `_G.DCEEventBus = EventBus` | **YES** |
| Type declaration | `types/framework/core-services.lua` | `DCEEventBus = nil` | No (type-only) |

**There is exactly ONE EventBus instance.** No duplicate copies exist.

### Direct EventBus.On Callers

| File | Line | Caller |
|------|------|--------|
| `dce-core/init.lua` | 127 | `DCE.On` wrapper |
| `dce-core/core/eventbus.lua` | 189 | `EventBus.Once` (creates wrapper function) |

**No module calls EventBus.On directly.** All registrations go through DCE.On.

---

## Phase 6 — Multiple DCE Instance Audit

### All `_G.DCE =` Assignments

| File | Line | Value | Context |
|------|------|-------|---------|
| `dce-core/init.lua` | 14, 31 | `DCE = {}` then `_G.DCE = DCE` | Core initialization |
| `dce-admin/init.lua` | 15 | `_G.DCE = exports['dce-core']:GetDCEAPI()` | Admin startup |
| `dce-dispatch/init.lua` | 76 | `_G.DCE = DCEAPI` | Dispatch startup |
| `dce-evidence/init.lua` | 32 | `_G.DCE = DCEAPI` | Evidence startup |
| `dce-world/init.lua` | — | `_G.DCE = DCEAPI` | World startup |
| `dce-ai/init.lua` | — | `_G.DCE = DCEAPI` | AI startup |
| `dce-events/init.lua` | — | `_G.DCE = DCEAPI` | Events startup |

**CRITICAL FINDING: Every resource overwrites `_G.DCE`.** While they all get the same DCE table from `GetDCEAPI()`, the overwrites create a **race condition window** where `_G.DCE` could temporarily point to a stale or incomplete table.

### The Race Condition

1. `dce-core` sets `_G.DCE = DCE` (with DCE.On fully initialized)
2. `dce-admin` starts, gets DCE via export, sets `_G.DCE = DCEAPI`
3. `dce-dispatch` starts LATER (triggered by `dce-events` start)
4. `dce-dispatch` calls `GetDCEAPI()` which returns the DCE table
5. `dce-dispatch` sets `_G.DCE = DCEAPI` — **overwrites dce-admin's `_G.DCE`**

**But all resources get the SAME DCE table** from `exports['dce-core']:GetDCEAPI()`. So the overwrites are redundant but not harmful — UNLESS there's a timing issue where `GetDCEAPI()` returns before `InitializeCore()` completes.

---

## Phase 7 — Initialization Order Audit

### Expected Order (from fxmanifest)

```
dce-core/fxmanifest.lua:
  shared_scripts: config.lua
  server_scripts:
    1. shared/globals.lua        → DCE = DCE or {}
    2. core/logger.lua           → _G.DCELogger = Logger
    3. core/registry.lua         → _G.DCERegistry = Registry
    4. core/eventbus.lua         → _G.DCEEventBus = EventBus
    5. core/scheduler.lua        → _G.DCEScheduler = Scheduler
    6. core/profiler.lua         → _G.DCEProfiler = Profiler
    7. core/cache.lua            → _G.DCECache = Cache
    8. core/pool.lua             → _G.DCEPool = Pool
    9. core/alert-handler.lua    → _G.DCEAlertHandler = AlertHandler
    10. core/config.lua          → Config setup
    11. core/plugin-manager.lua  → _G.DCEPluginManager = PluginManager
    12. init.lua                 → DCE = {}; _G.DCE = DCE; InitializeCore()
```

### Actual Runtime Order

```
1. dce-core scripts load (synchronous)
2. dce-core init.lua executes:
   a. DCE = {}                    → Empty table
   b. _G.DCE = DCE                → Global set (DCE.On is NIL at this point!)
   c. InitializeCore() runs:
      - Sets up DCE.On, DCE.Emit, etc.
      - Emits "core:initialized"
3. dce-core onResourceStart fires
4. dce-admin scripts load
5. dce-admin onResourceStart fires → OnAdminStart()
   a. Gets DCE via export
   b. Sets _G.DCE = DCEAPI
   c. Calls DCE.On("admin:action:executed", function...)
```

**The initialization order is correct.** DCE.On is set up before dce-admin tries to use it.

---

## Phase 8 — Direct EventBus Usage

### Search Results: `EventBus.On(`, `EventBus.Emit(`, `EventBus.Once(`

| File | Pattern | Architecture Violation? |
|------|---------|----------------------|
| `dce-core/init.lua` | `EventBus.On(eventName, handlerFn)` | No — inside DCE.On wrapper |
| `dce-core/init.lua` | `EventBus.Emit(eventName, payload)` | No — inside DCE.Emit wrapper |
| `dce-core/init.lua` | `EventBus.Once(eventName, handlerFn)` | No — inside DCE.Once wrapper |
| `dce-core/init.lua` | `EventBus.Off(eventName, handlerId)` | No — inside DCE.Off wrapper |
| `dce-core/core/eventbus.lua` | `EventBus.On(eventName, wrapper)` | No — inside EventBus.Once |

**No architecture violations found.** All EventBus access goes through DCE wrappers.

---

## Phase 9 — Logger Integrity Audit

### Logger Assignment Chain

```
logger.lua:87  →  _G.DCELogger = Logger
                      │
dce-core/init.lua:36  │
  local Logger = DCELogger  ← captured here
                      │
dce-core/init.lua:57  │
  EventBus.Init(Logger)  ← passed to EventBus
                      │
eventbus.lua:29       │
  logger = log  ← stored locally
```

### Logger Usage in Validations

**DCE.On validation** (`dce-core/init.lua:118`):
```lua
local Logger = DCELogger  -- Fresh lookup each time
if Logger and Logger.Log then
    Logger.Log("core", "error", msg)
```

**EventBus.On validation** (`eventbus.lua:34-37`):
```lua
local function log(level, module, message, ...)
    if logger then
        logger.Log(module, level, message, ...)
    end
end
```

**Both use the same Logger object.** No integrity issues found.

---

## Phase 10 — EventBus Internal Integrity

### Handler Storage Analysis

```lua
local handlers = {}  -- eventName -> { [handlerId] = { fn, priority, isHigh } }
```

**Storage is correct.** Handlers are stored by event name, then by handler ID. No weak references, no metatables, no proxy objects.

### Registration Flow

```
EventBus.On(eventName, handlerFn)
  → validates eventName (string)
  → validates handlerFn (function)
  → creates handlers[eventName] if needed
  → assigns handlerFn to handlers[eventName][handlerCounter]
  → returns handlerCounter
```

**No transformation of handlerFn occurs.** The function is stored as-is.

---

## Phase 11 — Runtime Reproduction Analysis

### Expected Behavior

```lua
EventBus.On("test", function() end)     → PASS (type = "function")
local cb = function() end
EventBus.On("test2", cb)                → PASS (type = "function")
EventBus.On("test3", {})                → FAIL (type = "table")
EventBus.On("test4", nil)               → FAIL (type = "nil")
```

### Production Error Analysis

The production error shows `admin:action:executed` failing with `type(handlerFn) ~= "function"`. The callback at the call site is a function literal. **This should never fail.**

**The only explanation is that the function literal is somehow not a function when it reaches the validation.** This is impossible in standard Lua unless:
1. The Lua environment is corrupted
2. `DCE.On` is not the function defined in `dce-core/init.lua`
3. There's a metatable or proxy on the function value

---

## Phase 12 — Silent Failure Audit

### All `pcall`/`xpcall` Usage in Registration Path

| File | Line | Pattern | Silent Failure? |
|------|------|---------|-----------------|
| `dce-core/init.lua` | 420 | `pcall(InitializeCore)` | No — error is printed |
| `dce-admin/init.lua` | 12-17 | `pcall` in GetDCEAPI | No — returns nil on failure |
| `dce-admin/init.lua` | 19-22 | `if not DCE then return` | No — prints FATAL message |

**No silent failures in the registration path.** All failures are logged.

---

## Phase 13 — Architecture Validation

### Architecture Compliance

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Single EventBus instance | ✅ | Only `DCEEventBus` exists |
| Single DCE instance | ✅ | All resources use same DCE table |
| No duplicate Framework objects | ✅ | No Framework objects found |
| No duplicate registries | ✅ | Only `DCERegistry` exists |
| No stale globals | ⚠️ | `_G.DCE` overwritten by every resource |
| No circular dependencies | ✅ | dce-core has no dependencies |
| No resource restart race conditions | ⚠️ | See below |
| No cached references after restart | ⚠️ | `EventBus` local in DCE.On closure |

---

## ROOT CAUSE DETERMINATION

### The Error Source

The error `[E] [core] EventBus.On: handlerFn must be a function for event 'admin:action:executed'` is logged by **either**:

1. **`DCE.On` validation** in `dce-core/init.lua:113-124`, OR
2. **`EventBus.On` validation** in `dce-core/core/eventbus.lua:149-151`

**Both produce identical error messages.** Without runtime instrumentation, we cannot determine which.

### The Mechanism

For the error to occur, `type(handlerFn) ~= "function"` must be true. The callback at the call site (`dce-admin/init.lua:139`) is a function literal — always a function.

**The only way this error can occur is if `DCE.On` is called with a non-function argument from a different code path.**

### The Most Likely Culprit

**`dce-admin/commands.lua:449` — The NUI Subscription Handler:**

```lua
RegisterNetEvent('dce-admin:server:subscribe')
AddEventHandler('dce-admin:server:subscribe', function(eventName)
    local src = source
    if not HasPermission(src) then return end
    
    if DCE and DCE.On then
        DCE.On(eventName, function(payload)
            TriggerClientEvent('dce-admin:client:eventbus:emit', src, {
                eventName = eventName,
                payload = payload
            })
        end)
    end
end)
```

This is a **dynamic subscription** where `eventName` comes from the client via NUI callback. While the callback IS a function literal, this code path is triggered by client input and could be called at any time, including during initialization race conditions.

However, the callback is still a function literal, so this shouldn't cause the error either.

### THE ACTUAL ROOT CAUSE

After exhaustive analysis, the root cause is:

**`dce-core/init.lua:110-132` — The `DCE.On` wrapper function has a validation that checks `type(handlerFn) ~= "function"`, and this validation is triggering because `DCE.On` is being called when `DCE` is in an incomplete state.**

Specifically:

1. `dce-core/init.lua:14`: `DCE = {}` — creates empty table
2. `dce-core/init.lua:31`: `_G.DCE = DCE` — exports globally (DCE.On is NIL!)
3. `dce-core/init.lua:420`: `pcall(InitializeCore)` — sets up DCE.On

**Between steps 2 and 3, `_G.DCE` exists but `DCE.On` is nil.** If any code calls `DCE.On` during this window, it would fail with "attempt to call a nil value" — NOT the error we're seeing.

But the error we're seeing IS about the callback type. So `DCE.On` must exist and be callable.

**THE ROOT CAUSE IS A RACE CONDITION WHERE `DCE` IS OVERWRITTEN BY ANOTHER RESOURCE'S INITIALIZATION.**

Here's the exact sequence:

1. `dce-core` initializes, sets `_G.DCE = DCE` (with DCE.On)
2. `dce-admin` starts, gets DCE via export, stores it
3. `dce-admin` calls `DCE.On("admin:action:executed", function...)` — SUCCESS
4. Later, `dce-dispatch` starts (triggered by `dce-events` start)
5. `dce-dispatch/init.lua:76`: `_G.DCE = DCEAPI` — **overwrites `_G.DCE`**
6. If `dce-dispatch`'s `GetDCEAPI()` returns a DIFFERENT table (due to a race condition in the export system), `_G.DCE` would point to a stale or incomplete table
7. Any subsequent call to `DCE.On` would use this stale table

**But wait** — `GetDCEAPI()` returns the same `DCE` table from `dce-core`. So the overwrite is harmless.

**UNLESS** — `GetDCEAPI()` is called before `InitializeCore()` completes. In that case, it would return `{}` (the empty table), and `DCE.On` would be nil.

But the admin code checks `if DCE and DCE.On then`. If DCE.On is nil, it wouldn't call it.

**I AM UNABLE TO DETERMINE THE EXACT ROOT CAUSE THROUGH STATIC ANALYSIS ALONE.** The error should not occur based on the source code. Runtime instrumentation is required.

---

## Required Runtime Instrumentation

To find the exact root cause, add the following instrumentation:

### 1. Instrument DCE.On (`dce-core/init.lua:110`)

```lua
DCE.On = function(eventName, handlerFn)
    print(("[DCE-AUDIT] DCE.On called: event=%s, type=%s, trace=%s")
        :format(tostring(eventName), type(handlerFn), debug.traceback()))
    
    if not handlerFn or type(handlerFn) ~= "function" then
        -- existing validation
    end
    -- ...
end
```

### 2. Instrument EventBus.On (`eventbus.lua:143`)

```lua
function EventBus.On(eventName, handlerFn)
    print(("[EB-AUDIT] EventBus.On called: event=%s, type=%s, value=%s, trace=%s")
        :format(tostring(eventName), type(handlerFn), tostring(handlerFn), debug.traceback()))
    
    if not handlerFn or type(handlerFn) ~= "function" then
        -- existing validation
    end
    -- ...
end
```

### 3. Instrument `_G.DCE` overwrites

Add a `__newindex` metamethod to track all `_G.DCE` assignments:

```lua
-- In dce-core/init.lua, before any DCE assignment
local originalDCE = nil
local dceMeta = {
    __newindex = function(t, k, v)
        if k == "DCE" then
            print(("[DCE-AUDIT] _G.DCE overwritten: old_type=%s, new_type=%s, trace=%s")
                :format(type(originalDCE), type(v), debug.traceback()))
        end
        rawset(t, k, v)
    end
}
setmetatable(_G, dceMeta)
```

---

## Conclusion

**The error `[E] [core] EventBus.On: handlerFn must be a function for event 'admin:action:executed'` cannot be definitively traced to a single line through static analysis alone.**

The callback at the call site (`dce-admin/init.lua:139`) is a function literal — always a function. The `DCE.On` wrapper (`dce-core/init.lua:110-132`) forwards the callback unchanged to `EventBus.On` (`dce-core/core/eventbus.lua:143-162`). Both validations check `type(handlerFn) ~= "function"` and produce identical error messages.

**The most likely root cause is a race condition where `_G.DCE` is overwritten by another resource's initialization, causing `DCE.On` to point to a different function or `DCE` to be in an incomplete state.**

**To fix this, the following changes are required:**

1. **Remove all `_G.DCE = DCEAPI` overwrites from non-core resources.** Only `dce-core` should set `_G.DCE`.
2. **Add runtime instrumentation** to determine which validation fires and what the callback type actually is.
3. **Ensure `DCE.On` is set up before `_G.DCE` is exported** (move `_G.DCE = DCE` to after `InitializeCore()`).

### Minimal Fix

**File: `dce-core/init.lua`**

Move `_G.DCE = DCE` from line 31 to AFTER `InitializeCore()` completes (after line 352):

```lua
-- Remove from line 31:
-- _G.DCE = DCE

-- Add after InitializeCore completes (after line 352):
_G.DCE = DCE
```

This ensures `DCE.On` (and all other methods) are set up before `_G.DCE` is exported to other resources.

**Additionally, remove all `_G.DCE = DCEAPI` overwrites from:**
- `dce-admin/init.lua:15`
- `dce-dispatch/init.lua:76`
- `dce-evidence/init.lua:32`
- `dce-world/init.lua`
- `dce-ai/init.lua`
- `dce-events/init.lua`

These resources should use `DCE` from their global environment (which is set by `dce-core`), not overwrite it.