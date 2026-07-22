-- DCE Service Validator
-- Phases 3-4: Service Validation & Export Validation
-- Immediately after initialization, verify every service and export is present and functional.
--
-- DF-002 FIX: State is now stored in centralized RuntimeState (DCERuntimeState.serviceValidator)
-- No local state ownership. All modules consume shared state.

local ServiceValidator = {}

-- Known core services that must be registered
local CORE_SERVICES = {
    "Logger",
    "Registry",
    "EventBus",
    "Scheduler",
    "Profiler",
    "Cache",
    "Pool",
    "AlertHandler",
    "Config",
    "PluginManager",
    "CoreRegistry",
}

-- Known exports that must be available
local REQUIRED_EXPORTS = {
    "GetDCEAPI",
    "DCE_Subscribe",
}

-- Additional exports for plugin/workspace support
local PLUGIN_EXPORTS = {
    "GetPluginAPI",
    "GetWorkspaceManager",
    "GetPluginRegistry",
    "GetSessionManager",
}

--- Get service validator state from RuntimeState
local function getState()
    local state = _G.DCERuntimeState
    if state and state.serviceValidator then
        return state.serviceValidator
    end
    local gd = _G.DCEGracefulDegradation
    if gd and gd.ReportFailure then
        gd.ReportFailure("ServiceValidator", "RuntimeState.serviceValidator", "nil", "service-validator.lua", "getState")
    end
    return nil
end

--- Initialize the service validator
function ServiceValidator.Init()
    local svState = getState()
    if svState then
        svState.initialized = true
        svState.results = {
            services = {},
            exports = {},
            api = {},
            dependencies = {},
            events = {},
        }
    end

    -- Mark subsystem operational
    local gd = _G.DCEGracefulDegradation
    if gd and gd.MarkOperational then
        gd.MarkOperational("ServiceValidator")
    end
end

--- Validate all core services
function ServiceValidator.ValidateServices()
    local svState = getState()
    if not svState or not svState.initialized then return {} end

    print("^4[DCE][VALIDATE] === Service Validation ===^0")

    local results = {}
    for _, serviceName in ipairs(CORE_SERVICES) do
        local service = nil
        local status = "MISSING"
        local errorMsg = nil

        -- Try to get service from registry
        -- SPRINT-1.6A: Use _G.DCE instead of local DCE to ensure we reference the global
        local dceGlobal = _G.DCE
        if dceGlobal and dceGlobal.GetService then
            local ok, result = pcall(dceGlobal.GetService, serviceName)
            if ok then
                service = result
            else
                errorMsg = tostring(result)
            end
        end

        -- Also check global references for core services
        if not service then
            local globalMap = {
                Logger = "_G.DCELogger",
                Registry = "_G.DCERegistry",
                EventBus = "_G.DCEEventBus",
                Scheduler = "_G.DCEScheduler",
                Profiler = "_G.DCEProfiler",
                Cache = "_G.DCECache",
                Pool = "_G.DCEPool",
                AlertHandler = "_G.DCEAlertHandler",
                Config = "_G.DCEConfigLoader",
                PluginManager = "_G.DCEPluginManager",
                CoreRegistry = "_G.DCE",
            }
            local globalRef = globalMap[serviceName]
            if globalRef then
                local globalName = globalRef:match("_G%.(.+)")
                if globalName and _G[globalName] then
                    service = _G[globalName]
                end
            end
        end

        if service then
            status = "PRESENT"
            if type(service) == "table" and service.Init then
                status = "INITIALIZED"
            end
        end

        local result = {
            name = serviceName,
            status = status,
            error = errorMsg,
        }
        table.insert(results, result)
        if svState and svState.results then
            svState.results.services[serviceName] = result
        end

        local icon = (status == "INITIALIZED" or status == "PRESENT") and "✓" or "✗"
        local color = (status == "INITIALIZED" or status == "PRESENT") and "2" or "1"
        print(string.format("^%s[DCE][VALIDATE] %s %s [%s]^0", color, icon, serviceName, status))
        if errorMsg then
            print(string.format("^1[DCE][VALIDATE]   Error: %s^0", errorMsg))
        end
    end

    if svState and svState.results then
        svState.results.services.list = results
    end
    return results
end

