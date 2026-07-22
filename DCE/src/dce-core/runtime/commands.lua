-- DCE Diagnostic Commands
-- Phase 11: Diagnostic Commands
-- Creates developer commands:
-- /dce_diag - Shows loaded services, missing services, export status, EventBus status,
--             active resources, current session state, plugin count
-- /dce_health - Runs every validation again while the server is running
-- /dce_events - Shows registered events, subscriber counts, events emitted since startup
-- /dce_services - Displays Logger ✓ Registry ✓ EventBus ✓ Scheduler ✓ PluginManager ✓
-- /dce_boot - Reprints the boot timeline
--
-- SPRINT-1.6A FIX: Every printf-style print() call now uses string.format() correctly.
--   Root Cause: print() in Lua does NOT support string formatting. Calling
--   print("Actual: %s", value) simply prints "Actual: %s" and ignores the second argument.
--   This caused misleading error messages like "Actual: %s" instead of "Actual: nil".
--   Fix: Use string.format() for all formatted output.
--
-- SPRINT-1.6A FIX: All DCE references use _G.DCE instead of local DCE.
--   Root Cause: In commands.lua, there is no local `DCE` variable defined.
--   The `DCE` references in HandleHealth() rely on _G.DCE being set, which was
--   not done until after InitializeCore() completed. With the init.lua fix,
--   _G.DCE is now set at the start of InitializeCore(), so it works.
--   Fix: Changed all `if DCE then` to `if _G.DCE then` for explicit safety.

local DiagnosticCommands = {}

--- Get commands state from RuntimeState
local function getState()
    local state = _G.DCERuntimeState
    if state and state.commands then
        return state.commands
    end
    return nil
end

--- Safe subsystem accessor - never crashes, always returns nil on failure
local function safeGet(globalName)
    local ok, result = pcall(function()
        return _G[globalName]
    end)
    if ok then return result end
    return nil
end

--- Safe function caller - never crashes, returns (false, error) on failure
local function safeCall(fn, ...)
    local args = {...}
    local ok, result = pcall(function()
        return fn(table.unpack(args))
    end)
    if not ok then
        print(string.format("^3[DCE][DIAG] Subsystem call failed: %s^0", tostring(result)))
        print(string.format("^3[DCE][DIAG]   Subsystem unavailable. Reason: %s^0", tostring(result)))
        print(string.format("^3[DCE][DIAG]   Expected: Successful execution^0"))
        print(string.format("^3[DCE][DIAG]   Actual: %s^0", tostring(result)))
        print(string.format("^3[DCE][DIAG]   Recommended investigation: Check subsystem initialization^0"))
    end
    return ok, result
end

--- Initialize diagnostic commands
function DiagnosticCommands.Init()
    local cmdState = getState()
    if cmdState then
        cmdState.initialized = true
    end

    -- Mark subsystem operational
    local gd = _G.DCEGracefulDegradation
    if gd and gd.MarkOperational then
        gd.MarkOperational("Commands")
    end
end

--- Register all diagnostic commands via FiveM chat/commands
function DiagnosticCommands.Register()
    local cmdState = getState()
    if cmdState and cmdState.registered then return end
    if not cmdState then
        DiagnosticCommands.Init()
    end

    if RegisterCommand then
        RegisterCommand("dce_diag", function(source, args, rawCommand)
            DiagnosticCommands.HandleDiag(source, args)
        end, false)

        RegisterCommand("dce_health", function(source, args, rawCommand)
            DiagnosticCommands.HandleHealth(source, args)
        end, false)

        RegisterCommand("dce_events", function(source, args, rawCommand)
            DiagnosticCommands.HandleEvents(source, args)
        end, false)

        RegisterCommand("dce_services", function(source, args, rawCommand)
            DiagnosticCommands.HandleServices(source, args)
        end, false)

        RegisterCommand("dce_boot", function(source, args, rawCommand)
            DiagnosticCommands.HandleBoot(source, args)
        end, false)

        if cmdState then cmdState.registered = true end

        print("^2[DCE][DIAG] Commands registered: /dce_diag, /dce_health, /dce_events, /dce_services, /dce_boot^0")
    else
        print("^3[DCE][DIAG] WARNING: RegisterCommand not available, diagnostic commands not registered^0")
    end
end

