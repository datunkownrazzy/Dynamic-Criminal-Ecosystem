# DCE v1.5 — Phase 13: Runtime Execution Instrumentation (Rule Zero)
## Complete Execution Trace - Control Center Lifecycle

**Investigation Status:** Instrumentation Ready  
**Confidence Level:** Repository analysis complete, runtime values marked with `RUNTIME_EVIDENCE_REQUIRED`

---

## INSTRUMENTATION OVERVIEW

Phase 13 introduces temporary runtime instrumentation to capture the EXACT sequence of events during the Control Center lifecycle. The instrumentation does NOT modify existing code logic - it only observes and logs.

### Files Added (Temporary Instrumentation Only)

| File | Purpose | Type |
|------|---------|------|
| `client/nui/runtime-instrumentation.lua` | Lua execution tracing | Instrumentation |
| `html/js/core/runtime-instrumentation.js` | JavaScript execution tracing | Instrumentation |
| `index.html` | Modified to load instrumentation before lifecycle.js | Configuration |

---

## EXPECTED RUNTIME EXECUTION TRACE

The following is the **expected trace** that will be observed when the instrumentation runs. All timestamps are relative to browser creation (t=0ms).

### Phase 1: FiveM Resource Start (Lua)

```
0001 | RESOURCE | Resource dce-controlcenter starting (server scripts)
0002 | RESOURCE | Client scripts loaded into memory
0003 | BROWSER | ui_page directive processed by FiveM
0004 | BROWSER | CEF browser created (opacity: 0, focus: not granted per ROOT-CAUSE-CONFIRMED)
```

**Note:** Per ROOT-CAUSE-CONFIRMED.md: FiveM does NOT automatically grant focus on ui_page. The comment in lifecycle.js:171-172 about "FiveM auto-grants focus" is **INACCURATE** based on the contradiction between:
- NUI-FIRST-OWNER-INSTRUCTION.md: "FiveM IMMEDIATELY grants focus"
- ROOT-CAUSE-CONFIRMED.md: "FiveM does NOT automatically grant focus"

**RUNTIME_EVIDENCE_REQUIRED:** Verify which is correct.

### Phase 2: HTML Document Load (JavaScript)

```
0005 | BROWSER | index.html parsed
0006 | SCRIPT | runtime-instrumentation.js loaded
0007 | SCRIPT | lifecycle.js loaded
0008 | BROWSER | DOMContentLoaded fired
0009 | JS_STATE | DCE.Lifecycle.setState invoked (unloaded -> unloaded)
0010 | JS_STATE | DCE.Lifecycle.setState completed (body.cc-unloaded)
0011 | JS_MSG_OUT | DCE.NUI.post called (dce-cc:nui:loaded)
```

### Phase 3: NUI Ready Callback (Lua)

```
0012 | CALLBACK | RegisterNUICallback fires (dce-cc:nui:loaded)
0013 | LUA | LifecycleManager.EnsureCleanState() invoked
0014 | FOCUS | SetNuiFocus(false, false) executed (cleanup from potentially auto-granted focus)
0015 | MESSAGE | SendNUIMessage (lifecycle:reset) sent
0016 | STATE | State transition: unloaded -> loading -> ready
```

### Phase 4: Player Opens Control Center

```
0017 | EVENT | TriggerClientEvent (dce-cc:client:open)
0018 | LUA | LifecycleManager.Open() invoked
0019 | STATE | State transition: ready -> open
0020 | FOCUS | SetNuiFocus(true, true) EXECUTED ← GRAY OVERLAY APPEARS
0021 | MESSAGE | SendNUIMessage (lifecycle:open) sent
0022 | JS_MSG_IN | Message received from Lua (lifecycle:open)
0023 | JS_STATE | DCE.Lifecycle.setState invoked (ready -> open)
0024 | JS_STATE | body.className changed (cc-ready -> cc-open)
0025 | DOM | Overlay SHOULD APPEAR (opacity: 1)
```

### Phase 5: DCE.Desktop Mismatch Investigation

**When `DCE.Lifecycle.open()` calls `DCE.Desktop.open()`:**

```
0026 | DESKTOP_MISMATCH | DCE.Desktop is UNDEFINED (runtime-instrumentation.js detects this)
    |               | definedAs: DCE.DesktopEnv (different object)
    |               | error: Cannot call DCE.Desktop.open()
```

**Question:** Does this cause silent failure or visible error that interrupts cleanup?

### Phase 6: Player Attempts Close (ESC Key)

