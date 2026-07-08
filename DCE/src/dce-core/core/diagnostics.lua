-- DCE Diagnostics Module
-- Comprehensive NUI Lifecycle Diagnostic Mode
-- Instrumented when Config.Debug.NUILifecycle = true

local Diagnostics = {}
local logger

-- Diagnostic counters
local stats = {
    resourcesLoaded = 0,
    threadsStarted = 0,
    threadsFinished = 0,
    eventsPublished = 0,
    eventsReceived = 0,
    nuiMessages = 0,
    focusChanges = 0,
    authRequests = 0,
    illegalStateChanges = 0,
    warnings = 0,
    errors = 0,
}

-- Thread tracking
local trackedThreads = {}
local threadCounter = 0

-- Callback tracking
local trackedCallbacks = {}
local callbackTimeouts = {}

-- NUI Focus ownership
local nuiFocusOwner = {
    focus = "unknown",
    keyboard = "unknown",
    cursor = "unknown",
    mouse = "unknown",
}

-- Lifecycle state machine
local lifecycleState = {
    value = "BOOT",
    history = {},
    lastTransition = nil,
}

-- Valid state transitions
local validTransitions = {
    BOOT = { "RESOURCE_START", "CLIENT_READY" },
    RESOURCE_START = { "CLIENT_READY", "NUI_READY" },
    CLIENT_READY = { "NUI_READY", "WAITING" },
    NUI_READY = { "WAITING", "OPENING" },
    WAITING = { "AUTHORIZED", "OPENING", "CLOSED" },
    AUTHORIZED = { "OPENING", "CLOSED" },
    OPENING = { "OPEN", "CLOSING" },
    OPEN = { "CLOSING" },
    CLOSING = { "CLOSED" },
    CLOSED = { "OPENING", "WAITING" },
}

-- Timing tracker
local timers = {}

-- Hang detection flag
local startupComplete = false

-- Check if diagnostics are enabled
local function isEnabled()
    local Config = _G.Config or {}
    return Config.Debug and Config.Debug.NUILifecycle == true
end

-- Get stack trace for caller info (FiveM-compatible)
local function getStackTrace(levels)
    levels = levels or 2
    local trace = ""
    local success, result = pcall(function()
        if debug and debug.traceback then
            return debug.traceback("", levels)
        end
        return nil
    end)
    if success and result then
        -- Extract the first line that contains useful info
        for line in result:gmatch("[^\n]+") do
            if line:find("@") then
                trace = line
                break
            end
        end
    end
    return trace
end

--- Initialize the diagnostics module
function Diagnostics.Init(log)
    logger = log
end

--- Log diagnostic message
local function diagPrint(prefix, message, ...)
    if not isEnabled() then return end
    if ... then
        message = string.format(message, ...)
    end
    print(("[%s] %s"):format(prefix, message))
end

--- Generate unique ID
local function generateId()
    threadCounter = threadCounter + 1
    return threadCounter
end

-- ============================================================================
-- Step 1: Resource Startup Trace
-- ============================================================================

function Diagnostics.OnResourceStart(resourceName)
    if not isEnabled() then return end
    stats.resourcesLoaded = stats.resourcesLoaded + 1
    diagPrint("DCE][BOOT", "==========================================")
    diagPrint("DCE][BOOT", "[DCE][BOOT]")
    diagPrint("DCE][BOOT", "Resource: " .. resourceName)
    diagPrint("DCE][BOOT", "Starting...")
    diagPrint("DCE][BOOT", "Time: " .. (GetGameTimer and GetGameTimer() or os.time()))
    diagPrint("DCE][BOOT", "==========================================")
end

function Diagnostics.OnResourceInitialized(resourceName)
    if not isEnabled() then return end
    diagPrint("DCE][BOOT", "[DCE][BOOT] Resource initialized successfully: " .. resourceName)
end

function Diagnostics.OnResourceError(resourceName, funcName, reason, stack)
    if not isEnabled() then return end
    stats.errors = stats.errors + 1
    diagPrint("DCE][BOOT][ERROR", "==========================================")
    diagPrint("DCE][BOOT][ERROR", "[DCE][BOOT][ERROR]")
    diagPrint("DCE][BOOT][ERROR", "Resource: " .. resourceName)
    diagPrint("DCE][BOOT][ERROR", "Initialization failed")
    diagPrint("DCE][BOOT][ERROR", "Function: " .. tostring(funcName))
    diagPrint("DCE][BOOT][ERROR", "Reason: " .. tostring(reason))
    if stack then
        diagPrint("DCE][BOOT][ERROR", "Stack: " .. tostring(stack))
    end
    diagPrint("DCE][BOOT][ERROR", "==========================================")
