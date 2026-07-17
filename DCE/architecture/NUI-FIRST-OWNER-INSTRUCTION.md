# DCE v1.5 - Phase 11: Precise Instruction-by-Instruction Trace
## From fxmanifest.lua to First SetNuiFocus(true, true)

---

## Step 1: fxmanifest.lua Execution Order (FiveM Internal)

FiveM processes fxmanifest in this exact order:

1. **Line 5-10** - fx_version, game, author, description, version (metadata)
2. **Line 12-14** - dependencies { 'dce-core' } (waits for dce-core to start)
3. **Line 16-20** - shared_scripts (shared/config.lua, shared/interfaces/*.lua) - **EXECUTES FIRST**
4. **Line 22-34** - server_scripts (ALL server files load and execute)
5. **Line 36-41** - client_scripts (ALL client files load and execute)
6. **Line 43-74** - file { ... } (NUI files are marked as resource files)
7. **Line 76** - **ui_page 'html/index.html'** - FiveM creates browser and grants focus

**CRITICAL:** The ui_page directive at line 76 is processed AFTER client_scripts are loaded but BEFORE any DOM is ready.

---

## Step 2: Client Scripts Load (Lua)

### 2.1 lifecycle-manager.lua (First client script, line 37)

**Lines 1-50:** Variable declarations and state constants
```lua
local STATES = {
    UNLOADED = 'unloaded',
    LOADING = 'loading',
    READY = 'ready',
    OPEN = 'open',
    CLOSING = 'closing',
    SHUTDOWN = 'shutdown'
}
local currentState = STATES.UNLOADED
local cleanStateInitialized = false
```

**Lines 171-178:** RegisterNUICallback('dce-cc:nui:loaded')
```lua
RegisterNUICallback('dce-cc:nui:loaded', function(data, cb)
    LifecycleManager.EnsureCleanState()  -- THIS WILL RELEASE FOCUS
    LifecycleManager.Transition(STATES.LOADING)
    ...
end)
```

**Lines 429-433:** RegisterNUICallback('dce-cc:input:escape')
```lua
RegisterNUICallback('dce-cc:input:escape', function(data, cb)
    TriggerServerEvent('dce-cc:server:close')
    cb({})
end)
```

**Lines 485-492:** RegisterNetEvent('dce-cc:client:open') handler
```lua
RegisterNetEvent('dce-cc:client:open')
AddEventHandler('dce-cc:client:open', function()
    LifecycleManager.Open()
end)
```

**Lines 488-492:** RegisterNetEvent('dce-cc:client:close') handler
```lua
RegisterNetEvent('dce-cc:client:close')
AddEventHandler('dce-cc:client:close', function()
    local playerSource = Source or 0
    LifecycleManager.Close(playerSource)
end)
```

**Lines 490-492:** RegisterNUICallback('dce-cc:window:allClosed') handler
```lua
RegisterNUICallback('dce-cc:window:allClosed', function(data, cb)
    LifecycleManager.Close(playerSource)
    cb({})
end)
```

**Lines 407-427:** onClientResourceStart (registers callbacks)
```lua
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    RegisterNUICallback('dce-cc:nui:loaded', ...)  -- Already registered above
    ...
end)
```

**NO SetNuiFocus calls during script load.** Only callback registrations.

---

## Step 3: ui_page Processing (FiveM Internal)

When FiveM processes `ui_page 'html/index.html'` (line 76):

1. FiveM creates a browser instance for the NUI
2. FiveM **IMMEDIATELY grants focus** to the browser (FiveM behavior)
3. FiveM loads `html/index.html` into the browser
4. FiveM processes all `<script>` tags in order

**This focus grant is NOT preventable by Lua code.** It happens in FiveM internals before any Lua callback fires.

---

## Step 4: Browser Bootstrap (JavaScript Execution)

### Frame 4.1: index.html loads

```html
<body class="cc-unloaded">
    <div class="desktop" id="desktop">
        ...
    </div>
</body>
```

CSS applies:
```css
body { opacity: 0 !important; pointer-events: none !important; }
body.cc-unloaded { opacity: 0 !important; pointer-events: none !important; }
```

**Result:** Browser has focus but body opacity is 0 → gray overlay visible but no visual content.

---

### Frame 4.2: JS Files Execute in fxmanifest Order

#### js/app.js (line 49) → DCE.NUI.post helper defined

```javascript
DCE.NUI = {
    post: function(event, data) {
        return fetch(`https://${GetParentResourceName()}/${event}`, { ... });
    }
};
```

#### js/core/lifecycle.js (line 50) → DCE.Lifecycle object created

```javascript
(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Lifecycle = { ... };

    function init() {
        console.log('[DCE Lifecycle] Initializing...');
        DCE.Lifecycle.setState(STATES.UNLOADED);  // Sets body.cc-unloaded (opacity: 0)
        DCE.NUI.post('dce-cc:nui:loaded', { status: 'loaded' });  // SENDS TO LUA
    }

    // DOM ready check
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();  // Called immediately if DOM already ready
    }
})();
```

**Key Point:** init() runs immediately (DOM is ready) → DCE.NUI.post('dce-cc:nui:loaded') is called.

---

## Step 5: First SetNuiFocus Call (Lua Response)

### Frame 5.1: Lua receives dce-cc:nui:loaded callback

```lua
RegisterNUICallback('dce-cc:nui:loaded', function(data, cb)
    LifecycleManager.EnsureCleanState()  -- Line 424
    ...
end)
```

### Frame 5.2: EnsureCleanState() executes

```lua
function LifecycleManager.EnsureCleanState()  -- Lines 180-192
    if cleanStateInitialized then return true end
    cleanStateInitialized = true

    log("info", "Browser ready, releasing auto-granted focus")

    if SetNuiFocus then  -- Line 186
        SetNuiFocus(false, false)  -- Line 187 - FIRST SetNuiFocus CALL
    end

    if SetNuiFocusKeepInput then
        SetNuiFocusKeepInput(false)
    end

    SendNUIMessage({ action = "lifecycle:reset" })
    return true
end
```

**THIS IS THE FIRST SetNuiFocus CALL AFTER BROWSER CREATION.**

It takes ownership of the NUI browser and immediately releases the focus that FiveM auto-granted.

---

## Step 6: RequestFocus() - First Re-grant of Focus

The next time SetNuiFocus(true, true) is called:

```
Player runs /dce command
    ↓
init.lua:25-30 → ControlCenter.RequestOpen(source)
    ↓
controlcenter.lua:115-139 → ControlCenterService.RequestOpen(source)
    ↓
TriggerClientEvent('dce-cc:client:open', source)  -- Line 131
    ↓
lifecycle-manager.lua:485-492 → AddEventHandler('dce-cc:client:open')
    ↓
LifecycleManager.Open()  -- Line 487
    ↓
LifecycleManager.RequestFocus()  -- Line 201
    ↓
SetNuiFocus(true, true)  -- Line 206 - FIRST RE-GRANT OF FOCUS
```

**This is the ONLY place SetNuiFocus(true, true) is called in the codebase.**

---

## Step 7: Close Path Analysis

### Working Close Path (Window close)

```
Player closes all windows
    ↓
window-manager.js:closeAll()
    ↓
DCE.NUI.post('dce-cc:window:allClosed')
    ↓
lifecycle-manager.lua:490-492 → LifecycleManager.Close()
    ↓
LifecycleManager.ReleaseFocus() → SetNuiFocus(false, false) ✓
```

### Broken Close Path (ESC key)

```
Player presses ESC
    ↓
JS captures key OR FiveM ESC callback
    ↓
RegisterNUICallback('dce-cc:input:escape') fires
    ↓
TriggerServerEvent('dce-cc:server:close') sent
    ↓
SERVER: NO HANDLER EXISTS - EVENT DROPPED
    ↓
Focus never released - gray overlay persists
```

---

## SUMMARY OF FIRST NUI OWNING INSTRUCTION

| # | Entity | Action | Result |
|---|--------|--------|--------|
| 1 | FiveM | ui_page processing | Creates browser, grants focus (TEMPORARY) |
| 2 | JS init() | DCE.NUI.post('dce-cc:nui:loaded') | Sends callback to Lua |
| 3 | Lua EnsureCleanState() | SetNuiFocus(false, false) | **TAKES OWNERSHIP, releases focus** |
| 4 | Lua RequestFocus() | SetNuiFocus(true, true) | Re-grants focus when CC opens |
| 5 | Lua ReleaseFocus() | SetNuiFocus(false, false) | Releases focus when CC closes |

The lifecycle manager is the SOLE owner of NUI focus after EnsureCleanState() runs.