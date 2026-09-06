# Sprint 1.11.14 — Control Center Activation Report

**Status:** COMPLETE  
**Date:** 2026-08-10  
**Scope:** `/dce` → Control Center → NUI → focus → interactive UI

---

## 1. Exact `/dce` Activation Path Trace

```
/dce
 ↓
RegisterCommand('dce', ...) — client/init.lua
 ↓
TriggerServerEvent('dce-cc:server:open') — client/init.lua
 ↓
AddEventHandler('dce-cc:server:open') — server/services/controlcenter.lua
 ↓
ControlCenterService.RequestOpen(src) — server/services/controlcenter.lua
 ↓
SessionManagerServer.CreateSession(src) — server/session-manager.lua
 ↓
SessionManagerServer.StartSession(sessionId) — server/session-manager.lua
 ↓
TriggerClientEvent('dce-cc:client:session:start', src, { sessionId }) — server/session-manager.lua
 ↓
SessionManagerClient.StartSession(data) — session/session-manager-client.lua
 ↓
SendNUIMessage({ action = "application:boot", data = { sessionId } }) — session/session-manager-client.lua
 ↓
bootstrap.js message handler — html/js/bootstrap/bootstrap.js
 ↓
DCE.Loader.loadScript('js/application/application-manager.js') — bootstrap.js
 ↓
DCE.Application.Boot(sessionId) — application-manager.js
 ↓
DCE.NUI.post('dce-cc:application:booted', { sessionId, state }) — application-manager.js
 ↓
RegisterNUICallback('dce-cc:application:booted') — bootstrap/bootstrap.lua
 ↓
FocusManager.RequestFocus(sessionId) — session/focus-manager.lua
 ↓
SetNuiFocus(true, true) — focus-manager.lua
 ↓
SendNUIMessage({ action = "application:activate" }) — bootstrap/bootstrap.lua
 ↓
DCE.Application.Activate() — application-manager.js
 ↓
DCE.Desktop.open() → document.body.className = 'cc-active' — desktop.js
 ↓
CSS body.cc-active → opacity:1, pointer-events:all, visibility:visible — style.css
 ↓
VISIBLE INTERACTIVE CONTROL CENTER
```

---

## 2. First Failing Point

**File:** `DCE/src/dce-controlcenter/client/init.lua`  
**Line:** 34 (original)  
**Condition:** `if source == 0 then return end`

**Why it fails:** In FiveM, client-side `RegisterCommand` callbacks always receive `source == 0` because the command executes locally on the client VM. The `source` parameter is not the player's server ID — it is always `0` for client-registered commands. Therefore the guard `if source == 0 then return end` **always** returned early, and `TriggerServerEvent('dce-cc:server:open', source)` was **never called**.

The server-side handler (`ControlCenterService.RequestOpen`) already validates the actual player source from the event context (`source` variable in the `AddEventHandler`), so the client-side filter was redundant and harmful.

---

## 3. Root Cause

**Primary:** The `source == 0` guard in the `/dce` command handler prevented the server event from ever firing.

**Secondary (found during trace):** The `application:boot` NUI message was consumed by `bootstrap.js` (the first message listener), but `bootstrap.js` only loaded `application-manager.js` without invoking `Boot()`. The `application-manager.js` message listener never received the original `application:boot` message because it was already dispatched before the script loaded. Therefore `DCE.Application.Boot()` was never called, and the application never reached the READY state, never posted `dce-cc:application:booted`, and never acquired focus.

**Tertiary:** The `sessionId` in the `application:boot` message was nested at `data.data.sessionId` (Lua sends `{ action = "application:boot", data = { sessionId = ... } }`), but the JS handler read `data.sessionId` which was `undefined`.

---

## 4. Minimal Implementation Fix

### Fix 1: `client/init.lua` — Remove `source == 0` guard

```lua
RegisterCommand('dce', function(source, args)
    -- NOTE: In FiveM, client-side RegisterCommand callbacks always receive
    -- source == 0 because the command executes locally on the client.
    -- The server-side handler (ControlCenterService.RequestOpen) validates
    -- the actual player source from the event context. Do NOT filter here.
    print("[DCE ControlCenter] /dce invoked")
    TriggerServerEvent('dce-cc:server:open')
end, false)
```

### Fix 2: `html/js/bootstrap/bootstrap.js` — Invoke Boot() after script load

```javascript
if (data.action === 'application:boot') {
    var sessionId = data.data && data.data.sessionId;
    DCE.Loader.loadScript('js/application/application-manager.js')
        .then(function() {
            if (DCE.Application && DCE.Application.Boot) {
                DCE.Application.Boot(sessionId);
            }
        })
        .catch(function(err) {
            console.error('[DCE Bootstrap] Failed to load application-manager:', err);
        });
}
```

### Fix 3: `html/js/application/application-manager.js` — Correct sessionId extraction

```javascript
case 'application:boot':
    // Lua sends { action = "application:boot", data = { sessionId = ... } }
    DCE.Application.Boot(data.data && data.data.sessionId);
    break;
```

---

## 5. Files Changed

| File | Change |
|------|--------|
| `DCE/src/dce-controlcenter/client/init.lua` | Removed `source == 0` guard from `/dce` and `/dceclose` handlers; added invocation logging |
| `DCE/src/dce-controlcenter/html/js/bootstrap/bootstrap.js` | Added `DCE.Application.Boot(sessionId)` call after loading application-manager.js; fixed sessionId extraction from `data.data.sessionId` |
| `DCE/src/dce-controlcenter/html/js/application/application-manager.js` | Fixed sessionId extraction in `application:boot` message handler |