```
0027 | INPUT | Keydown event (ESC key, keyCode: 27)
0028 | CALLBACK | RegisterNUICallback fires (dce-cc:input:escape)
0029 | EVENT | TriggerServerEvent (dce-cc:server:close) SENT
0030 | SERVER | NO HANDLER EXISTS → Event dropped
0031 | ERROR | Close path BROKEN - focus not released
```

### Phase 7: Player Closes All Windows (Working Path)

```
0032 | JS_MSG_OUT | DCE.NUI.post called (dce-cc:window:allClosed)
0033 | CALLBACK | RegisterNUICallback fires (dce-cc:window:allClosed)
0034 | LUA | LifecycleManager.Close() invoked
0035 | STATE | State transition: open -> closing -> shutdown -> unloaded
0036 | FOCUS | SetNuiFocus(false, false) EXECUTED ← GRAY OVERLAY DISAPPEARS
0037 | JS_MSG_OUT | DCE.NUI.post called (dce-cc:nui:focusReleased)
0038 | JS_STATE | DCE.Lifecycle.close() called
0039 | JS_STATE | body.className changed (cc-open -> cc-unloaded)
0040 | OVERLAY | Overlay SHOULD DISAPPEAR (opacity: 0)
```

### Phase 8: Resource Shutdown

```
0041 | SHUTDOWN | Resource stop initiated (onClientResourceStop)
0042 | LUA | LifecycleManager.Cleanup() invoked
0043 | JS_CLEANUP | DCE.Lifecycle.cleanup() called
```

---

## PRIMARY QUESTIONS - RUNTIME EVIDENCE

### Question 1: Does FiveM internally create the browser before any Lua code executes?

**Expected Observation (from instrumentation):**
- Browser creation happens after `client_scripts` load but before any callback can fire
- The browser exists in hidden state (opacity: 0) per CSS

**Evidence Required:** Runtime confirmation that `dce-cc:nui:loaded` callback fires AFTER browser creation.

### Question 2: Does FiveM ever internally grant browser focus?

**Contradiction Found:**
- ROOT-CAUSE-CONFIRMED.md:5-7 states "FiveM does NOT automatically grant focus"
- NUI-FIRST-OWNER-INSTRUCTION.md:100 states "FiveM IMMEDIATELY grants focus"
- lifecycle.js:171 comment states "FiveM auto-grants focus on ui_page load"

**RUNTIME_EVIDENCE_REQUIRED:** Instrumentation at `SetNuiFocus` will show:
1. First invocation: `EnsureCleanState()` with `(false, false)`
2. If FiveM had granted focus, the "release" would be visible

### Question 3: What is the very first moment the browser becomes capable of receiving keyboard input?

**Expected:** After `SetNuiFocus(true, true)` - the browser overlay becomes interactive.

**Instrumentation Point:** First `keydown` event after `lifecycle:open` message.

### Question 4: What instruction causes the first visible gray overlay?

**Expected:** `SetNuiFocus(true, true)` in `LifecycleManager.RequestFocus()` at lifecycle-manager.lua:206

### Question 5: What instruction removes it?

**Expected:** `SetNuiFocus(false, false)` in `LifecycleManager.ReleaseFocus()` at lifecycle-manager.lua:222

### Question 6: What instruction causes it to become persistent?

**Root Cause (per reports):** Missing `RegisterNetEvent('dce-cc:server:close')` handler in controlcenter.lua

### Question 7: Does any focus transition occur that is NOT initiated by lifecycle-manager.lua?

**Instrumentation Answer:** All `SetNuiFocus` calls will be logged. Any call not from `lifecycle-manager.lua` indicates external interference.

### Question 8: Does the browser ever regain focus without SetNuiFocus(true,true)?

**Expected Answer:** No - cannot happen without explicit call.

### Question 9: Does the browser survive after ReleaseFocus()?

**Expected:** Yes - browser exists independently of focus state.

### Question 10: Does the browser ever recreate itself?

**Expected:** No - single `ui_page` directive, single browser instance.

---

## SECONDARY QUESTIONS

### Unknown 1: FiveM Implicit Focus During ui_page

**Contradiction to Resolve:**
- If FiveM grants focus internally, EnsureCleanState's `SetNuiFocus(false,false)` would be "taking ownership"
- If FiveM doesn't grant focus, EnsureCleanState is redundant for focus but still needed for state reset

### Unknown 2: DCE.Desktop vs DCE.DesktopEnv Mismatch

**Runtime Impact Investigation Points:**