end

-- ============================================================================
-- Step 2: Thread Trace
-- ============================================================================

function Diagnostics.OnThreadStart(resource, threadName)
    if not isEnabled() then return end
    stats.threadsStarted = stats.threadsStarted + 1
    local id = generateId()
    trackedThreads[id] = {
        id = id,
        resource = resource,
        name = threadName,
        started = GetGameTimer and GetGameTimer() or os.time(),
        completed = nil,
    }
    diagPrint("DCE][THREAD", "==========================================")
    diagPrint("DCE][THREAD", "[DCE][THREAD]")
    diagPrint("DCE][THREAD", "Resource: " .. tostring(resource))
    diagPrint("DCE][THREAD", "Thread Name: " .. tostring(threadName))
    diagPrint("DCE][THREAD", "Started: " .. trackedThreads[id].started)
    diagPrint("DCE][THREAD", "Completed: (pending)")
    diagPrint("DCE][THREAD", "==========================================")
    
    -- Set up timeout warning
    if SetTimeout then
        callbackTimeouts[id] = SetTimeout(5000, function()
            if trackedThreads[id] and not trackedThreads[id].completed then
                stats.warnings = stats.warnings + 1
                diagPrint("DCE WARNING", "==========================================")
                diagPrint("DCE WARNING", "[DCE][WARNING]")
                diagPrint("DCE WARNING", "Possible hung thread")
                diagPrint("DCE WARNING", "Thread: " .. tostring(threadName))
                diagPrint("DCE WARNING", "Started: " .. trackedThreads[id].started)
                diagPrint("DCE WARNING", "Elapsed: " .. ((GetGameTimer and GetGameTimer() or os.time()) - trackedThreads[id].started))
                diagPrint("DCE WARNING", "Current Step: " .. tostring(trackedThreads[id].lastStep or "unknown"))
                diagPrint("DCE WARNING", "==========================================")
            end
        end)
    end
    
    return id
end

function Diagnostics.OnThreadComplete(threadId, step)
    if not isEnabled() then return end
    if trackedThreads[threadId] then
        trackedThreads[threadId].completed = GetGameTimer and GetGameTimer() or os.time()
        trackedThreads[threadId].lastStep = step
        stats.threadsFinished = stats.threadsFinished + 1
        
        if trackedThreads[threadId].started then
            local elapsed = trackedThreads[threadId].completed - trackedThreads[threadId].started
            diagPrint("DCE][THREAD", "==========================================")
            diagPrint("DCE][THREAD", "[DCE][THREAD]")
            diagPrint("DCE][THREAD", "Resource: " .. tostring(trackedThreads[threadId].resource))
            diagPrint("DCE][THREAD", "Thread Name: " .. tostring(trackedThreads[threadId].name))
            diagPrint("DCE][THREAD", "Started: " .. trackedThreads[threadId].started)
            diagPrint("DCE][THREAD", "Completed: " .. trackedThreads[threadId].completed)
            diagPrint("DCE][THREAD", "Execution Time: " .. elapsed .. "ms")
            diagPrint("DCE][THREAD", "==========================================")
        end
        
        -- Clear timeout
        if callbackTimeouts[threadId] and ClearTimeout then
            ClearTimeout(callbackTimeouts[threadId])
            callbackTimeouts[threadId] = nil
        end
    end
end

-- ============================================================================
-- Step 3: EventBus Trace
-- ============================================================================

function Diagnostics.OnEventEmit(eventName, source)
    if not isEnabled() then return end
    stats.eventsPublished = stats.eventsPublished + 1
    local startTime = GetGameTimer and GetGameTimer() or os.time()
    
    diagPrint("DCE][EVENT", "==========================================")
    diagPrint("DCE][EVENT", "[DCE][EVENT]")
    diagPrint("DCE][EVENT", "Time: " .. startTime)
    diagPrint("DCE][EVENT", "Event Name: " .. tostring(eventName))
    diagPrint("DCE][EVENT", "Publisher: " .. tostring(source))
    
    -- Get subscribers (requires EventBus access)
    local DCEEventBus = _G.DCEEventBus or {}
    local handlerCount = DCEEventBus.HandlerCount and DCEEventBus.HandlerCount(eventName) or 0
    diagPrint("DCE][EVENT", "Subscribers: " .. handlerCount)
    
    diagPrint("DCE][EVENT", "==========================================")
    
    return startTime
