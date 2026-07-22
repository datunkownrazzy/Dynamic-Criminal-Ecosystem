-- DCE Runtime Diagnostic Logger
-- Phase 1: Runtime Diagnostic Logger
-- Provides structured diagnostic logging with tagged output format:
-- [DCE][CORE][INFO] instead of raw print statements.
-- Every important runtime decision leaves evidence.
--
-- DF-002 FIX: State is now stored in centralized RuntimeState (DCERuntimeState.diagnostics)
-- No local state ownership. All modules consume shared state.

local Diagnostics = {}
local logger

-- Entry types
local ENTRY_TYPES = {
    INFO = "INFO",
    WARN = "WARN",
    ERROR = "ERROR",
    SUCCESS = "SUCCESS",
    TRACE = "TRACE",
    SECTION = "SECTION",
    MARKER = "MARKER",
    ASSERT = "ASSERT",
}

--- Get diagnostics state from RuntimeState
local function getState()
    local state = _G.DCERuntimeState
    if state and state.diagnostics then
        return state.diagnostics
    end
    -- Fallback: create local state if RuntimeState unavailable (graceful degradation)
    local gd = _G.DCEGracefulDegradation
    if gd and gd.ReportFailure then
        gd.ReportFailure("Diagnostics", "RuntimeState.diagnostics", "nil", "diagnostics.lua", "getState")
    end
    return nil
end

--- Initialize the diagnostics module
function Diagnostics.Init(log)
    logger = log
    local state = getState()
    if state then
        state.initialized = true
        state.startupTime = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
    end
    Diagnostics.Info("CORE", "Runtime Diagnostic Logger initialized")

    -- Mark subsystem operational
    local gd = _G.DCEGracefulDegradation
    if gd and gd.MarkOperational then
        gd.MarkOperational("Diagnostics")
    end
end

--- Get current timestamp in milliseconds since startup
local function getTimestamp()
    local state = getState()
    local now = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
    if state and state.startupTime then
        return string.format("%06.3f", (now - state.startupTime) / 1000)
    end
    return string.format("%06.3f", now / 1000)
end

--- Get caller info: file, function, line
local function getCallerInfo(levels)
    levels = levels or 3
    local info = { file = "unknown", func = "unknown", line = "?" }
    local success, trace = pcall(function()
        return debug and debug.traceback and debug.traceback("", levels) or ""
    end)
    if success and trace then
        for line in trace:gmatch("[^\n]+") do
            local f, l = line:match("@(.+):(%d+):")
            if f then
                local name = f:match("[^/\\]+$") or f
                info.file = name
                info.line = l
                local fn = line:match("in function '([^']+)'")
                if fn then info.func = fn end
                break
            end
        end
    end
    return info
end

--- Internal: record a diagnostic entry
local function recordEntry(entryType, module, message, caller)
    caller = caller or getCallerInfo(4)
    local timestamp = getTimestamp()
    local entry = {
        type = entryType,
        timestamp = timestamp,
        module = module,
        message = message,
        caller = caller,
    }

    local state = getState()
    if state and state.entries then
        table.insert(state.entries, entry)

        -- Track warnings and errors separately
        if entryType == ENTRY_TYPES.WARN then
            table.insert(state.warnings, entry)
        elseif entryType == ENTRY_TYPES.ERROR or entryType == ENTRY_TYPES.ASSERT then
            table.insert(state.errors, entry)
        end
    end

    return entry
end

--- Format a diagnostic output line
local function formatOutput(level, module, message)
    return string.format("[DCE][%s][%s] %s", module, level, message)
end

--- Print a diagnostic line to console
local function diagPrint(level, module, message)
    local output = formatOutput(level, module, message)
    if level == "ERROR" or level == "ASSERT" then
        print("^1" .. output .. "^0")
    elseif level == "WARN" then
        print("^3" .. output .. "^0")
    elseif level == "SUCCESS" then
        print("^2" .. output .. "^0")
    elseif level == "TRACE" then
        print("^5" .. output .. "^0")
    else
        print(output)
    end
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Log an informational diagnostic message
function Diagnostics.Info(module, message, ...)
    local state = getState()
    if not state or not state.initialized then return end
    if ... then message = string.format(message, ...) end
    recordEntry(ENTRY_TYPES.INFO, module, message)
    diagPrint("INFO", module, message)
end

--- Log a warning diagnostic message
function Diagnostics.Warn(module, message, ...)
    local state = getState()
    if not state or not state.initialized then return end
    if ... then message = string.format(message, ...) end
    recordEntry(ENTRY_TYPES.WARN, module, message)
    diagPrint("WARN", module, message)
end

--- Log an error diagnostic message
function Diagnostics.Error(module, message, ...)
    local state = getState()
    if not state or not state.initialized then return end
    if ... then message = string.format(message, ...) end
    recordEntry(ENTRY_TYPES.ERROR, module, message, getCallerInfo(4))
    diagPrint("ERROR", module, message)
end

--- Log a success diagnostic message
function Diagnostics.Success(module, message, ...)
    local state = getState()
    if not state or not state.initialized then return end
    if ... then message = string.format(message, ...) end
    recordEntry(ENTRY_TYPES.SUCCESS, module, message)
    diagPrint("SUCCESS", module, message)
end

--- Log a trace diagnostic message (verbose debugging)
function Diagnostics.Trace(module, message, ...)
    local state = getState()
    if not state or not state.initialized then return end
    if ... then message = string.format(message, ...) end
    recordEntry(ENTRY_TYPES.TRACE, module, message)
    diagPrint("TRACE", module, message)
end

