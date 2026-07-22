-- DCE Control Center Diagnostics
-- Phase 8: Control Center Diagnostics
-- NOTE: "undefined-field" diagnostics below are false positives from LuaLS.
-- ccState.failure is a dynamically-assigned table accessed via nil-safe patterns.
-- The `ccState.failure and ccState.failure.stage` pattern is intentional runtime safety.
---@diagnostic disable: undefined-field
-- When /dce is executed, print every transition.
-- If any stage fails, print FAILED with Reason, File, Function, Resource.
--
-- DF-002 FIX: State is now stored in centralized RuntimeState (DCERuntimeState.ccDiagnostics)
-- No local state ownership. All modules consume shared state.

local CCDiagnostics = {}

-- Control Center lifecycle stages
local CC_STAGES = {
    "Command Received",
    "API Retrieved",
    "Session Created",
    "Browser Started",
    "NUI Ready",
    "Focus Granted",
    "Workspace Loaded",
    "Desktop Visible",
}

--- Get CC diagnostics state from RuntimeState
local function getState()
    local state = _G.DCERuntimeState
    if state and state.ccDiagnostics then
        return state.ccDiagnostics
    end
    local gd = _G.DCEGracefulDegradation
    if gd and gd.ReportFailure then
        gd.ReportFailure("CCDiagnostics", "RuntimeState.ccDiagnostics", "nil", "cc-diagnostics.lua", "getState")
    end
    return nil
end

--- Initialize CC diagnostics
function CCDiagnostics.Init()
    local ccState = getState()
    if ccState then
        ccState.initialized = true
        ccState.transitions = {}
        ccState.state = {
            currentStage = nil,
            started = false,
            completed = false,
            failed = false,
            failure = nil,
            startTime = nil,
        }
    end

    -- Mark subsystem operational
    local gd = _G.DCEGracefulDegradation
    if gd and gd.MarkOperational then
        gd.MarkOperational("CCDiagnostics")
    end
end

--- Record a Control Center transition
function CCDiagnostics.RecordTransition(stage, status, details)
    local ccState = getState()
    if not ccState or not ccState.initialized then return end

    local timestamp = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
    local caller = { file = "unknown", func = "unknown", resource = "dce-controlcenter" }

    local success, trace = pcall(function()
        return debug and debug.traceback and debug.traceback("", 3) or ""
    end)
    if success and trace then
        for line in trace:gmatch("[^\n]+") do
            local f = line:match("@(.+):%d+:")
            if f then
                caller.file = f:match("[^/\\]+$") or f
                local fn = line:match("in function '([^']+)'")
                if fn then caller.func = fn end
                break
            end
        end
    end

    local transition = {
        stage = stage,
        status = status or "PASS",
        details = details,
        timestamp = timestamp,
        caller = caller,
    }

    if ccState then
        table.insert(ccState.transitions, transition)
        ccState.state.currentStage = stage

        if status == "FAILED" then
            ccState.state.failed = true
            ccState.state.failure = {
                stage = stage,
                reason = details,
                file = caller.file,
                func = caller.func,
                resource = caller.resource,
            }
        end
    end

    -- Print the transition
    local color = (status == "PASS" or status == "SUCCESS") and "2" or "1"
    local icon = (status == "PASS" or status == "SUCCESS") and "→" or "✗"
    print(string.format("^%s[DCE][CC] %s %s [%s]^0", color, icon, stage, status or "PASS"))
    if details then
        print(string.format("^%s[DCE][CC]   %s^0", color, details))
    end
    if status == "FAILED" then
        print(string.format("^1[DCE][CC]   FAILED Reason: %s^0", details or "Unknown"))
        print(string.format("^1[DCE][CC]   File: %s^0", caller.file))
        print(string.format("^1[DCE][CC]   Function: %s^0", caller.func))
        print(string.format("^1[DCE][CC]   Resource: %s^0", caller.resource))
    end
end

--- Mark CC startup as started
function CCDiagnostics.MarkStarted()
    local ccState = getState()
    if not ccState or not ccState.initialized then return end
    ccState.state.started = true
    ccState.state.startTime = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
    CCDiagnostics.RecordTransition("Command Received", "PASS")