end

function Diagnostics.OnEventComplete(startTime, eventName, errorOccurred)
    if not isEnabled() then return end
    if errorOccurred then
        stats.eventsReceived = stats.eventsReceived - 1 -- Don't double count
    end
    stats.eventsReceived = stats.eventsReceived + 1
    
    local endTime = GetGameTimer and GetGameTimer() or os.time()
    local elapsed = (endTime - startTime)
    
    diagPrint("DCE][EVENT", "==========================================")
    diagPrint("DCE][EVENT", "[DCE][EVENT]")
    diagPrint("DCE][EVENT", "Execution Time: " .. elapsed .. "ms")
    if errorOccurred then
        diagPrint("DCE][EVENT][ERROR", "[DCE][EVENT][ERROR]")
        diagPrint("DCE][EVENT][ERROR", "Error occurred during event processing")
    end
    diagPrint("DCE][EVENT", "==========================================")
end

function Diagnostics.OnEventNoSubscribers(eventName)
    if not isEnabled() then return end
    diagPrint("DCE][EVENT", "[DCE][EVENT] No subscribers for: " .. tostring(eventName))
end

function Diagnostics.OnEventError(eventName, handlerId, error, stack)
    if not isEnabled() then return end
    stats.errors = stats.errors + 1
    diagPrint("DCE][EVENT][ERROR", "==========================================")
    diagPrint("DCE][EVENT][ERROR", "[DCE][EVENT][ERROR]")
    diagPrint("DCE][EVENT][ERROR", "Event: " .. tostring(eventName))
    diagPrint("DCE][EVENT][ERROR", "Subscriber: " .. tostring(handlerId))
    diagPrint("DCE][EVENT][ERROR", "Error: " .. tostring(error))
    if stack then
        diagPrint("DCE][EVENT][ERROR", "Stack: " .. tostring(stack))
    end
    diagPrint("DCE][EVENT][ERROR", "==========================================")
end

-- ============================================================================
-- Step 4: NUI Focus Trace
-- ============================================================================

local focusSequence = 0

function Diagnostics.OnSetNuiFocus(hasFocus, hasCursor, resource, caller)
    if not isEnabled() then return end
    stats.focusChanges = stats.focusChanges + 1
    focusSequence = focusSequence + 1
    
    if hasFocus then
        nuiFocusOwner.focus = resource or "unknown"
        nuiFocusOwner.cursor = resource or "unknown"
        nuiFocusOwner.keyboard = resource or "unknown"
    else
        nuiFocusOwner.focus = "unknown"
        nuiFocusOwner.cursor = "unknown"
        nuiFocusOwner.keyboard = "unknown"
    end
    
    diagPrint("DCE][NUI", "==========================================")
    diagPrint("DCE][NUI", "[DCE][NUI]")
    diagPrint("DCE][NUI", "Function: SetNuiFocus")
    diagPrint("DCE][NUI", "Arguments: hasFocus=" .. tostring(hasFocus) .. ", hasCursor=" .. tostring(hasCursor))
    diagPrint("DCE][NUI", "Resource: " .. tostring(resource or "dce-admin"))
    diagPrint("DCE][NUI", "Caller: " .. tostring(caller or "unknown"))
    diagPrint("DCE][NUI", "Stack: " .. getStackTrace(3))
    diagPrint("DCE][NUI", "Timestamp: " .. (GetGameTimer and GetGameTimer() or os.time()))
    diagPrint("DCE][NUI", "==========================================")
    
    if hasFocus then
        diagPrint("DCE][NUI", "Focus #" .. focusSequence)
        diagPrint("DCE][NUI", "Requested by: " .. tostring(resource or "dce-admin") .. "/client/nui.lua")
        diagPrint("DCE][NUI", "Function: " .. tostring(caller or "unknown"))
        diagPrint("DCE][NUI", "Time: " .. (GetGameTimer and GetGameTimer() or os.time()))
    end
end

function Diagnostics.OnSetNuiFocusKeepInput(keepInput, resource, caller)
    if not isEnabled() then return end
    
    diagPrint("DCE][NUI", "==========================================")
    diagPrint("DCE][NUI", "[DCE][NUI]")
    diagPrint("DCE][NUI", "Function: SetNuiFocusKeepInput")
    diagPrint("DCE][NUI", "Arguments: keepInput=" .. tostring(keepInput))
    diagPrint("DCE][NUI", "Resource: " .. tostring(resource or "dce-admin"))
    diagPrint("DCE][NUI", "Caller: " .. tostring(caller or "unknown"))
    diagPrint("DCE][NUI", "Stack: " .. getStackTrace(3))
    diagPrint("DCE][NUI", "Timestamp: " .. (GetGameTimer and GetGameTimer() or os.time()))
    diagPrint("DCE][NUI", "==========================================")
