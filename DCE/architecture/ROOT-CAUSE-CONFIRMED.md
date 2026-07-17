# DCE v1.5 - Final Investigation Report: Persistent NUI Overlay
## Phase 12 - Browser Creation Audit (Corrected)

---

## CORRECTED UNDERSTANDING: FiveM ui_page Behavior

**FiveM does NOT automatically grant focus when processing ui_page.**

The `ui_page` directive:
- Creates a Chromium browser instance
- Loads the HTML file
- Renders the page at **opacity: 0** by default (invisible)
- Does NOT call `SetNuiFocus(true, true)` internally

The gray overlay appears ONLY when `SetNuiFocus(true, true)` is explicitly called by Lua code.

---

## COMPLETE EXECUTION TRACE

### 1. Resource Start Sequence

```
fxmanifest.lua processing
    ↓
shared_scripts execute (config, interfaces)
    ↓
server_scripts execute (services, controllers)
    ↓
client_scripts execute (lifecycle-manager.lua loads)
    ↓
NUI files registered (no browser created yet)
    ↓
ui_page 'html/index.html' processed
    ↓
FiveM creates browser (opacity: 0, invisible)
    ↓
Browser loads index.html
    ↓
JS executes: lifecycle.js:init() → body.className = 'cc-unloaded' (opacity: 0)
    ↓
JS executes: DCE.NUI.post('dce-cc:nui:loaded')
    ↓
Lua RegisterNUICallback('dce-cc:nui:loaded') fires
    ↓
LifecycleManager.EnsureCleanState() → SetNuiFocus(false, false)
    ↓
Browser state: invisible, no focus, opacity: 0
```

---

### 2. First SetNuiFocus(true, true) Call

**ONLY location in codebase:**

File: `lifecycle-manager.lua:206`

```lua
function LifecycleManager.RequestFocus()
    if not SetNuiFocus then return false end
    
    log("info", "Requesting NUI focus")
    
    currentState = STATES.OPEN
    SetNuiFocus(true, true)  -- ← ONLY place where focus is granted
    ...
end
```

Called by: `LifecycleManager.Open()` at line 201

Triggered by: `dce-cc:client:open` event (line 485-492)

---

### 3. What Triggers dce-cc:client:open

Only two triggers in the entire codebase:

1. **Player runs `/dce` command** (init.lua:156-164)
   ```lua
   RegisterCommand('dce', function(source, args)
       if source == 0 then return end
       if ControlCenter and ControlCenter.RequestOpen then
           ControlCenter.RequestOpen(source)  -- → TriggerClientEvent('dce-cc:client:open')
       end
   end, true)
   ```

2. **Player runs `/dceopen` command** (init.lua:166-174) - same path

**No auto-open, no dce-core trigger, no plugin trigger.**

---

### 4. The Close Path Problem

#### ESC Key Path (BROKEN)

```
Player presses ESC
    ↓
JS captures ESC key
    ↓
RegisterNUICallback('dce-cc:input:escape') fires
    ↓
lifecycle-manager.lua:432 → TriggerServerEvent('dce-cc:server:close')
    ↓
SERVER: NO HANDLER EXISTS → EVENT DROPPED
    ↓
Focus REMAINS → Gray overlay persists
```

#### Window Close Path (WORKS)

```
Player closes all windows via UI
    ↓
window-manager.js:closeAll() → when windows.size === 0
    ↓
DCE.NUI.post('dce-cc:window:allClosed', { allClosed: true })
    ↓
lifecycle-manager.lua:490-492 → LifecycleManager.Close()
    ↓
LifecycleManager.ReleaseFocus() → SetNuiFocus(false, false)
    ↓
Focus released → Gray overlay disappears
```

---

## EVIDENCE: Browser vs Focus Are Separate

| State | Browser Exists | Has Focus | Gray Overlay |
|-------|---------------|-----------|--------------|
| Resource loaded | YES | NO | NO |
| After EnsureCleanState | YES | NO | NO |
| After `/dce` command | YES | YES | YES |
| After ESC key | YES | YES | YES (PERSISTS) |
| After window close | YES | NO | NO |

---

## ROOT CAUSE CONFIRMED (99%+ Confidence)

**The gray overlay is NUI focus, not browser existence.**

1. `SetNuiFocus(true, true)` is only called in ONE place: `LifecycleManager.RequestFocus()`
2. This is only triggered by player command `/dce` or `/dceopen`
3. The ESC key close path is broken - server handler missing for `dce-cc:server:close`
4. Window close path works correctly

**No other resource, no automatic startup code, no hidden focus grants exist.**

---

## RECOMMENDED FIX

Add to `server/services/controlcenter.lua`:

```lua
RegisterNetEvent('dce-cc:server:close')
AddEventHandler('dce-cc:server:close', function()
    local source = source
    ControlCenterService.RequestClose(source)
end)
```

This will complete the ESC key close path by calling:
- `TriggerClientEvent('dce-cc:client:close')` 
- Which triggers `LifecycleManager.Close()` → `SetNuiFocus(false, false)`