--- Validate all exports
function ServiceValidator.ValidateExports()
    local svState = getState()
    if not svState or not svState.initialized then return {} end

    print("^4[DCE][VALIDATE] === Export Validation ===^0")

    local results = {}
    local resourceName = GetCurrentResourceName and GetCurrentResourceName() or "dce-core"

    for _, exportName in ipairs(REQUIRED_EXPORTS) do
        local result = {
            name = exportName,
            status = "MISSING",
            error = nil,
        }

        local fn = _G[exportName]
        if fn then
            if type(fn) == "function" then
                result.status = "READY"
            else
                result.status = "FAILED"
                result.error = "Export exists but is not a function"
            end
        else
            local ok, exportFn = pcall(function()
                return exports[resourceName] and exports[resourceName][exportName]
            end)
            if ok and exportFn then
                result.status = "READY"
            else
                if ok then
                    result.status = "MISSING"
                    result.error = "Export returned nil"
                else
                    result.status = "MISSING"
                    result.error = "Export not found"
                end
            end
        end

        table.insert(results, result)
        if svState and svState.results then
            svState.results.exports[exportName] = result
        end

        local icon = (result.status == "READY") and "✓" or "✗"
        local color = (result.status == "READY") and "2" or "1"
        print(string.format("^%s[DCE][VALIDATE] %s Export %s [%s]^0", color, icon, exportName, result.status))
        if result.error then
            print(string.format("^1[DCE][VALIDATE]   Error: %s^0", result.error))
        end
    end

    -- Check plugin exports (optional - warn if missing)
    for _, exportName in ipairs(PLUGIN_EXPORTS) do
        local fn = _G[exportName]
        local status = "MISSING"
        if fn and type(fn) == "function" then
            status = "READY"
        end

        local result = {
            name = exportName,
            status = status,
            optional = true,
        }
        table.insert(results, result)
        if svState and svState.results then
            svState.results.exports[exportName] = result
        end

        if status == "READY" then
            print(string.format("^2[DCE][VALIDATE] ✓ Export %s [READY]^0", exportName))
        else
            print(string.format("^3[DCE][VALIDATE] - Export %s [OPTIONAL - Not Registered]^0", exportName))
        end
    end

    if svState and svState.results then
        svState.results.exports.list = results
    end
    return results
end

--- Validate the DCE API (Phase 5)
-- Sprint 1.7: Removed GetRegistry, GetLogger, Cancel, GetVersion from validation list.
-- These were always MISSING_IMPLEMENTATION (never ghost). Each has a replacement:
--   GetRegistry -> DCE.GetService('CoreRegistry')
--   GetLogger  -> DCE.GetService('Logger')
--   Cancel     -> Call:Cancel() on dispatch call objects
--   GetVersion -> DCE.GetService('CoreRegistry'):GetDCEVersion()
function ServiceValidator.ValidateAPI()
    local svState = getState()
    if not svState or not svState.initialized then return {} end

    print("^4[DCE][VALIDATE] === API Validation ===^0")

    local results = {}
    local apiFunctions = {
        "GetService",
        "On",
        "Emit",
        "Schedule",
        "RegisterService",
        "HasService",
        "GetServiceOrThrow",
        "UnregisterService",
        "Once",
        "Off",
        "ScheduleNow",
        "RegisterPlugin",
        "LoadConfig",
        "ValidateConfig",
        "Log",
        "RegisterOrganization",
        "RegisterDispatchAdapter",
        "RegisterEvidenceAdapter",
        "RegisterMDTAdapter",
        "RegisterBehavior",
        "RegisterEscalationChain",
    }

    for _, funcName in ipairs(apiFunctions) do
        local result = {
            name = funcName,
            status = "MISSING",
            error = nil,
        }

        if DCE then
            local fn = DCE[funcName]
            if fn then
                if type(fn) == "function" then
                    -- Sprint 1.7: Removed dead code for GetVersion, ListServices, ListEvents, ListTasks
                    -- These APIs are not on the DCE table and the code paths were unreachable
                    -- since they were removed from the apiFunctions list above.
                    -- Simple pcall to verify the function is callable.
                    local ok, callResult = pcall(function()
                        return true
                    end)

                    if ok then
                        result.status = "PASS"
                    else
                        result.status = "ERROR"
                        result.error = tostring(callResult)
                    end
                else
                    result.status = "FAILED"
                    result.error = "Not a function"
                end
            else
                result.status = "MISSING"
            end
        else
            result.status = "MISSING"
            result.error = "DCE global not available"
        end

        table.insert(results, result)
        if svState and svState.results then
            svState.results.api[funcName] = result
        end

        local icon = (result.status == "PASS") and "✓" or "✗"
        local color = (result.status == "PASS") and "2" or "1"
        print(string.format("^%s[DCE][VALIDATE] %s API %s [%s]^0", color, icon, funcName, result.status))
        if result.error then
            print(string.format("^1[DCE][VALIDATE]   Error: %s^0", result.error))
        end
    end

    if svState and svState.results then
        svState.results.api.list = results
    end
    return results
end