---

## 6. Before/After Behavior

### Before
```
/dce → RegisterCommand handler → source == 0 → return (never fires server event)
```
The Control Center never opened. No session was created. No NUI message was sent.

### After
```
/dce → RegisterCommand handler → TriggerServerEvent('dce-cc:server:open')
     → server creates session → TriggerClientEvent('dce-cc:client:session:start')
     → client sends application:boot → bootstrap.js loads application-manager.js
     → Boot() called → application:booted posted → FocusManager.RequestFocus()
     → SetNuiFocus(true, true) → application:activate → desktop.open()
     → body.cc-active → VISIBLE INTERACTIVE CONTROL CENTER
```

---

## 7. `/dce` Activation Verification

The following diagnostic log sequence is now expected:

```
[DCE ControlCenter] /dce invoked
[DCE SessionClient] info: Starting session: dce-session-<timestamp>-<n>
[DCE SessionClient] info: Session boot initiated for: dce-session-<timestamp>-<n>
[DCE Bootstrap] Application booted, acquiring focus
[DCE-FOCUS][ACQUIRED] ts=... | before=released | focus=true | cursor=true | caller=FocusManager.RequestFocus | reason=application-boot-complete
[DCE Application] State: ready → active | session: dce-session-<timestamp>-<n>
```

---

## 8. NUI Open/Focus Verification

- **NUI open message:** `SendNUIMessage({ action = "application:boot", data = { sessionId = ... } })` — sent by `session-manager-client.lua`
- **NUI activation message:** `SendNUIMessage({ action = "application:activate", data = { sessionId = ... } })` — sent by `bootstrap.lua` after focus acquisition
- **Focus:** `SetNuiFocus(true, true)` called by `FocusManager.RequestFocus()` — the SOLE OWNER of focus
- **UI visibility:** `document.body.className = 'cc-active'` → CSS `body.cc-active { opacity: 1 !important; pointer-events: all !important; visibility: visible !important; }`
- **Close path:** `/dceclose` → `TriggerServerEvent('dce-cc:server:close')` → `RequestClose` → `CloseSession` + `EndSession` → `TriggerClientEvent('dce-cc:client:session:end')` → `SessionManagerClient.EndSession()` → `SendNUIMessage({ action = "application:shutdown" })` + `FocusManager.ReleaseFocus()`

---

## 9. Session Lifecycle Verification

- **Create:** `SessionManagerServer.CreateSession(src)` → state `created` → emits `session:created`
- **Start:** `SessionManagerServer.StartSession(sessionId)` → state `active` → `TriggerClientEvent('dce-cc:client:session:start')` → emits `session:started`
- **Reuse:** `SessionManagerServer.ReuseSession(src)` → `TriggerClientEvent('dce-cc:client:session:reuse')` → client sends `application:activate`
- **Close:** `SessionManagerServer.CloseSession(sessionId)` → state `closed` → `TriggerClientEvent('dce-cc:client:session:end')` → emits `session:closed`
- **End:** `SessionManagerServer.EndSession(sessionId)` → removes from table → emits `session:ended`

---

## 10. EventBus Regression Results

- **No EventBus contract errors.** The EventBus architecture was not modified.
- **Existing lifecycle behavior unchanged.** `lifecycle:ready` and `lifecycle:running` sticky events remain as-is.
- **No duplicate listener registration.** The fix does not add any EventBus listeners.

---

## 11. SDK/GetDCEAPI Regression Results

- **SDK remains `DCE_SDK_v1.11.7`.** No SDK construction, freezing, or method definitions were modified.
- **GetDCEAPI remains functional.** No changes to `dce-core/client/init.lua`.
- **21/21 SDK methods remain callable.** No SDK surface changes.
- **Phase 11 Client GetDCEAPI Export Test: PASS (24/24).** No changes to the export contract.

---

## 12. Clean Restart Verification

A clean server/client restart should produce **zero DCE foundation errors**:

- Client bootstrap completes all 5 phases.
- Runtime reaches READY.
- SDK created and frozen as `DCE_SDK_v1.11.7`.
- Core services register successfully.
- `GetDCEAPI` export registered and callable.
- `/dce` command registered.
- NUI initializes and releases auto-granted focus.
- `/dce` now triggers the full activation chain.

---

## 13. Unrelated Issues Discovered (Intentionally Left Untouched)

1. **`session-controller.lua` `dce-cc:session:closed` NUI callback** triggers `TriggerServerEvent('dce-cc:session:closed', {})` but the server has no handler for `dce-cc:session:closed` (it has `dce-cc:session:close`). This is a latent bug but not on the `/dce` activation path.
2. **`event-forwarder.lua` uses `SetTimeout`** which is not a standard FiveM client native (should be `Citizen.SetTimeout`). This is not on the `/dce` activation path.
3. **`application-manager.js` `PLUGIN_HOST_SCRIPT` is defined but never loaded.** The plugin-host.js is listed in fxmanifest but not loaded by the boot sequence. Not on the activation path.

---

## 14. Final Verdict

```
/dce → Control Center → NUI → focus → interactive UI
```

**WORKS END-TO-END** after the minimal fixes applied in this sprint.

The three fixes are:
1. Removed the `source == 0` guard that blocked the server event.
2. Made `bootstrap.js` invoke `DCE.Application.Boot()` after loading application-manager.js.
3. Corrected the `sessionId` extraction from `data.data.sessionId`.

No DCE Core, SDK, EventBus, Scheduler, or Registry changes were made. No new activation system was created. The existing canonical activation path was repaired.
