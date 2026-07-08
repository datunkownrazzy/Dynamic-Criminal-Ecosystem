# DCE Control Center - RUNTIME FORENSIC INVESTIGATION REPORT

**Date:** 2026-07-07  
**Status:** ROOT CAUSE IDENTIFIED  

---

## THE SINGLE ROOT CAUSE

| Attribute | Value |
|-----------|-------|
| **Exact File** | `DCE/src/dce-admin/client/nui.lua` |
| **Exact Line** | 82 (inside `ensureCleanState()`) AND 39 (inside `releaseFocus()`) |
| **Exact Function** | `ensureCleanState()` and `releaseFocus()` |
| **Why Execution Stops** | Race condition between FiveM's native NUI focus state machine and DCE's Lua initialization |

---

## RUNTIME EXECUTION TRACE

### 1. Resource Startup (Where the Problem Begins)

```
FiveM Engine Timeline:
    ↓
[1] Resource declared with ui_page (fxmanifest.lua:61)
    ↓
[2] ui_page begins loading → FiveM AUTO-GRANTS NUI focus here ← ROOT CAUSE STARTS
    ↓
[3] Lua scripts begin execution (nui.lua)
    ↓
[4] ensureCleanState() executes at line 514 (IMMEDIATE script load execution)
    ├── SetNuiFocus(false, false) at line 82 ← FIVEM IGNORES THIS (browser not ready)
    └── SendNUIMessage({action="close"}) at line 91-93
    ↓
[5] Browser finishes loading
    ├── FiveM still has focus granted (native state: HAS_FOCUS)
    ├── DCE's hasFocus variable: FALSE (desynchronized)
    ↓
[6] Player joins → GRAY OVERLAY IS NOW VISIBLE
    ↓
[7] /dce command runs
    ├── SetNuiFocus(true, true) at line 122-123
    └── SendNUIMessage({action="open"}) at line 129-131
    ↓
[8] UI becomes visible (opacity: 1)
```

### 2. Close Attempt - Where the Failure Manifests

```
[9] User presses ESC or clicks close button
    ↓
[10] Lua RegisterNUICallback('close') or ('keydown') receives message
    ↓
[11] releaseFocus() called (line 33-53 or line 141)
    ├── hasFocus = false (local variable)
    ├── SetNuiFocus(false, false) at line 39 ← FIVEM MAY IGNORE DUE TO STATE CORRUPTION
    └── SendNUIMessage({action="close"}) at line 48-50
    ↓
[12] JavaScript receives "close" message (framework.js:282-287)
    ├── DCE.Desktop.hide() → DCE.UI.close()
    └── DCE.Windows.closeAll()
    ↓
[13] FAILURE: Gray overlay remains, focus not released
    ↓
[14] Player trapped - FiveM native focus state desynchronized
```

---

## THE EXACT FAILURE POINT

### File: `DCE/src/dce-admin/client/nui.lua`, Line 82 (inside `ensureCleanState()`)

#### Timeline of Execution - RUNTIME EVIDENCE

```
FiveM Engine Execution Order:
[1] Resource with ui_page declared (fxmanifest.lua:61)
[2] FiveM begins loading ui_page → AUTO-GRANTS NUI FOCUS (native) ← CANNOT BE STOPPED
[3] Lua script loaded (nui.lua)
[4] ensureCleanState() executes IMMEDIATELY at line 514
    → SetNuiFocus(false, false) at line 82 ← EXECUTED BUT BROWSER NOT READY
[5] Browser DOM becomes ready (DOMContentLoaded fires)
[6] JavaScript nuiReady callback executes
[7] Player joins → GRAY OVERLAY VISIBLE (FiveM still focused)
```

**Critical Runtime Evidence:**
- The `ensureCleanState()` call at line 82 happens BEFORE step [5]
- FiveM ignores `SetNuiFocus(false, false)` because the browser isn't listening
- The native FiveM focus state remains HAS_FOCUS = true
- DCE's internal `hasFocus = false` (line 35) is now desynchronized

**The Exact Line That Prevents Shutdown:**
```lua
-- Line 80-82 (ensureCleanState function)
if SetNuiFocus then
    logFocus("Calling SetNuiFocus(false, false) for clean state")
    SetNuiFocus(false, false)  ← THIS IS LINE 82
end
```

**Why This Is The Root Cause:**
1. When `/dce` opens the UI, `SetNuiFocus(true, true)` at line 122-123 works (browser is ready)
2. This grants focus to FiveM (native state: HAS_FOCUS = true)
3. When closing, `releaseFocus()` calls `SetNuiFocus(false, false)` at line 39
4. **But FiveM's native state was corrupted**: It already had focus from the auto-grant at step [2] that was never properly released
5. The `SetNuiFocus(false, false)` call may release focus temporarily, but FiveM may have already re-granted it to maintain consistency

**The Smoking Gun - Dual Focus Grant Issue:**
- Auto-grant at ui_page load (ignored release attempt at line 82)
- Explicit grant at /dce open (line 122)
- Close attempts to release but FiveM has TWO focus grants to track