--- /dce_diag handler
-- Shows: loaded services, missing services, export status, EventBus status,
--        active resources, current session state, plugin count
function DiagnosticCommands.HandleDiag(source, args)
    local ok, err = pcall(function()
        print("^4=====================================^0")
        print("^4        DCE Diagnostics (/dce_diag)^0")
        print("^4=====================================^0")

        -- Services status
        print("^4--- Services ---^0")
        local validator = safeGet("DCEServiceValidator")
        if validator then
            local ok_results, results = safeCall(validator.GetResults)
            if ok_results and results then
                local services = results.services.list or {}
                local passed = 0
                local failed = 0
                for _, svc in ipairs(services) do
                    if svc.status == "INITIALIZED" or svc.status == "PRESENT" then
                        passed = passed + 1
                        print(string.format("^2  ✓ %s^0", svc.name))
                    else
                        failed = failed + 1
                        print(string.format("^1  ✗ %s [%s]^0", svc.name, svc.status))
                        if svc.error then
                            print(string.format("^1    Error: %s^0", svc.error))
                        end
                    end
                end
                print(string.format("^4  Result: %d/%d passed (%d failed)^0", passed, passed + failed, failed))
            else
                print("^3  Service validator results unavailable^0")
                print("^3  Expected: ServiceValidator.GetResults()^0")
                print(string.format("^3  Actual: %s^0", tostring(results)))
                print("^3  Recommended investigation: Check service validator initialization^0")
            end
        else
            print("^3  Service validator not available^0")
            print("^3  Expected: DCEServiceValidator global^0")
            print("^3  Actual: nil^0")
            print("^3  Recommended investigation: Check runtime/service-validator.lua loading^0")
        end

        -- Export status
        print("^4--- Exports ---^0")
        if validator then
            local ok_results, results = safeCall(validator.GetResults)
            if ok_results and results then
                local exports = results.exports.list or {}
                for _, exp in ipairs(exports) do
                    if exp.status == "READY" then
                        print(string.format("^2  ✓ %s^0", exp.name))
                    elseif exp.optional then
                        print(string.format("^3  - %s [OPTIONAL]^0", exp.name))
                    else
                        print(string.format("^1  ✗ %s [%s]^0", exp.name, exp.status))
                    end
                end
            end
        end

        -- EventBus status
        print("^4--- EventBus ---^0")
        local eventBus = safeGet("DCEEventBus")
        if eventBus then
            if eventBus.GetStats then
                local ok_stats, stats = safeCall(eventBus.GetStats)
                if ok_stats and stats then
                    print(string.format("  Events: %d", stats.totalEvents or 0))
                    print(string.format("  Handlers: %d", stats.totalHandlers or 0))
                end
            end
            if eventBus.ListEvents then
                local ok_events, events = safeCall(eventBus.ListEvents)
                if ok_events then
                    print(string.format("  Registered Events: %d", #events))
                end
            end
        else
            print("^3  EventBus not available^0")
            print("^3  Expected: DCEEventBus global^0")
            print("^3  Actual: nil^0")
        end

        -- Active resources
        print("^4--- Resources ---^0")
        if validator then
            local ok_results, results = safeCall(validator.GetResults)
            if ok_results and results then
                local resources = results.dependencies.list or {}
                for _, res in ipairs(resources) do
                    if res.status == "STARTED" then
                        print(string.format("^2  ✓ %s^0", res.name))
                    elseif res.status == "STARTING" then
                        print(string.format("^3  ~ %s [STARTING]^0", res.name))
                    elseif res.status == "MISSING" then
                        print(string.format("^3  - %s [MISSING]^0", res.name))
                    else
                        print(string.format("^1  ✗ %s [%s]^0", res.name, res.status))
                    end
                end
            end
        end

        -- Session state
        print("^4--- Control Center ---^0")
        local ccDiag = safeGet("DCECCDiagnostics")
        if ccDiag then
            local ok_state, state = safeCall(ccDiag.GetState)
            if ok_state and state then
                if state.completed then
                    print("^2  ✓ Control Center: Running^0")
                elseif state.failed then
                    local fail = ccDiag.GetFailure()
                    print(string.format("^1  ✗ Control Center: FAILED at '%s'^0", 
                        fail and fail.stage or "unknown"))
                    if fail then
                        print(string.format("^1    Reason: %s^0", fail.reason or "unknown"))
                    end
                else
                    print("^3  ○ Control Center: Not started^0")
                end
            else
                print("^3  ○ Control Center state unavailable^0")
            end
        else
            print("^3  ○ Control Center diagnostics not available^0")
        end

        -- Plugin count
        print("^4--- Plugins ---^0")
        local pluginManager = safeGet("DCEPluginManager")
        if pluginManager and pluginManager.List then
            local ok_plugins, plugins = safeCall(pluginManager.List)
            if ok_plugins and plugins then
                print(string.format("  Registered Plugins: %d", #plugins))
            else
                print("  Registered Plugins: 0")
            end
        else
            print("  Registered Plugins: 0")
        end

        -- Warning/Error summary
        print("^4--- Summary ---^0")
        local runtimeReport = safeGet("DCERuntimeReport")
        if runtimeReport then
            local ok_summary, summary = safeCall(runtimeReport.GetPlainTextSummary)
            if ok_summary and summary then
                print(summary)
            else
                print("^3  Runtime report summary unavailable^0")
            end
        end

        print("^4=====================================^0")
    end)

    if not ok then
        print("^1[DCE][DIAG] /dce_diag encountered an error:^0")
        print(string.format("^1  %s^0", tostring(err)))
        print("^3  The command continued executing. Some information may be incomplete.^0")
        print("^4=====================================^0")
    end
end

--- /dce_health handler
-- Runs every validation again while the server is running
-- Outputs PASS WARN FAIL for every subsystem
function DiagnosticCommands.HandleHealth(source, args)
    local ok, err = pcall(function()
        print("^4=====================================^0")
        print("^4      DCE Health Check (/dce_health)^0")
        print("^4=====================================^0")

        local issues = {}

        -- Check if DCE global is accessible
        local dceGlobal = _G.DCE
        if dceGlobal then
            print("^2[PASS] DCE Global^0")
        else
            print("^1[FAIL] DCE Global^0")
            table.insert(issues, "DCE global not accessible")
        end

        -- Check Logger
        local logger = safeGet("DCELogger")
        if logger then
            print("^2[PASS] Logger Service^0")
        else
            print("^1[FAIL] Logger Service^0")
            table.insert(issues, "Logger service not available")
        end

        -- Check Registry
        local registry = safeGet("DCERegistry")
        if registry then
            print("^2[PASS] Registry Service^0")
        else
            print("^1[FAIL] Registry Service^0")
            table.insert(issues, "Registry service not available")
        end

        -- Check EventBus
        local eventBus = safeGet("DCEEventBus")
        if eventBus then
            print("^2[PASS] EventBus Service^0")
            if eventBus.Emit then
                print("^2[PASS] EventBus Emit^0")
            else
                print("^1[FAIL] EventBus Emit^0")
                table.insert(issues, "EventBus Emit function not available")
            end
        else
            print("^1[FAIL] EventBus Service^0")
            table.insert(issues, "EventBus service not available")
        end

        -- Check Scheduler
        local scheduler = safeGet("DCEScheduler")
        if scheduler then
            print("^2[PASS] Scheduler Service^0")
        else
            print("^1[FAIL] Scheduler Service^0")
            table.insert(issues, "Scheduler service not available")
        end

        -- Check PluginManager
        local pluginManager = safeGet("DCEPluginManager")
        if pluginManager then
            print("^2[PASS] PluginManager Service^0")
        else
            print("^1[FAIL] PluginManager Service^0")
            table.insert(issues, "PluginManager service not available")
        end

        -- Check Config
        local configLoader = safeGet("DCEConfigLoader")
        if configLoader then
            print("^2[PASS] Config Loader^0")
        else
            print("^1[FAIL] Config Loader^0")
            table.insert(issues, "Config loader not available")
        end

        -- Check DCE API functions
        local apiChecks = {
            {"DCE.GetService", dceGlobal and dceGlobal.GetService},
            {"DCE.GetServiceOrThrow", dceGlobal and dceGlobal.GetServiceOrThrow},
            {"DCE.On", dceGlobal and dceGlobal.On},
            {"DCE.Emit", dceGlobal and dceGlobal.Emit},
            {"DCE.Schedule", dceGlobal and dceGlobal.Schedule},
            {"DCE.Log", dceGlobal and dceGlobal.Log},
            {"DCE.RegisterService", dceGlobal and dceGlobal.RegisterService},
            {"DCE.HasService", dceGlobal and dceGlobal.HasService},
            {"DCE.Once", dceGlobal and dceGlobal.Once},
            {"DCE.Off", dceGlobal and dceGlobal.Off},
        }
        for _, check in ipairs(apiChecks) do
            if check[2] then
                print(string.format("^2[PASS] %s^0", check[1]))
            else
                print(string.format("^3[WARN] %s^0", check[1]))
                table.insert(issues, check[1] .. " not available")
            end
        end

        -- Check exports
        print("^4--- Exports ---^0")
        local exportChecks = {
            "GetDCEAPI",
            "DCE_Subscribe",
        }
        for _, expName in ipairs(exportChecks) do
            local fn = _G[expName]
            if fn and type(fn) == "function" then
                print(string.format("^2[PASS] Export %s^0", expName))
            else
                print(string.format("^1[FAIL] Export %s^0", expName))
                table.insert(issues, "Export " .. expName .. " not registered")
            end
        end

        -- Print summary
        print("^4-------------------------------------^0")
        if #issues == 0 then
            print("^2[DCE][HEALTH] ALL CHECKS PASSED^0")
        else
            print(string.format("^3[DCE][HEALTH] %d issue(s) found:^0", #issues))
            for _, issue in ipairs(issues) do
                print(string.format("^3  - %s^0", issue))
            end
        end
        print("^4=====================================^0")
    end)

    if not ok then
        print("^1[DCE][DIAG] /dce_health encountered an error:^0")
        print(string.format("^1  %s^0", tostring(err)))
        print("^3  The command continued executing. Some information may be incomplete.^0")
        print("^4=====================================^0")
    end
end

--- /dce_events handler
-- Shows registered events, subscriber counts, events emitted since startup, events with zero listeners
function DiagnosticCommands.HandleEvents(source, args)
    local ok, err = pcall(function()
        print("^4=====================================^0")
        print("^4       DCE Events (/dce_events)^0")
        print("^4=====================================^0")

        local eventBus = safeGet("DCEEventBus")
        if not eventBus then
            print("^3[DCE][EVENTS] EventBus not available^0")
            print("^3  Expected: DCEEventBus global^0")
            print("^3  Actual: nil^0")
            print("^3  Recommended investigation: Check EventBus initialization^0")
            print("^4=====================================^0")
            return
        end

        -- List all registered events
        print("^4--- Registered Events ---^0")
        if eventBus.ListEvents then
            local ok_events, eventList = safeCall(eventBus.ListEvents)
            if ok_events and eventList then
                if #eventList == 0 then
                    print("^3  No events registered^0")
                else
                    for _, eventName in ipairs(eventList) do
                        local handlerCount = 0
                        if eventBus.HandlerCount then
                            local ok_count, count = safeCall(eventBus.HandlerCount, eventName)
                            if ok_count then handlerCount = count end
                        end

                        local color = handlerCount > 0 and "2" or "3"
                        print(string.format("^%s  %s (Subscribers: %d)^0", color, eventName, handlerCount))
                    end
                end
            else
                print("^3  Failed to list events^0")
            end
        end

        -- Events with zero listeners (orphaned events)
        print("^4--- Events with Zero Subscribers ---^0")
        if eventBus.ListEvents then
            local ok_events, eventList = safeCall(eventBus.ListEvents)
            if ok_events and eventList then
                local zeroCount = 0
                for _, eventName in ipairs(eventList) do
                    local handlerCount = 0
                    if eventBus.HandlerCount then
                        local ok_count, count = safeCall(eventBus.HandlerCount, eventName)
                        if ok_count then handlerCount = count end
                    end
                    if handlerCount == 0 then
                        zeroCount = zeroCount + 1
                        print(string.format("^3  %s^0", eventName))
                    end
                end
                if zeroCount == 0 then
                    print("^2  No events with zero subscribers^0")
                else
                    print(string.format("^3  Total: %d events with no subscribers^0", zeroCount))
                end
            end
        end

        -- EventBus metrics
        print("^4--- EventBus Metrics ---^0")
        if eventBus.GetMetrics then
            local ok_metrics, metrics = safeCall(eventBus.GetMetrics)
            if ok_metrics then
                print(string.format("  Total Dispatches: %d", metrics.totalDispatches or 0))
                print(string.format("  Total Errors: %d", metrics.totalErrors or 0))
                print(string.format("  Total Skipped: %d", metrics.totalSkipped or 0))

                if metrics.events and #metrics.events > 0 then
                    print("^4--- Per-Event Metrics ---^0")
                    for _, evt in ipairs(metrics.events) do
                        print(string.format("  %s: %d dispatches (avg: %.1fms, max: %.1fms)", 
                            evt.name, evt.totalDispatches, evt.avgDispatchMs or 0, evt.maxDispatchMs or 0))
                    end
                end
            end
        end

        print("^4=====================================^0")
    end)

    if not ok then
        print("^1[DCE][DIAG] /dce_events encountered an error:^0")
        print(string.format("^1  %s^0", tostring(err)))
        print("^3  The command continued executing. Some information may be incomplete.^0")
        print("^4=====================================^0")
    end
end

--- /dce_services handler
-- Displays Logger ✓ Registry ✓ EventBus ✓ Scheduler ✓ PluginManager ✓
function DiagnosticCommands.HandleServices(source, args)
    local ok, err = pcall(function()
        print("^4=====================================^0")
        print("^4      DCE Services (/dce_services)^0")
        print("^4=====================================^0")

        local validator = safeGet("DCEServiceValidator")
        if validator then
            local ok_results, results = safeCall(validator.GetResults)
            if ok_results and results then
                local services = results.services.list or {}

                for _, svc in ipairs(services) do
                    local icon = "✓"
                    local color = "2"

                    if svc.status == "INITIALIZED" then
                        icon = "✓"
                        color = "2"
                    elseif svc.status == "PRESENT" then
                        icon = "✓"
                        color = "2"
                    elseif svc.status == "MISSING" then
                        icon = "✗"
                        color = "1"
                    else
                        icon = "?"
                        color = "3"
                    end

                    print(string.format("^%s  %s %s [%s]^0", color, icon, svc.name, svc.status))
                end
            else
                print("^3  Service validator results unavailable^0")
                print("^3  Expected: ServiceValidator.GetResults()^0")
                print(string.format("^3  Actual: %s^0", tostring(results)))
                print("^3  Recommended investigation: Check service validator initialization^0")
            end
        else
            -- Fallback: direct check
            local serviceMap = {
                {"Logger", safeGet("DCELogger")},
                {"Registry", safeGet("DCERegistry")},
                {"EventBus", safeGet("DCEEventBus")},
                {"Scheduler", safeGet("DCEScheduler")},
                {"Profiler", safeGet("DCEProfiler")},
                {"Cache", safeGet("DCECache")},
                {"Pool", safeGet("DCEPool")},
                {"AlertHandler", safeGet("DCEAlertHandler")},
                {"Config", safeGet("DCEConfigLoader")},
                {"PluginManager", safeGet("DCEPluginManager")},
            }

            for _, pair in ipairs(serviceMap) do
                local name = pair[1]
                local svc = pair[2]
                if svc then
                    print(string.format("^2  ✓ %s [INITIALIZED]^0", name))
                else
                    print(string.format("^1  ✗ %s [MISSING]^0", name))
                end
            end
        end

        print("^4=====================================^0")
    end)

    if not ok then
        print("^1[DCE][DIAG] /dce_services encountered an error:^0")
        print(string.format("^1  %s^0", tostring(err)))
        print("^3  The command continued executing. Some information may be incomplete.^0")
        print("^4=====================================^0")
    end
end

--- /dce_boot handler
-- Reprints the boot timeline
function DiagnosticCommands.HandleBoot(source, args)
    local ok, err = pcall(function()
        local bootTimeline = safeGet("DCEBootTimeline")
        if bootTimeline and bootTimeline.Print then
            local ok_print, printErr = safeCall(bootTimeline.Print)
            if not ok_print then
                print("^3[DCE][BOOT] Boot timeline print failed^0")
                print("^3  Expected: BootTimeline.Print()^0")
                print(string.format("^3  Actual: %s^0", tostring(printErr)))
                print("^3  Recommended investigation: Check boot-timeline.lua initialization^0")
            end
        else
            print("^3[DCE][BOOT] Boot timeline not available^0")
            print("^3  Expected: DCEBootTimeline global with Print()^0")
            print(string.format("^3  Actual: %s^0", tostring(bootTimeline)))
            print("^3  Recommended investigation: Check runtime/boot-timeline.lua loading^0")
        end
    end)

    if not ok then
        print("^1[DCE][DIAG] /dce_boot encountered an error:^0")
        print(string.format("^1  %s^0", tostring(err)))
        print("^4=====================================^0")
    end
end

--- Check if commands are registered
function DiagnosticCommands.IsRegistered()
    local cmdState = getState()
    return cmdState and cmdState.registered or false
end

_G.DCEDiagnosticCommands = DiagnosticCommands
return DiagnosticCommands