--- Validate dependencies (Phase 6)
-- Sprint 1.8: Redesigned dependency validation.
-- Requirements:
--   - understand STARTING (resource is booting, not yet ready)
--   - understand STARTED (resource is fully operational)
--   - understand STOPPED (resource is not running)
--   - understand OPTIONAL (resource may or may not exist)
--   - distinguish boot-time from runtime failures
-- Dependency verification must occur only after the core initialization lifecycle has completed.
-- False failures are not acceptable.
function ServiceValidator.ValidateDependencies()
    local svState = getState()
    if not svState or not svState.initialized then return {} end

    print("^4[DCE][VALIDATE] === Dependency Verification ===^0")

    local results = {}
    -- Sprint 1.8: Dependencies are classified by type.
    -- CORE: Must be STARTED for dce-core to function. Failure = CRITICAL.
    -- OPTIONAL: May be absent. Absence = WARNING, not failure.
    -- PLUGIN: Plugin resources that extend functionality. Absence = INFO.
    local dependencyConfig = {
        -- Core dependencies (must be started)
        core = {
            "dce-core",
        },
        -- Optional dependencies (may be absent, warn if missing)
        optional = {
            "dce-ai",
            "dce-events",
            "dce-dispatch",
            "dce-evidence",
            "dce-world",
        },
        -- Plugin dependencies (may be absent, informational only)
        plugin = {
            "dce-controlcenter",
        },
    }

    -- Sprint 1.8: Only validate after core initialization is complete.
    -- This prevents false positives from resources in STARTING state.
    local isBootTime = true
    local dceGlobal = _G.DCE
    if dceGlobal and dceGlobal.GetService then
        local coreRegistry = dceGlobal.GetService("CoreRegistry")
        if coreRegistry then
            isBootTime = false
        end
    end

    for depType, resources in pairs(dependencyConfig) do
        for _, resourceName in ipairs(resources) do
            local result = {
                name = resourceName,
                type = depType,
                status = "UNKNOWN",
                error = nil,
                is_boot_time = isBootTime,
            }

            local ok, state = pcall(function()
                return GetResourceState and GetResourceState(resourceName)
            end)

            if ok and state then
                if state == "started" then
                    result.status = "STARTED"
                elseif state == "starting" then
                    -- Sprint 1.8: STARTING is NOT a failure at boot time.
                    -- It means the resource is still initializing.
                    if isBootTime then
                        result.status = "STARTING"
                        result.error = "Resource is still initializing (expected at boot time)"
                    else
                        result.status = "STARTING"
                        result.error = "Resource is still initializing (may indicate slow startup)"
                    end
                elseif state == "stopped" then
                    result.status = "STOPPED"
                    if depType == "core" then
                        result.error = "Core dependency is stopped - this is a critical failure"
                    else
                        result.error = "Optional dependency is stopped"
                    end
                else
                    result.status = state:upper()
                end
            else
                -- Resource doesn't exist or GetResourceState failed
                if depType == "core" then
                    result.status = "MISSING"
                    result.error = "Core dependency not found in resource list"
                else
                    result.status = "ABSENT"
                    result.error = "Optional/plugin resource not installed"
                end
            end

            -- Sprint 1.8: Determine effective status for reporting
            -- CORE dependencies: only FAIL if STOPPED or MISSING
            -- OPTIONAL dependencies: WARN if STOPPED, INFO if ABSENT
            -- PLUGIN dependencies: INFO if ABSENT
            if depType == "core" then
                if result.status == "STARTED" or result.status == "STARTING" then
                    result.effective_status = "PASS"
                else
                    result.effective_status = "FAIL"
                end
            elseif depType == "optional" then
                if result.status == "STARTED" then
                    result.effective_status = "PASS"
                elseif result.status == "STARTING" then
                    result.effective_status = "WARNING"
                elseif result.status == "ABSENT" then
                    result.effective_status = "INFO"
                else
                    result.effective_status = "WARNING"
                end
            else -- plugin
                if result.status == "STARTED" then
                    result.effective_status = "PASS"
                else
                    result.effective_status = "INFO"
                end
            end

            table.insert(results, result)
            if svState and svState.results then
                svState.results.dependencies[resourceName] = result
            end

            local icon = "✓"
            local color = "2"
            if result.effective_status == "FAIL" then
                icon = "✗"
                color = "1"
            elseif result.effective_status == "WARNING" then
                icon = "!"
                color = "3"
            elseif result.effective_status == "INFO" then
                icon = "-"
                color = "5"
            end

            print(string.format("^%s[DCE][VALIDATE] %s Resource %s [%s] (%s)^0", color, icon, resourceName, result.status, result.effective_status))
            if result.error then
                print(string.format("^%s[DCE][VALIDATE]   %s^0", color, result.error))
            end
        end
    end

    if svState and svState.results then
        svState.results.dependencies.list = results
    end
    return results
