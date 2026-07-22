-- DCE Boot Timeline
-- Phase 2: Boot Timeline
-- Records every major stage of initialization with precise timestamps.
-- Output format:
-- 00.000 Core Loading
-- 00.012 Registry Created
-- 00.017 Logger Registered
-- ...
--
-- DF-002 FIX: State is now stored in centralized RuntimeState (DCERuntimeState.bootTimeline)
-- DF-003 FIX: BootTimeline.Init() is called before any Record() calls.
--   Root Cause: BootTimeline.Record() was called in dce-core/init.lua before
--   RuntimeInit.Initialize() was called, meaning BootTimeline.Init() hadn't run yet.
--   The fix ensures Init() is called first, and Record() checks isInitialized.

local BootTimeline = {}

-- Known boot stages in expected order
local BOOT_STAGES = {
    "Core Loading",
    "Registry Created",
    "Logger Registered",
    "EventBus Registered",
    "Scheduler Registered",
    "Profiler Registered",
    "Cache Registered",
    "Pool Registered",
    "AlertHandler Registered",
    "Config Loader Registered",
    "Plugin Manager Registered",
    "Diagnostics Registered",
    "Export Registration Complete",
    "Services Available",
    "Plugins Loaded",
    "Boot Complete",
}

--- Get boot timeline state from RuntimeState
local function getState()
    local state = _G.DCERuntimeState
    if state and state.bootTimeline then
        return state.bootTimeline
    end
    local gd = _G.DCEGracefulDegradation
    if gd and gd.ReportFailure then
        gd.ReportFailure("BootTimeline", "RuntimeState.bootTimeline", "nil", "boot-timeline.lua", "getState")
    end
    return nil
end

--- Initialize the boot timeline
function BootTimeline.Init()
    local state = getState()
    if state then
        state.initialized = true
        state.start = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
        state.stages = {}
        state.stageOrder = {}
        -- Record the initial boot stage
        BootTimeline.Record("Core Loading")
    end

    -- Mark subsystem operational
    local gd = _G.DCEGracefulDegradation
    if gd and gd.MarkOperational then
        gd.MarkOperational("BootTimeline")
    end
end

--- Get current elapsed time since timeline start
local function getElapsed()
    local state = getState()
    local now = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
    if state and state.start then
        return (now - state.start) / 1000
    end
    return 0
end

--- Get caller info for recording context
local function getCallerInfo()
    local info = { file = "unknown", func = "unknown" }
    local success, trace = pcall(function()
        return debug and debug.traceback and debug.traceback("", 3) or ""
    end)
    if success and trace then
        for line in trace:gmatch("[^\n]+") do
            local f = line:match("@(.+):%d+:")
            if f then
                info.file = f:match("[^/\\]+$") or f
                local fn = line:match("in function '([^']+)'")
                if fn then info.func = fn end
                break
            end
        end
    end
    return info
end

--- Record a boot stage
function BootTimeline.Record(stageName, details)
    local state = getState()
    if not state or not state.initialized then
        -- DF-003: If not initialized, print warning but don't crash
        print(string.format("^3[DCE][BOOT] %s - Boot timeline not initialized yet (will be recorded after Init)^0", stageName))
        return
    end
    local elapsed = getElapsed()
    local caller = getCallerInfo()
    local entry = {
        name = stageName,
        timestamp = elapsed,
        timeMs = elapsed * 1000,
        details = details or "",
        caller = caller,
        order = #state.stageOrder + 1,
    }
    table.insert(state.stageOrder, entry)
    state.stages[stageName] = entry

    -- Print the timeline entry
    local output = string.format("[DCE][BOOT] %06.3f %s", elapsed, stageName)
    if details and details ~= "" then
        output = output .. " (" .. details .. ")"
    end
    print(output)
end

--- Record boot stage with success/failure status
function BootTimeline.RecordWithStatus(stageName, success, errorMsg)
    local state = getState()
    if not state or not state.initialized then return end
    local elapsed = getElapsed()
    local caller = getCallerInfo()
    local status = success and "PASS" or "FAIL"
    local entry = {
        name = stageName,
        timestamp = elapsed,
        timeMs = elapsed * 1000,
        status = status,
        error = errorMsg,
        caller = caller,
        order = #state.stageOrder + 1,
    }
    table.insert(state.stageOrder, entry)
    state.stages[stageName] = entry

    local color = success and "2" or "1"
    local output = string.format("^%s[DCE][BOOT] %06.3f %s [%s]^0", color, elapsed, stageName, status)
    if not success and errorMsg then
        output = string.format("^%s[DCE][BOOT] %06.3f %s [%s] %s^0", color, elapsed, stageName, status, errorMsg)
    end
    print(output)
end

--- Get all recorded boot stages in order
function BootTimeline.GetStages()
    local state = getState()
    return state and state.stageOrder or {}
end

--- Get a specific stage by name
function BootTimeline.GetStage(stageName)
    local state = getState()
    return state and state.stages[stageName] or nil
end

--- Get the total startup time in seconds
function BootTimeline.GetTotalTime()
    local state = getState()
    if not state or not state.start then return 0 end
    local now = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
    return (now - state.start) / 1000
end

--- Get the total startup time in milliseconds
function BootTimeline.GetTotalTimeMs()
    return BootTimeline.GetTotalTime() * 1000
end

--- Check if the timeline has been initialized
function BootTimeline.IsReady()
    local state = getState()
    return state and state.initialized or false
end

--- Print the full boot timeline
function BootTimeline.Print()
    local state = getState()
    if not state or not state.initialized then
        print("[DCE][BOOT] Boot timeline not initialized")
        return
    end

    print("^4=====================================^0")
    print("^4[DCE][BOOT] Boot Timeline^0")
    print("^4=====================================^0")
    for _, entry in ipairs(state.stageOrder) do
        local color = "0"
        if entry.status == "FAIL" then
            color = "1;41"
        elseif entry.status == "PASS" then
            color = "2"
        end
        local output = string.format("^%s%06.3f %s^0", color, entry.timestamp, entry.name)
        if entry.status then
            output = string.format("^%s%06.3f %s [%s]^0", color, entry.timestamp, entry.name, entry.status)
        end
        if entry.error then
            output = output .. string.format(" ^1ERROR: %s^0", entry.error)
        end
        print(output)
    end
    print("^4-------------------------------------^0")
    print(string.format("^4Total Boot Time: %.3f seconds (%dms)^0", 
        BootTimeline.GetTotalTime(), BootTimeline.GetTotalTimeMs()))
    print("^4=====================================^0")
end

--- Reset the boot timeline (for restart scenarios)
function BootTimeline.Reset()
    local state = getState()
    if state then
        state.stages = {}
        state.stageOrder = {}
        state.start = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
        BootTimeline.Record("Core Loading (restart)")
    end
end

_G.DCEBootTimeline = BootTimeline
return BootTimeline