end

function Diagnostics.OnSetCursorLocation(x, y, resource, caller)
    if not isEnabled() then return end
    
    diagPrint("DCE][NUI", "==========================================")
    diagPrint("DCE][NUI", "[DCE][NUI]")
    diagPrint("DCE][NUI", "Function: SetCursorLocation")
    diagPrint("DCE][NUI", "Arguments: x=" .. tostring(x) .. ", y=" .. tostring(y))
    diagPrint("DCE][NUI", "Resource: " .. tostring(resource or "dce-admin"))
    diagPrint("DCE][NUI", "Caller: " .. tostring(caller or "unknown"))
    diagPrint("DCE][NUI", "Stack: " .. getStackTrace(3))
    diagPrint("DCE][NUI", "Timestamp: " .. (GetGameTimer and GetGameTimer() or os.time()))
    diagPrint("DCE][NUI", "==========================================")
end

function Diagnostics.OnSendNUIMessage(action, data, resource)
    if not isEnabled() then return end
    stats.nuiMessages = stats.nuiMessages + 1
    
    diagPrint("DCE][NUI", "==========================================")
    diagPrint("DCE][NUI", "[DCE][NUI]")
    diagPrint("DCE][NUI", "Function: SendNUIMessage")
    diagPrint("DCE][NUI", "Arguments: action=" .. tostring(action))
    if data then
        local payloadStr = ""
        for k, v in pairs(data) do
            if #payloadStr > 100 then break end
            payloadStr = payloadStr .. tostring(k) .. "=" .. tostring(v) .. " "
        end
        diagPrint("DCE][NUI", "Data: " .. payloadStr)
    end
    diagPrint("DCE][NUI", "Resource: " .. tostring(resource or "dce-admin"))
    diagPrint("DCE][NUI", "Stack: " .. getStackTrace(3))
    diagPrint("DCE][NUI", "Timestamp: " .. (GetGameTimer and GetGameTimer() or os.time()))
    diagPrint("DCE][NUI", "==========================================")
end

-- ============================================================================
-- Step 5: Lifecycle State Machine (JavaScript trace comes via message)
-- ============================================================================

function Diagnostics.SetLifecycleState(newState, caller)
    if not isEnabled() then return end
    
    -- Check illegal transitions
    if newState == "OPEN" and lifecycleState.value ~= "AUTHORIZED" then
        stats.illegalStateChanges = stats.illegalStateChanges + 1
        diagPrint("DCE ERROR", "==========================================")
        diagPrint("DCE ERROR", "[DCE ERROR]")
        diagPrint("DCE ERROR", "Illegal State Transition")
        diagPrint("DCE ERROR", "Previous: " .. lifecycleState.value)
        diagPrint("DCE ERROR", "Current: " .. newState)
        diagPrint("DCE ERROR", "Caller: " .. tostring(caller or "unknown"))
        diagPrint("DCE ERROR", "Stack: " .. getStackTrace(3))
        diagPrint("DCE ERROR", "==========================================")
        return
    end
    
    -- Track state history
    table.insert(lifecycleState.history, {
        from = lifecycleState.value,
        to = newState,
        time = GetGameTimer and GetGameTimer() or os.time(),
    })
    
    diagPrint("DCE STATE", "==========================================")
    diagPrint("DCE STATE", "[DCE STATE]")
    for _, entry in ipairs(lifecycleState.history) do
        diagPrint("DCE STATE", entry.from .. " → " .. entry.to)
    end
    diagPrint("DCE STATE", "==========================================")
    
    lifecycleState.value = newState
    lifecycleState.lastTransition = {
        from = lifecycleState.value,
        to = newState,
        caller = caller,
    }
end

function Diagnostics.GetLifecycleState()
    return lifecycleState.value
end

-- ============================================================================
-- Step 7: Callback Trace
-- ============================================================================

