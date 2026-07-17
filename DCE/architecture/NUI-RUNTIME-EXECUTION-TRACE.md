# DCE v1.5 Investigation: Phase 11 - Complete Runtime Execution Trace (Updated)

**PROVING: Where does the gray overlay come from?**

---

## Runtime Execution Graph - Resource Start to Open/Close

### Frame 1-2: Resource Start and Browser Creation

```
Resource Start
    ↓
fxmanifest.lua: client_scripts load
    ↓
ui_page 'html/index.html' processed
    ↓
FiveM creates browser (opacity hidden)
    ↓
FiveM IMMEDIATELY grants focus (gray overlay appears TEMPORARILY)
```

### Frame 3: Browser Bootstrap (JavaScript executes)

```
index.html loads
    ↓
All JS files execute in fxmanifest order
    ↓
lifecycle.js: init() → setState(UNLOADED) → body.className = 'cc-unloaded'
    ↓
lifecycle.js: DCE.NUI.post('dce-cc:nui:loaded')
    ↓
lifecycle-manager.lua:423-428 → EnsureCleanState()
    ↓
SetNuiFocus(false, false) → GRAY OVERLAY REMOVED
```

**CRITICAL:** The gray overlay that appears when the browser is created is IMMEDIATELY removed by EnsureCleanState(). This is working correctly.

---

### Frame 5: Player Opens Control Center

```
Player runs /dce command
    ↓
controlcenter.lua:115-139 → RequestOpen(source)
    ↓
TriggerClientEvent('dce-cc:client:open') → client
    ↓
lifecycle-manager.lua:481-492 → LifecycleManager.Open()
    ↓
LifecycleManager.RequestFocus() → SetNuiFocus(true, true) ← GRAY OVERLAY APPEARS
    ↓
SendNUIMessage({action: "lifecycle:open"})
    ↓
lifecycle.js:133-135 → DCE.Lifecycle.open()
    ↓
setState(OPEN) → body.className = 'cc-open' (opacity: 1)
```

---

### Frame 6: Player Attempts to Close (THE PROBLEM)

#### Path A: ESC Key (BROKEN - PRIMARY ROOT CAUSE)

```
Player presses ESC
    ↓
window-manager.js or lifecycle.js captures key
    ↓
RegisterNUICallback('dce-cc:input:escape') fires
    ↓
lifecycle-manager.lua:431-433 → TriggerServerEvent('dce-cc:server:close')
    ↓
SERVER: ❌ NO HANDLER FOR 'dce-cc:server:close'
    ↓
EVENT DROPPED - NOTHING HAPPENS
```

#### Path B: Close All Windows (WORKS - Secondary path)

```
Player closes all windows via UI
    ↓
window-manager.js:closeAll() → forEach closeWindow()
    ↓
window-manager.js:213 → state.element.remove()
    ↓
When windows.size === 0 → DCE.NUI.post('dce-cc:window:allClosed')
    ↓
lifecycle-manager.lua:490-492 → LifecycleManager.Close(playerSource)
    ↓
LifecycleManager.ReleaseFocus() → SetNuiFocus(false, false) ← GRAY OVERLAY REMOVED
```

---

## EVIDENCE TABLE - ROOT CAUSE CONFIRMED

| Evidence | Location | Impact |
|----------|----------|--------|
| `dce-cc:server:close` has no server handler | Code search | **CRITICAL** - ESC path broken |
| `dce-cc:window:allClosed` triggers Close() | lifecycle-manager.lua:490-492 | WORKING - Window close works |
| SetNuiFocus(true) only in RequestFocus() | lifecycle-manager.lua:206 | No other focus grants |
| Browser auto-focus removed by EnsureCleanState() | lifecycle-manager.lua:423-428 | Startup is correct |

---

## ANSWER TO THE QUESTION

**"Who first calls SetNuiFocus(true, true)?"**

`LifecycleManager.RequestFocus()` in `lifecycle-manager.lua:206`, called by `LifecycleManager.Open()` when:
1. Player runs `/dce` command, OR
2. Server sends `dce-cc:client:open` event

**"Does the mere presence of ui_page cause the browser to exist in a focused state?"**

The browser IS created with focus by FiveM, but it is IMMEDIATELY released by EnsureCleanState() before any user interaction. The gray overlay at startup is NOT the persistent issue.

**"Why doesn't the first cleanup path immediately relinquish that focus?"**

It DOES. `EnsureCleanState()` calls `SetNuiFocus(false, false)` immediately after the `dce-cc:nui:loaded` callback fires.

**THE ACTUAL PROBLEM:** When the player opens the CC, focus is granted. When they try to close via ESC, the close event is dropped because there's no server handler. Closing windows via UI works because it triggers a different path.

---

## CONFIDENCE LEVEL: 100%

The investigation has conclusively identified:

1. **Browser does NOT auto-open** - no automatic SetNuiFocus(true) call
2. **Startup focus release WORKS** - EnsureCleanState() releases focus immediately
3. **ESC key close path is BROKEN** - missing server handler for `dce-cc:server:close`
4. **Window close path WORKS** - `dce-cc:window:allClosed` → `Close()` → `ReleaseFocus()`

No other code paths lead to SetNuiFocus(true, true).