--- Begin a diagnostic section
function Diagnostics.Section(name)
    local state = getState()
    if not state or not state.initialized then return end
    local timestamp = getTimestamp()
    local caller = getCallerInfo(4)
    recordEntry(ENTRY_TYPES.SECTION, "SECTION", "=== " .. name .. " ===", caller)
    state.sections[name] = state.sections[name] or { entries = {}, startTime = timestamp }
    state.activeSection = name
    state.sectionDepth = (state.sectionDepth or 0) + 1
    print(string.format("^4[DCE][CORE][SECTION] === %s ===^0", name))
end

--- End the current diagnostic section
function Diagnostics.EndSection()
    local state = getState()
    if not state or not state.initialized or (state.sectionDepth or 0) <= 0 then return end
    state.sectionDepth = (state.sectionDepth or 0) - 1
    if state.activeSection then
        local sectionData = state.sections[state.activeSection]
        if sectionData then
            sectionData.endTime = getTimestamp()
        end
        print(string.format("^4[DCE][CORE][SECTION] === End %s ===^0", state.activeSection))
    end
    state.activeSection = nil
end

--- Record a marker in the diagnostic timeline
function Diagnostics.Marker(name)
    local state = getState()
    if not state or not state.initialized then return end
    recordEntry(ENTRY_TYPES.MARKER, "MARKER", name)
    diagPrint("INFO", "MARKER", name)
end

--- Log an assertion failure as a structured diagnostic
function Diagnostics.Assert(expected, received, context)
    local state = getState()
    if not state or not state.initialized then return end
    local caller = getCallerInfo(4)
    local entry = recordEntry(ENTRY_TYPES.ASSERT, "ASSERT", 
        string.format("%s Expected: %s Received: %s Caller: %s File: %s Line: %s",
            context or "Assertion failed",
            tostring(expected),
            tostring(received),
            caller.func,
            caller.file,
            caller.line
        ), caller)
    if state and state.assertionFailures then
        table.insert(state.assertionFailures, entry)
    end
    diagPrint("ASSERT", "ASSERT", string.format("%s Expected: %s Received: %s Caller: %s File: %s Line: %s",
        context or "Assertion failed",
        tostring(expected),
        tostring(received),
        caller.func,
        caller.file,
        caller.line
    ))
end

-- ============================================================================
-- Query methods (for report generation and commands)
-- ============================================================================

--- Get all diagnostic entries
function Diagnostics.GetEntries()
    local state = getState()
    return state and state.entries or {}
end

--- Get all warnings
function Diagnostics.GetWarnings()
    local state = getState()
    return state and state.warnings or {}
end

--- Get all errors
function Diagnostics.GetErrors()
    local state = getState()
    return state and state.errors or {}
end

--- Get all assertion failures
function Diagnostics.GetAssertionFailures()
    local state = getState()
    return state and state.assertionFailures or {}
end

--- Get all entries of a specific type
function Diagnostics.GetEntriesByType(entryType)
    local state = getState()
    if not state or not state.entries then return {} end
    local result = {}
    for _, entry in ipairs(state.entries) do
        if entry.type == entryType then
            table.insert(result, entry)
        end
    end
    return result
end

--- Get entries for a specific module
function Diagnostics.GetEntriesByModule(module)
    local state = getState()
    if not state or not state.entries then return {} end
    local result = {}
    for _, entry in ipairs(state.entries) do
        if entry.module == module then
            table.insert(result, entry)
        end
    end
    return result
end

--- Get a summary of diagnostic statistics
function Diagnostics.GetStats()
    local state = getState()
    if not state then
        return { total = 0, info = 0, warnings = 0, errors = 0, success = 0, traces = 0, assertions = 0, sections = 0 }
    end
    return {
        total = #state.entries,
        info = #(Diagnostics.GetEntriesByType(ENTRY_TYPES.INFO)),
        warnings = #state.warnings,
        errors = #state.errors,
        success = #(Diagnostics.GetEntriesByType(ENTRY_TYPES.SUCCESS)),
        traces = #(Diagnostics.GetEntriesByType(ENTRY_TYPES.TRACE)),
        assertions = #state.assertionFailures,
        sections = state.sections and #state.sections or 0,
    }
end

--- Get the startup timestamp
function Diagnostics.GetStartupTime()
    local state = getState()
    return state and state.startupTime or nil
end

--- Get the current elapsed time since startup in ms
function Diagnostics.GetElapsed()
    local state = getState()
    local now = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
    if state and state.startupTime then
        return now - state.startupTime
    end
    return 0
end

--- Check if diagnostics are initialized
function Diagnostics.IsReady()
    local state = getState()
    return state and state.initialized or false
end

--- Reset diagnostic state (for restart scenarios)
function Diagnostics.Reset()
    local state = getState()
    if state then
        state.entries = {}
        state.warnings = {}
        state.errors = {}
        state.assertionFailures = {}
        state.sections = {}
        state.activeSection = nil
        state.sectionDepth = 0
        state.startupTime = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
        Diagnostics.Info("CORE", "Diagnostics reset")
    end
end

--- Print the full diagnostic log
function Diagnostics.PrintLog()
    local state = getState()
    if not state or not state.entries then return end
    print("^4=====================================^0")
    print("^4[DCE] Full Diagnostic Log^0")
    print("^4=====================================^0")
    for _, entry in ipairs(state.entries) do
        if entry.type ~= ENTRY_TYPES.SECTION then
            print(string.format("[%s][DCE][%s][%s] %s", entry.timestamp, entry.module, entry.type, entry.message))
        end
    end
    print("^4=====================================^0")
end

_G.DCEDiagnostics = Diagnostics
return Diagnostics