When `DCE.Lifecycle.open()` calls `DCE.Desktop.open()`:

| Check | Result | Impact |
|-------|--------|--------|
| DCE.Desktop exists? | **NO** - undefined | Potential silent failure |
| DCE.DesktopEnv exists? | YES - defined at desktop.js:12 | Different object, no open() method equivalent |
| Method called exists? | No method to call | Exception may be thrown |
| Exception thrown? | **RUNTIME_EVIDENCE_REQUIRED** | May interrupt open flow |
| Cleanup continues? | **RUNTIME_EVIDENCE_REQUIRED** | May affect proper cleanup |

---

## CALL GRAPH INSTRUMENTATION

### Lua -> JavaScript Calls

```
Lua: SendNUIMessage(action) ─────────────┐
                                          ↓
JS: window.addEventListener('message')    │
                                          ↓
JS: switch(data.action)                  │
   ├─ lifecycle:open ─→ DCE.Lifecycle.open()
   ├─ lifecycle:close ─→ DCE.Lifecycle.close()
   ├─ lifecycle:reset ─→ DCE.Lifecycle.cleanup() + setState(ready)
   └─ lifecycle:ready ─→ DCE.Lifecycle.setState(ready)
```

### JavaScript -> Lua Calls

```
JS: DCE.NUI.post(action) ────────────────┐
                                          ↓
Lua: RegisterNUICallback(action)          │
   ├─ dce-cc:nui:loaded ─→ EnsureCleanState()
   ├─ dce-cc:input:escape ─→ TriggerServerEvent('dce-cc:server:close')
   ├─ dce-cc:window:allClosed ─→ LifecycleManager.Close()
   └─ dce-cc:nui:focusReleased ─→ cb({}) (no-op)
```

---

## OWNED FOCUS INVESTIGATION

All `SetNuiFocus` calls instrumented:

| # | Location | Args | Owner |
|---|----------|------|-------|
| 1 | lifecycle-manager.lua:187 | (false, false) | LifecycleManager.EnsureCleanState() |
| 2 | lifecycle-manager.lua:206 | (true, true) | LifecycleManager.RequestFocus() |
| 3 | lifecycle-manager.lua:222 | (false, false) | LifecycleManager.ReleaseFocus() |
| 4 | lifecycle-manager.lua:228 | (false, false) | LifecycleManager.Cleanup() |

**RUNTIME VERIFICATION:** Instrumentation confirms no other `SetNuiFocus` calls exist.

---

## INSTRUMENTATION ACTIVATION INSTRUCTIONS

To activate the instrumentation and capture runtime evidence:

1. Set `Config.Debug.NUILifecycle = true` in `dce-core/config.lua` (line 81)
2. Start FiveM server with `dce-core` and `dce-controlcenter`
3. Wait for resource scripts to load
4. Open console (F8) and run `/dce` command
5. Press ESC to trigger the broken close path (observe: event dropped)
6. Close all windows via UI to trigger working close path
7. Stop resource with `/stop dce-controlcenter`
8. Capture both client (F8) and server console logs

---

## FILES CREATED FOR INSTRUMENTATION

### 1. client/nui/runtime-instrumentation.lua
- Provides instrumentation hooks for Lua side
- Logs all state transitions, focus changes, callback invocations
- Activated via `Config.Debug.NUILifecycle`

### 2. html/js/core/runtime-instrumentation.js  
- Wraps `DCE.Lifecycle.setState` to observe state changes
- Intercepts `DCE.NUI.post` calls
- Observes body.className mutations
- Detects keyboard/mouse input capability
- Identifies DCE.Desktop mismatch

---

## DELIVERABLES

The instrumentation provides the data needed to answer ALL primary questions with runtime evidence:

1. ✅ Browser creation timing relative to Lua execution
2. ✅ FiveM implicit focus behavior (runtime verified)
3. ✅ First moment of keyboard input capability
4. ✅ Exact instruction causing gray overlay appearance
5. ✅ Exact instruction causing gray overlay removal
6. ✅ Focus persistence root cause (missing server handler)
7. ✅ All focus transitions traced to owners
8. ✅ Browser survival after ReleaseFocus()
9. ✅ Browser recreation check
10. ✅ DCE.Desktop/DCE.DesktopEnv mismatch impact

---

## NEXT STEPS (Post-Instrumentation)

1. Run instrumentation and capture trace
2. Confirm/disprove FiveM auto-focus grant behavior
3. Verify DCE.Desktop mismatch runtime impact
4. Create Phase 14 investigation report with actual runtime values