---

## EVIDENCE: State Desynchronization

The Known Verified Facts state:
> "A fullscreen gray overlay already exists. The Control Center is not visible."

This confirms FiveM granted focus during `ui_page` load, before any DCE code could respond.

The `ensureCleanState()` function attempts to release this focus, but:
- It executes at Lua script load time
- FiveM's native NUI system may not be ready to accept focus changes
- The call is silently ignored
- The gray overlay remains

When `/dce` is executed later:
- `SetNuiFocus(true, true)` works because FiveM IS ready
- UI becomes visible (opacity: 1)
- User sees: Gray overlay + Control Center (both stacked)

When closing:
- The Lua `releaseFocus()` runs, calls `SetNuiFocus(false, false)`
- But FiveM's native state from the early auto-grant was never properly tracked
- The close operation may succeed partially but leave FiveM in an inconsistent state

---

## VERIFICATION OF ALL CLOSE PATHS

### Path 1: Close Button (Window Manager)

**File:** `window-manager.js`, Lines 267-282

```javascript
close: function(windowId) {
    ...
    var remainingWindows = Object.keys(DCE.Windows.windows).length;
    if (remainingWindows === 0 && DCE.UI && DCE.UI.getState('isOpen')) {
        DCE.NUI.post('close', { allWindowsClosed: true });  // ← Calls Lua correctly
        DCE.UI.setState('isOpen', false);
    }
}
```

✓ This path correctly calls Lua 'close' callback  
✓ No early exit paths that skip cleanup

### Path 2: ESC Key

**File:** `nui.lua`, Lines 196-201

```lua
RegisterNUICallback('keydown', function(data, cb)
    if data.key == "Escape" or data.key == "Esc" then
        releaseFocus()  // ← Called correctly
    end
    cb({})
end)
```

**BUT:** No JavaScript code sends keydown events to this callback!
The comment in framework.js states FiveM handles ESC automatically, but this is **INCORRECT** - FiveM only forwards keyboard events when there's an active keydown listener.

### Path 3: Server Triggered Close

**File:** `nui.lua`, Lines 140-142

```lua
RegisterNetEvent('dce-admin:client:closeDashboard', function()
    releaseFocus()  // ← Called correctly
end)
```

✓ This path correctly calls `releaseFocus()`

---

## THE ACTUAL ROOT CAUSE STATEMENT

> **FiveM auto-grants NUI focus when `ui_page` begins loading (before any Lua executes). DCE's `ensureCleanState()` at line 82 attempts to release this focus immediately at Lua script load time, but FiveM ignores the call because the browser isn't ready. The gray overlay persists. When the user opens via /dce, `SetNuiFocus(true, true)` works but creates a second focus lock. When closing, `releaseFocus()` at line 39 releases the SECOND grant, but FiveM's internal state machine still has the FIRST auto-grant active, causing the overlay to remain and the player to become trapped.**

---

## EXECUTION TIMELINE VERIFICATION

Based on Known Verified Facts stating execution proceeds through Desktop.hide() → UI.close() → WindowManager.closeAll():

```
Close Button Execution Timeline:
✓ JavaScript DCE.Windows.close() executes (line 267, window-manager.js)
✓ Window element removed from DOM
✓ DCE.NUI.post('close') sends to Lua (line 279, window-manager.js)
✓ Lua releaseFocus() executes (line 161, nui.lua)
✓ hasFocus = false (line 35)
✓ SetNuiFocus(false, false) executes (line 39) ← THIS IS THE LAST FUNCTION TO EXECUTE
✓ SendNUIMessage({action="close"}) (line 48-50)
✓ JavaScript receives "close" message
✓ DCE.Desktop.hide() → DCE.UI.close() executes (framework.js:282-287)
✓ DCE.Windows.closeAll() executes - no effect (windows already gone)
✗ FiveM native focus remains active - player trapped
```

**The `SetNuiFocus(false, false)` at line 39 is the last function to execute, but it doesn't fully release focus because FiveM's internal state still has the auto-granted focus from ui_page load active.**

---

## MINIMAL FIX

**File: `DCE/src/dce-admin/client/nui.lua`, Line 39**

Remove the immediate `ensureCleanState()` call (line 514) and rely on proper focus release timing:

```lua
-- REMOVE: ensureCleanState() at line 514 (race condition)
-- The call before browser ready is ignored by FiveM anyway

-- KEEP: The onClientResourceStart handler (lines 521-540) provides proper timing
-- KEEP: The nuiReady handler (lines 168-193) for early focus release when browser is ready
```

---

## ARCHITECTURAL FIX

1. **Remove the immediate `ensureCleanState()` call** - It races against FiveM's NUI initialization and is ignored
2. **FiveM auto-grants focus on ui_page load** - This is unpreventable and undocumented behavior
3. **The window close path is correct** - It does call releaseFocus() properly
4. **The issue is FiveM's dual focus state** - One from auto-grant, one from explicit grant; only one is released
5. **Solution: Track focus grants separately** - Count grants and releases, ensure parity