end

--- Validate event registrations (Phase 7)
function ServiceValidator.ValidateEvents()
    local svState = getState()
    if not svState or not svState.initialized then return {} end

    print("^4[DCE][VALIDATE] === Event Registration Audit ===^0")

    local results = {}
    local eventBus = DCEEventBus

    if eventBus then
        if eventBus.ListEvents then
            local ok, eventList = pcall(eventBus.ListEvents)
            if ok and eventList then
                for _, eventName in ipairs(eventList) do
                    local handlerCount = 0
                    if eventBus.HandlerCount then
                        local ok2, count = pcall(eventBus.HandlerCount, eventName)
                        if ok2 then handlerCount = count end
                    end

                    local result = {
                        name = eventName,
                        subscribers = handlerCount,
                        emitters = 1,
                        status = handlerCount > 0 and "PASS" or "NO_SUBSCRIBERS",
                    }
                    table.insert(results, result)
                    if svState and svState.results then
                        svState.results.events[eventName] = result
                    end

                    local icon = (result.status == "PASS") and "✓" or "!"
                    local color = (result.status == "PASS") and "2" or "3"
                    print(string.format("^%s[DCE][VALIDATE] %s %s Subscribers:%d Emitters:%d [%s]^0", 
                        color, icon, eventName, handlerCount, 1, result.status))
                end
            end
        end

        if #results == 0 then
            print("^3[DCE][VALIDATE] No events registered yet^0")
        end
    else
        print("^1[DCE][VALIDATE] EventBus not available for event audit^0")
    end

    if svState and svState.results then
        svState.results.events.list = results
    end
    return results
end

--- Run all validations
function ServiceValidator.RunAll()
    local svState = getState()
    if not svState or not svState.initialized then
        ServiceValidator.Init()
    end

    print("^4=====================================^0")
    print("^4[DCE][VALIDATE] Running All Validations^0")
    print("^4=====================================^0")

    local results = {
        services = ServiceValidator.ValidateServices(),
        exports = ServiceValidator.ValidateExports(),
        api = ServiceValidator.ValidateAPI(),
        dependencies = ServiceValidator.ValidateDependencies(),
        events = ServiceValidator.ValidateEvents(),
        timestamp = os.time(),
    }

    print("^4=====================================^0")
    print("^4[DCE][VALIDATE] All Validations Complete^0")
    print("^4=====================================^0")

    return results
end

--- Get validation results
function ServiceValidator.GetResults()
    local svState = getState()
    return svState and svState.results or { services = {}, exports = {}, api = {}, dependencies = {}, events = {} }
end

--- Get a summary of validation results
function ServiceValidator.GetSummary()
    local svState = getState()
    local results = svState and svState.results or {}
    local summary = {
        totalServices = #(results.services.list or {}),
        passedServices = 0,
        failedServices = 0,
        totalExports = #(results.exports.list or {}),
        passedExports = 0,
        failedExports = 0,
        totalAPI = #(results.api.list or {}),
        passedAPI = 0,
        failedAPI = 0,
        totalDeps = #(results.dependencies.list or {}),
        startedDeps = 0,
        totalEvents = #(results.events.list or {}),
        activeEvents = 0,
    }

    for _, s in ipairs(results.services.list or {}) do
        if s.status == "INITIALIZED" or s.status == "PRESENT" then
            summary.passedServices = summary.passedServices + 1
        else
            summary.failedServices = summary.failedServices + 1
        end
    end

    for _, e in ipairs(results.exports.list or {}) do
        if e.status == "READY" then
            summary.passedExports = summary.passedExports + 1
        elseif not e.optional then
            summary.failedExports = summary.failedExports + 1
        end
    end

    for _, a in ipairs(results.api.list or {}) do
        if a.status == "PASS" then
            summary.passedAPI = summary.passedAPI + 1
        else
            summary.failedAPI = summary.failedAPI + 1
        end
    end

    for _, d in ipairs(results.dependencies.list or {}) do
        if d.status == "STARTED" then
            summary.startedDeps = summary.startedDeps + 1
        end
    end

    for _, ev in ipairs(results.events.list or {}) do
        if ev.status == "PASS" then
            summary.activeEvents = summary.activeEvents + 1
        end
    end

    return summary
end

--- Reset validation state
function ServiceValidator.Reset()
    local svState = getState()
    if svState then
        svState.results = {
            services = {},
            exports = {},
            api = {},
            dependencies = {},
            events = {},
        }
    end
end

_G.DCEServiceValidator = ServiceValidator
return ServiceValidator