function Diagnostics.OnRegisterNUICallback(name, startTime)
    if not isEnabled() then return end
    
    diagPrint("DCE CALLBACK", "==========================================")
    diagPrint("DCE CALLBACK", "[DCE CALLBACK]")
    diagPrint("DCE CALLBACK", "Name: " .. tostring(name))
    diagPrint("DCE CALLBACK", "Started: " .. tostring(startTime or (GetGameTimer and GetGameTimer() or os.time())))
end

function Diagnostics.OnCallbackComplete(name, startTime, response)
    if not isEnabled() then return end
    
    local endTime = GetGameTimer and GetGameTimer() or os.time()
    local duration = endTime - startTime
    
    diagPrint("DCE CALLBACK", "==========================================")
    diagPrint("DCE CALLBACK", "[DCE CALLBACK]")
    diagPrint("DCE CALLBACK", "Name: " .. tostring(name))
    diagPrint("DCE CALLBACK", "Finished: " .. endTime)
    diagPrint("DCE CALLBACK", "Duration: " .. duration .. "ms")
    if duration > 2000 then
        stats.warnings = stats.warnings + 1
        diagPrint("DCE CALLBACK", "[WARNING] Callback timeout - exceeded 2 seconds")
        diagPrint("DCE CALLBACK", "Name: " .. tostring(name))
        diagPrint("DCE CALLBACK", "Elapsed: " .. duration .. "ms")
    end
end

-- ============================================================================
-- Step 9: Authorization Trace
-- ============================================================================

function Diagnostics.OnAuthCheck(resource, func, aceResult, allowed)
    if not isEnabled() then return end
    stats.authRequests = stats.authRequests + 1
    
    diagPrint("DCE AUTH", "==========================================")
    diagPrint("DCE AUTH", "[DCE AUTH]")
    diagPrint("DCE AUTH", "Who requested opening?")
    diagPrint("DCE AUTH", "Resource: " .. tostring(resource or "dce-admin"))
    diagPrint("DCE AUTH", "Function: " .. tostring(func or "unknown"))
    diagPrint("DCE AUTH", "Permission Check: Admin ACE")
    diagPrint("DCE AUTH", "ACE Result: " .. tostring(aceResult))
    diagPrint("DCE AUTH", allowed and "Allowed" or "Denied")
    diagPrint("DCE AUTH", "==========================================")
end

-- ============================================================================
-- Step 10: Performance Timing
-- ============================================================================

function Diagnostics.StartTimer(task)
    if not isEnabled() then return end
    timers[task] = GetGameTimer and GetGameTimer() or os.time()
end

function Diagnostics.EndTimer(task)
    if not isEnabled() then return end
    if timers[task] then
        local elapsed = (GetGameTimer and GetGameTimer() or os.time()) - timers[task]
        diagPrint("DCE TIMER", "==========================================")
        diagPrint("DCE TIMER", "[DCE TIMER]")
        diagPrint("DCE TIMER", "Task: " .. task)
        diagPrint("DCE TIMER", "Milliseconds: " .. elapsed)
        diagPrint("DCE TIMER", "==========================================")
        timers[task] = nil
    end
end

-- ============================================================================
-- Step 12: Resource Ownership
-- ============================================================================

function Diagnostics.GetOwnership()
    if not isEnabled() then return {} end
    return nuiFocusOwner
end

function Diagnostics.UpdateFocusOwner(resource, focus, keyboard, cursor)
    if not isEnabled() then return end
    if focus ~= nil then nuiFocusOwner.focus = resource end
    if keyboard ~= nil then nuiFocusOwner.keyboard = resource end
    if cursor ~= nil then nuiFocusOwner.cursor = resource end
end

-- ============================================================================
-- Step 13: Hang Detection
-- ============================================================================

local hangDetectionStartTime = nil

function Diagnostics.MarkStartupStart()
    if not isEnabled() then return end
    hangDetectionStartTime = GetGameTimer and GetGameTimer() or os.time()
    
    -- Start 10-second watchdog
    if SetTimeout then
        SetTimeout(10000, function()
            if not startupComplete then
                stats.warnings = stats.warnings + 1
                diagPrint("DCE WARNING", "==========================================")
                diagPrint("DCE WARNING", "[DCE WARNING]")
                diagPrint("DCE WARNING", "Startup appears stalled.")
                diagPrint("DCE WARNING", "Current Phase: " .. tostring(lifecycleState.value))
                diagPrint("DCE WARNING", "Current Function: unknown")
                diagPrint("DCE WARNING", "Last Completed Step: unknown")
                diagPrint("DCE WARNING", "==========================================")
            end
        end)
    end
end

