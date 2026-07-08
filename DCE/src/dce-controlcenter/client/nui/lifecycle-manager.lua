-- DCE Control Center v2 - NUI Lifecycle Manager
-- CRITICAL: This is the ONLY module that calls SetNuiFocus
-- No other code in DCE should call SetNuiFocus directly

local DCE = _G.DCE
local Diagnostics = _G.DCEDiagnostics

-- Lifecycle state machine states
local STATE_CLOSED = "closed"
local STATE_OPENING = "opening"
local STATE_OPEN = "open"
local STATE_CLOSING = "closing"

-- State tracking (per-player is not needed for single-player focus, but useful for multiplayer)
local lifecycleState = STATE_CLOSED
local pendingOpenRequests = 0
local pendingCloseRequests = 0

-- Internal focus tracking
local function logLifecycle(message)
    print(("[DCE][Lifecycle] %s (state=%s)"):format(message, lifecycleState))
    if Diagnostics and Diagnostics.OnNUIStateChange then
        Diagnostics.OnNUIStateChange(lifecycleState, message)
    end
end

--- Ensure clean state on resource load
local function ensureCleanState()
    logLifecycle("ensureCleanState: forcing clean state on load")
    
    -- Reset state to closed
    lifecycleState = STATE_CLOSED
    pendingOpenRequests = 0
    pendingCloseRequests = 0
    
    -- CRITICAL: Always call SetNuiFocus(false, false) first
    -- This removes any gray overlay that FiveM may have auto-granted
    if SetNuiFocus then
        SetNuiFocus(false, false)
    end
    
    -- Also disable any input passthrough
    if SetNuiFocusKeepInput then
        SetNuiFocusKeepInput(false)
    end
    
    -- Notify NUI to ensure it's hidden
    if SendNUIMessage then
        SendNUIMessage({
            action = "lifecycle:reset"
        })
    end
    
    logLifecycle("ensureCleanState: clean state established")
end

--- Request to open the Control Center
---@param callback function|nil Optional callback when open is confirmed
local function requestOpen(callback)
    if lifecycleState == STATE_OPEN then
        -- Already open, just notify
        if callback then callback(true) end
        return
    end
    
    if lifecycleState == STATE_OPENING then
        -- Already opening, increment pending and wait
        pendingOpenRequests = pendingOpenRequests + 1
        return
    end
    
    logLifecycle("requestOpen: requesting focus")
    lifecycleState = STATE_OPENING
    pendingOpenRequests = pendingOpenRequests + 1
    
    -- CRITICAL: Grant focus and cursor
    if SetNuiFocus then
        SetNuiFocus(true, true)
    end
    
    -- Notify NUI to show UI
    if SendNUIMessage then
        SendNUIMessage({
            action = "lifecycle:open"
        })
    end
    
    if callback then callback(true) end
end

--- Request to close the Control Center
---@param callback function|nil Optional callback when close is confirmed
local function requestClose(callback)
    if lifecycleState == STATE_CLOSED then
        -- Already closed
        if callback then callback(true) end
        return
    end
    
    if lifecycleState == STATE_CLOSING then
        -- Already closing, increment pending
        pendingCloseRequests = pendingCloseRequests + 1
        return
    end
    
    logLifecycle("requestClose: releasing focus")
    lifecycleState = STATE_CLOSING
    pendingCloseRequests = pendingCloseRequests + 1
    
    -- CRITICAL: Release focus first - this removes the gray overlay
    if SetNuiFocus then
        SetNuiFocus(false, false)
    end
    
    -- Clean up input passthrough
    if SetNuiFocusKeepInput then
        SetNuiFocusKeepInput(false)
    end
    
    -- Notify NUI to hide
    if SendNUIMessage then
        SendNUIMessage({
            action = "lifecycle:close"
        })
    end
    
    if callback then callback(true) end
end

--- Handle NUI ready notification
--- Called when NUI finishes loading and is ready to receive messages
RegisterNUICallback('dce-cc:nui:ready', function(data, cb)
    logLifecycle("NUI ready received")
    
    -- If we're in opening state, transition to open
    if lifecycleState == STATE_OPENING then
        lifecycleState = STATE_OPEN
        pendingOpenRequests = 0
    end
    
    -- ACK the ready with our state
    cb({ state = lifecycleState })
end)

--- Handle window close notification from NUI
--- When all windows are closed, release focus
RegisterNUICallback('dce-cc:window:allClosed', function(data, cb)
    logLifecycle("All windows closed, releasing focus")
    
    if lifecycleState == STATE_OPEN then
        requestClose()
    end
    
    cb({})
end)

--- Handle ESC key from NUI
RegisterNUICallback('dce-cc:input:escape', function(data, cb)
    logLifecycle("ESC pressed in NUI")
    requestClose()
    cb({})
end)

--- Handle explicit close request from NUI
RegisterNUICallback('dce-cc:nui:requestClose', function(data, cb)
    logLifecycle("Close requested from NUI")
    requestClose()
    cb({})
end)

--- Handle open request from NUI (keybind)
RegisterNUICallback('dce-cc:nui:requestOpen', function(data, cb)
    logLifecycle("Open requested from NUI (keybind)")
    requestOpen()
    cb({})
end)

--- Open from server event
RegisterNetEvent('dce-cc:client:open')
AddEventHandler('dce-cc:client:open', function()
    requestOpen()
end)

--- Close from server event
RegisterNetEvent('dce-cc:client:close')
AddEventHandler('dce-cc:client:close', function()
    requestClose()
end)

--- Handle focus confirmation from NUI
--- NUI calls this when it has visually hidden itself
RegisterNUICallback('dce-cc:nui:focusReleased', function(data, cb)
    logLifecycle("Focus released confirmed by NUI")
    
    if lifecycleState == STATE_CLOSING then
        lifecycleState = STATE_CLOSED
        pendingCloseRequests = 0
    end
    
    cb({})
end)

--- Get current lifecycle state
function GetLifecycleState()
    return lifecycleState
end

--- Check if NUI has focus
function IsFocused()
    return lifecycleState == STATE_OPEN
end

-- Critical: Ensure clean state immediately on script load
ensureCleanState()

-- Also handle resource start (defensive)
AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        logLifecycle("onClientResourceStart: defensive clean state")
        ensureCleanState()
    end
end)

-- Handle resource stop - ensure focus is released
AddEventHandler("onClientResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        logLifecycle("onClientResourceStop: cleaning up focus")
        lifecycleState = STATE_CLOSED
        if SetNuiFocus then
            SetNuiFocus(false, false)
        end
        if SetNuiFocusKeepInput then
            SetNuiFocusKeepInput(false)
        end
        if SendNUIMessage then
            SendNUIMessage({
                action = "lifecycle:cleanup"
            })
        end
    end
end)

-- Player spawn defense - ensure focus is released when player spawns
AddEventHandler("playerSpawned", function()
    if lifecycleState ~= STATE_CLOSED then
        logLifecycle("playerSpawned: releasing orphaned focus")
        lifecycleState = STATE_CLOSED
        if SetNuiFocus then
            SetNuiFocus(false, false)
        end
        if SetNuiFocusKeepInput then
            SetNuiFocusKeepInput(false)
        end
    end
end)

-- Export functions for other client modules to use
_G.DCELifecycleManager = {
    requestOpen = requestOpen,
    requestClose = requestClose,
    getState = GetLifecycleState,
    isFocused = IsFocused,
}