end

--- Mark CC as fully completed
function CCDiagnostics.MarkCompleted()
    local ccState = getState()
    if not ccState or not ccState.initialized then return end
    ccState.state.completed = true
    CCDiagnostics.RecordTransition("Desktop Visible", "SUCCESS")

    local elapsed = 0
    if ccState.state.startTime then
        local now = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
        elapsed = now - ccState.state.startTime
    end

    print("^2=====================================^0")
    print("^2[DCE][CC] Control Center Startup Complete^0")
    print(string.format("^2[DCE][CC] Total Transitions: %d^0", #ccState.transitions))
    print(string.format("^2[DCE][CC] Startup Time: %dms^0", elapsed))
    print("^2=====================================^0")
end

--- Mark CC as failed
function CCDiagnostics.MarkFailed(stage, reason)
    local ccState = getState()
    if not ccState or not ccState.initialized then return end
    CCDiagnostics.RecordTransition(stage or "Unknown", "FAILED", reason)

    print("^1=====================================^0")
    print("^1[DCE][CC] Control Center Startup FAILED^0")
    print(string.format("^1[DCE][CC] Stage: %s^0", stage or "Unknown"))
    print(string.format("^1[DCE][CC] Reason: %s^0", reason or "Unknown"))
    if ccState.state.failure then
        print(string.format("^1[DCE][CC] File: %s^0", ccState.state.failure.file))
        print(string.format("^1[DCE][CC] Function: %s^0", ccState.state.failure.func))
        print(string.format("^1[DCE][CC] Resource: %s^0", ccState.state.failure.resource))
    end
    print("^1=====================================^0")
end

--- Get all CC transitions
function CCDiagnostics.GetTransitions()
    local ccState = getState()
    return ccState and ccState.transitions or {}
end

--- Get the current CC state
function CCDiagnostics.GetState()
    local ccState = getState()
    return ccState and ccState.state or { currentStage = nil, started = false, completed = false, failed = false, failure = nil, startTime = nil }
end

--- Get the failure info if CC failed
function CCDiagnostics.GetFailure()
    local ccState = getState()
    return ccState and ccState.state.failure or nil
end

--- Print the full CC transition log
function CCDiagnostics.PrintTransitions()
    local ccState = getState()
    if not ccState or not ccState.transitions then
        print("^3[DCE][CC] No transitions recorded^0")
        return
    end
    print("^4=====================================^0")
    print("^4[DCE][CC] Control Center Transition Log^0")
    print("^4=====================================^0")
    for _, t in ipairs(ccState.transitions) do
        local color = (t.status == "PASS" or t.status == "SUCCESS") and "2" or "1"
        print(string.format("^%s[DCE][CC] %s [%s]^0", color, t.stage, t.status))
        if t.details then
            print(string.format("^%s[DCE][CC]   %s^0", color, t.details))
        end
    end
    if ccState.state.failure then
        print("^1=====================================^0")
        print("^1[DCE][CC] FAILURE SUMMARY^0")
        print(string.format("^1[DCE][CC] Stage: %s^0", ccState.state.failure.stage))
        print(string.format("^1[DCE][CC] Reason: %s^0", ccState.state.failure.reason))
        print(string.format("^1[DCE][CC] File: %s^0", ccState.state.failure.file))
        print(string.format("^1[DCE][CC] Function: %s^0", ccState.state.failure.func))
        print(string.format("^1[DCE][CC] Resource: %s^0", ccState.state.failure.resource))
        print("^1=====================================^0")
    end
    print("^4=====================================^0")
end

--- Reset CC diagnostics
function CCDiagnostics.Reset()
    local ccState = getState()
    if ccState then
        ccState.transitions = {}
        ccState.state = {
            currentStage = nil,
            started = false,
            completed = false,
            failed = false,
            failure = nil,
            startTime = nil,
        }
    end
end

_G.DCECCDiagnostics = CCDiagnostics
return CCDiagnostics