function Diagnostics.MarkStartupComplete()
    if not isEnabled() then return end
    startupComplete = true
    if hangDetectionStartTime then
        local elapsed = (GetGameTimer and GetGameTimer() or os.time()) - hangDetectionStartTime
        diagPrint("DCE TIMER", "==========================================")
        diagPrint("DCE TIMER", "[DCE TIMER]")
        diagPrint("DCE TIMER", "Task: Total Startup")
        diagPrint("DCE TIMER", "Milliseconds: " .. elapsed)
        diagPrint("DCE TIMER", "==========================================")
    end
end

-- ============================================================================
-- Step 15: Final Summary
-- ============================================================================

function Diagnostics.PrintSummary()
    if not isEnabled() then return end
    
    diagPrint("DCE SUMMARY", "==========================================")
    diagPrint("DCE SUMMARY", "DCE STARTUP SUMMARY")
    diagPrint("DCE SUMMARY", "==========================================")
    diagPrint("DCE SUMMARY", "Resources Loaded: " .. stats.resourcesLoaded)
    diagPrint("DCE SUMMARY", "Threads Started: " .. stats.threadsStarted)
    diagPrint("DCE SUMMARY", "Threads Finished: " .. stats.threadsFinished)
    diagPrint("DCE SUMMARY", "Events Published: " .. stats.eventsPublished)
    diagPrint("DCE SUMMARY", "Events Received: " .. stats.eventsReceived)
    diagPrint("DCE SUMMARY", "NUI Messages: " .. stats.nuiMessages)
    diagPrint("DCE SUMMARY", "Focus Changes: " .. stats.focusChanges)
    diagPrint("DCE SUMMARY", "Authorization Requests: " .. stats.authRequests)
    diagPrint("DCE SUMMARY", "Illegal State Changes: " .. stats.illegalStateChanges)
    diagPrint("DCE SUMMARY", "Warnings: " .. stats.warnings)
    diagPrint("DCE SUMMARY", "Errors: " .. stats.errors)
    diagPrint("DCE SUMMARY", "Total Startup Time: " .. (hangDetectionStartTime and ((GetGameTimer and GetGameTimer() or os.time()) - hangDetectionStartTime) or 0) .. "ms")
    diagPrint("DCE SUMMARY", "==========================================")
end

-- ============================================================================
-- Shutdown Trace (Step 14)
-- ============================================================================

function Diagnostics.OnShutdown()
    if not isEnabled() then return end
    
    diagPrint("DCE CLOSE", "==========================================")
    diagPrint("DCE CLOSE", "[DCE CLOSE]")
    diagPrint("DCE CLOSE", "Closing")
    diagPrint("DCE CLOSE", "↓")
    diagPrint("DCE CLOSE", "Releasing Focus")
    diagPrint("DCE CLOSE", "↓")
    diagPrint("DCE CLOSE", "Clearing Cursor")
    diagPrint("DCE CLOSE", "↓")
    diagPrint("DCE CLOSE", "Removing Listeners")
    diagPrint("DCE CLOSE", "↓")
    diagPrint("DCE CLOSE", "Finished")
    diagPrint("DCE CLOSE", "==========================================")
end

-- ============================================================================
-- Watchdog (Step 11)
-- ============================================================================

local function checkWatchdogConditions()
    if not isEnabled() then return end
    
    -- Check focus/UI state mismatch
    if nuiFocusOwner.focus ~= "unknown" and lifecycleState.value == "CLOSED" then
        stats.warnings = stats.warnings + 1
        diagPrint("DCE WATCHDOG", "==========================================")
        diagPrint("DCE WATCHDOG", "[DCE WATCHDOG]")
        diagPrint("DCE WATCHDOG", "Focus: TRUE")
        diagPrint("DCE WATCHDOG", "UI: FALSE")
        diagPrint("DCE WATCHDOG", "[WARNING] Focus mismatch detected")
        diagPrint("DCE WATCHDOG", "==========================================")
    end
end

-- Start periodic watchdog
local watchdogRunning = false
function Diagnostics.StartWatchdog()
    if not isEnabled() then return end
    if watchdogRunning then return end
    watchdogRunning = true
    
    if Citizen and Citizen.CreateThread then
        Citizen.CreateThread(function()
            while watchdogRunning do
                Citizen.Wait(1000)
                checkWatchdogConditions()
            end
        end)
    end
end

function Diagnostics.StopWatchdog()
    watchdogRunning = false
end

_G.DCEDiagnostics = Diagnostics
return Diagnostics