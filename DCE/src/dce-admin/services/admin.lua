-- DCE Admin Service
-- Provides admin dashboard, monitoring, and debug console functionality
-- v1.0 Scope: Organization overview, Active incidents, Performance metrics

local AdminService = {}
local auditLog = {}
local debugHistory = {}

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

--- Initialize the admin service (no logger injection - uses DCE.Log directly)
function AdminService.Initialize()
    -- No initialization required - service uses DCE.Log directly
end

--- Check if a source has admin permission
---@param source number Player server ID
---@return boolean
function AdminService.HasPermission(source)
    local Config = getConfig()
    if not Config.Admin or not Config.Admin.PermissionCheck then
        return false
    end
    return Config.Admin.PermissionCheck(source)
end

--- Get overview of all organizations
---@return table Array of organization summaries
function AdminService.GetOrganizationOverview()
    local orgsService = (DCE and DCE.GetService) and DCE.GetService("Organizations")
    if not orgsService then
        return {}
    end

    local orgIds = orgsService.GetAllOrgIds and orgsService.GetAllOrgIds()
    local overview = {}

    for _, orgId in ipairs(orgIds) do
        local state = orgsService.GetState and orgsService.GetState(orgId)
        local identity = orgsService.GetIdentity and orgsService.GetIdentity(orgId)
        local leadership = orgsService.GetLeadership and orgsService.GetLeadership(orgId)

        if state then
            table.insert(overview, {
                id = orgId,
                name = identity and identity.displayName or orgId,
                type = "organization", -- No "type" field in identity, use static label
                state = state.state or "Unknown",
                members = state.members or 0,
                money = state.money or 0,
                heat = state.heat or 0,
                morale = state.morale or 0,
                territories = state.territories and #state.territories or 0,
                leader = leadership and leadership.leaderId or "None",
            })
        end
    end

    return overview
end

--- Get active incidents/scenarios
---@return table Array of active scenarios
function AdminService.GetActiveIncidents()
    local scenarioEngine = (DCE and DCE.GetService) and DCE.GetService("ScenarioEngine")
    if not scenarioEngine then
        return {}
    end

    local scenarios = scenarioEngine.GetActiveScenarios and scenarioEngine.GetActiveScenarios()
    local incidents = {}

    for _, scenario in ipairs(scenarios) do
        if scenario then
            table.insert(incidents, {
                id = scenario.id,
                organizationId = scenario.organizationId,
                activity = scenario.activityId or scenario.activity,
                regionId = scenario.regionId,
                stage = scenario.currentStage or "Unknown",
                state = scenario.status or "Unknown",
                startedAt = scenario.createdAt,
                priority = scenario.priority or "medium",
            })
        end
    end

    return incidents
end

--- Get performance metrics for all systems
---@return table Performance metrics
function AdminService.GetPerformanceMetrics()
    local scheduler = (DCE and DCE.GetService) and DCE.GetService("Scheduler")
    local tasks = {}

    if scheduler then
        tasks = scheduler.ListTasks and scheduler.ListTasks() or {}
    end

    -- Calculate aggregate metrics
    local totalTasks = 0
    local activeTasks = 0
    local totalErrors = 0
    local taskDetails = {}

    for _, task in ipairs(tasks) do
        if task then
            totalTasks = totalTasks + 1
            if task.running then
                activeTasks = activeTasks + 1
            end
            totalErrors = totalErrors + (task.errorCount or 0)

            table.insert(taskDetails, {
                name = task.name,
                interval = task.interval,
                running = task.running,
                errorCount = task.errorCount or 0,
                runCount = task.runCount or 0,
                lastRunAt = task.lastRunAt,
            })
        end
    end

    return {
        totalTasks = totalTasks,
        activeTasks = activeTasks,
        totalErrors = totalErrors,
        tasks = taskDetails,
        timestamp = os.time(),
    }
end

-- Adapter diagnostics cache
local adapterDiagnostics = {}

-- Get diagnostics for a specific adapter
local function getAdapterDiagnostics(serviceName, service)
    if service and service.GetDiagnostics then
        local diag = service.GetDiagnostics()
        return {
            status = diag.status or "active",
            adapter = diag.adapter or serviceName,
            health = diag.health or 100,
            latency = diag.latency or 0,
            queue = diag.queue or 0,
            errors = diag.errors or 0
        }
    end
    return {
        status = (service and "active") or "inactive",
        adapter = serviceName,
        health = 100,
        latency = 0,
        queue = 0,
        errors = 0
    }
end

--- Get integration health status with full diagnostics
---@return table Integration status
function AdminService.GetIntegrationHealth()
    local integrations = {}

    -- Check all registered services that are adapters
    local adapterServices = {
        "Dispatch",
        "Evidence",
        "Weather",
        "MDT",
        "Economy",
        "Inventory",
        "Banking",
        "Target",
        "Fuel",
        "Housing",
        "Garage",
        "Phone"
    }

    for _, serviceName in ipairs(adapterServices) do
        local service = (DCE and DCE.GetService) and DCE.GetService(serviceName)
        if service then
            integrations[serviceName:lower()] = getAdapterDiagnostics(serviceName, service)
        else
            integrations[serviceName:lower()] = {
                status = "inactive",
                adapter = "none",
                health = 0,
                latency = 0,
                queue = 0,
                errors = 0
            }
        end
    end

    return integrations
end

--- Get all configs (read-only snapshot)
---@return table Configs by resource
function AdminService.GetAllConfigs()
    local configs = {}
    
    -- Each resource owns its own config
    -- We can request configs through their exports
    local resources = {
        "dce-admin", "dce-ai", "dce-world", "dce-events", "dce-dispatch", "dce-evidence"
    }
    
    for _, resource in ipairs(resources) do
        local success, result = pcall(function()
            local export = exports and exports[resource]
            if export and export.GetConfig then
                return export.GetConfig()
            end
            return nil
        end)
        if success and result then
            configs[resource] = result
        end
    end
    
    return configs
end

--- Update a config value at runtime
---@param resource string Resource name
---@param key string|table Config key (or path as table)
---@param value any New value
---@return boolean success, string|nil errorMessage
function AdminService.UpdateConfig(resource, key, value)
    local Config = getConfig()
    if not Config.Admin or not Config.Admin.ConfigRuntime or not Config.Admin.ConfigRuntime.Enabled then
        return false, "Runtime config updates are disabled"
    end
    
    -- Emit event for config update (resources handle their own updates)
    if DCE and DCE.Emit then
        DCE.Emit("admin:config:update", {
            eventName = "admin:config:update",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-admin",
            payload = {
                resource = resource,
                key = key,
                value = value,
            },
        })
    end
    
    return true
end

--- Execute a debug command
---@param source number Player server ID
---@param command string Command name
---@param args table Command arguments
---@return table Result
function AdminService.ExecuteDebugCommand(source, command, args)
    local Config = getConfig()
    
    -- Log the debug command
    if DCE and DCE.Log then
        DCE.Log("admin", "info", "Debug command from %s: %s %s", source, command, table.concat(args or {}, " "))
    end

    -- Add to debug history
    table.insert(debugHistory, {
        timestamp = os.time(),
        source = source,
        command = command,
        args = args,
    })

    -- Limit history size
    local maxHistory = 100
    if Config.Admin and Config.Admin.DebugConsole and Config.Admin.DebugConsole.MaxHistorySize then
        maxHistory = Config.Admin.DebugConsole.MaxHistorySize
    end
    if #debugHistory > maxHistory then
        table.remove(debugHistory, 1)
    end

    -- Emit event for debug command
    if DCE and DCE.Emit then
        DCE.Emit("admin:debug:command", {
            eventName = "admin:debug:command",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-admin",
            payload = {
                adminId = source,
                command = command,
                args = args,
            },
        })
    end

    -- Process debug command based on system
    local output = {}
    
    if command == "orgs" or command == "organizations" then
        output = AdminService.GetOrganizationOverview()
    elseif command == "incidents" or command == "scenarios" then
        output = AdminService.GetActiveIncidents()
    elseif command == "services" then
        local registry = (DCE and DCE.GetService) and DCE.GetService("CoreRegistry")
        output = registry and { services = registry.ListServices and registry.ListServices() } or { services = {} }
    elseif command == "tasks" then
        local registry = (DCE and DCE.GetService) and DCE.GetService("CoreRegistry")
        output = registry and { tasks = registry.ListTasks and registry.ListTasks() } or { tasks = {} }
    elseif command == "events" then
        local registry = (DCE and DCE.GetService) and DCE.GetService("CoreRegistry")
        output = registry and { events = registry.ListEvents and registry.ListEvents() } or { events = {} }
    elseif command == "integrations" then
        output = AdminService.GetIntegrationHealth()
    elseif command == "plugins" then
        local registry = (DCE and DCE.GetService) and DCE.GetService("CoreRegistry")
        output = registry and { plugins = registry.ListPlugins and registry.ListPlugins() } or { plugins = {} }
    elseif command == "configs" then
        output = AdminService.GetAllConfigs()
    else
        -- Try to emit for event-based handlers
        if DCE and DCE.Emit then
            DCE.Emit("admin:debug:unknown", {
                eventName = "admin:debug:unknown",
                eventVersion = 1,
                timestamp = os.time(),
                source = "dce-admin",
                payload = {
                    adminId = source,
                    command = command,
                    args = args,
                },
            })
        end
        output = { error = "Unknown debug system: " .. command }
    end

    return {
        success = true,
        message = "Debug: " .. command,
        output = output,
        timestamp = os.time(),
    }
end

--- Log an admin action for audit trail
---@param adminId number Admin player/server ID
---@param action string Action performed
---@param target string|table Target of the action
function AdminService.LogAction(adminId, action, target)
    local Config = getConfig()
    if not Config.Admin or not Config.Admin.AuditLog or not Config.Admin.AuditLog.Enabled then
        return
    end

    local entry = {
        timestamp = os.time(),
        adminId = adminId,
        action = action,
        target = type(target) == "table" and target or { id = target },
    }

    table.insert(auditLog, entry)

    -- Limit audit log size
    local maxEntries = 100
    if Config.Admin.AuditLog.MaxEntries then
        maxEntries = Config.Admin.AuditLog.MaxEntries
    end
    if #auditLog > maxEntries then
        table.remove(auditLog, 1)
    end

    -- Emit audit event
    if DCE and DCE.Emit then
        DCE.Emit("admin:action:executed", {
            eventName = "admin:action:executed",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-admin",
            payload = entry,
        })
    end
end

--- Get audit log entries
---@param limit number|nil Maximum entries to return
---@return table Array of audit log entries
function AdminService.GetAuditLog(limit)
    limit = limit or 50
    local entries = {}

    for i = math.max(1, #auditLog - limit + 1), #auditLog do
        entries[#entries + 1] = auditLog[i]
    end

    return entries
end

--- Get debug console history
---@param limit number|nil Maximum entries to return
---@return table Array of debug history entries
function AdminService.GetDebugHistory(limit)
    limit = limit or 50
    local entries = {}

    for i = math.max(1, #debugHistory - limit + 1), #debugHistory do
        entries[#entries + 1] = debugHistory[i]
    end

    return entries
end

--- Get comprehensive dashboard data
---@return table Dashboard data
function AdminService.GetDashboardData()
    return {
        organizations = AdminService.GetOrganizationOverview(),
        incidents = AdminService.GetActiveIncidents(),
        performance = AdminService.GetPerformanceMetrics(),
        integrations = AdminService.GetIntegrationHealth(),
        timestamp = os.time(),
    }
end

--- Get services list with task counts for UI
---@return table Array of service info objects
function AdminService.GetServicesList()
    local CoreRegistry = (DCE and DCE.GetService) and DCE.GetService("CoreRegistry")
    if not CoreRegistry then
        return {}
    end
    
    local serviceNames = CoreRegistry.ListServices and CoreRegistry.ListServices() or {}
    local services = {}
    
    for _, serviceName in ipairs(serviceNames) do
        if serviceName then
            table.insert(services, {
                name = serviceName,
                tasks = CoreRegistry.ListTasks and CoreRegistry.ListTasks() and #CoreRegistry.ListTasks() or 0,
                running = true, -- Services are assumed active if registered
            })
        end
    end
    
    return services
end

--- Get tasks list for UI
---@return table Array of task info objects
function AdminService.GetTasksList()
    -- Query Scheduler directly for task information
    -- Per architecture: Scheduler owns task data, not CoreRegistry
    local Scheduler = (DCE and DCE.GetService) and DCE.GetService("Scheduler")
    if not Scheduler then
        return {}
    end
    
    return Scheduler.ListTasks and Scheduler.ListTasks() or {}
end

--- Get config export (for NUI/commands access)
---@return table Current config
function AdminService.GetConfig()
    return getConfig()
end

--- Get comprehensive profiler metrics (per ADR-0015)
---@return table
function AdminService.GetProfilerMetrics()
    local Profiler = DCEProfiler
    if not Profiler then
        return { error = "Profiler not available" }
    end

    local metrics = Profiler.GetAllMetrics()
    local history = {}

    -- Get recent history for graphs
    for serviceId, _ in pairs(metrics) do
        history[serviceId] = Profiler.GetHistory(serviceId, 60) -- Last 60 entries
    end

    return {
        metrics = metrics,
        history = history,
        stats = Profiler.GetStats(),
    }
end

--- Get CPU per service breakdown
---@return table
function AdminService.GetCPUPerService()
    local Profiler = DCEProfiler
    if not Profiler then return {} end

    local metrics = Profiler.GetAllMetrics()
    local result = {}

    for serviceId, m in pairs(metrics) do
        result[serviceId] = {
            cpuMs = m.cpuMs or 0,
            memoryBytes = m.memoryBytes or 0,
            eventCount = m.eventCount or 0,
            queueDepth = m.queueDepth or 0,
            execFrequency = m.execFrequency or 0,
            lastUpdate = m.lastUpdate or 0,
        }
    end

    return result
end

--- Get cache statistics
---@return table
function AdminService.GetCacheStats()
    local Cache = DCECache
    if not Cache then return {} end

    -- This would be extended to list all caches when Cache service has that method
    return {
        -- Placeholder - Cache service would need GetListStats method
    }
end

--- Get pool statistics
---@return table
function AdminService.GetPoolStats()
    local Pool = DCEPool
    if not Pool then return {} end

    -- Return stats for known pools
    local pools = { "npc", "vehicle", "evidence", "incident", "dispatch_call" }
    local result = {}

    for _, poolName in ipairs(pools) do
        -- Pool service would need GetStats method
    end

    return result
end

--- Set performance budget for a service
---@param serviceId string
---@param budgetMs number
---@return boolean
function AdminService.SetServiceBudget(serviceId, budgetMs)
    local Profiler = DCEProfiler
    if not Profiler then return false end

    Profiler.SetBudget(serviceId, budgetMs)
    return true
end

--- Reset profiler metrics
function AdminService.ResetProfiler()
    local Profiler = DCEProfiler
    if Profiler then
        Profiler.Reset()
    end
end

--- Shutdown the admin service
function AdminService.Shutdown()
    if DCE and DCE.Log then
        DCE.Log("admin", "info", "Admin service shutting down")
    end
    auditLog = {}
    debugHistory = {}

    -- Shutdown profiler
    if DCEProfiler then
        DCEProfiler.Shutdown()
    end

    -- Shutdown cache
    if DCECache then
        DCECache.Shutdown()
    end

    -- Shutdown pool
    if DCEPool then
        DCEPool.Shutdown()
    end
end

--- Get all locations
---@return table Array of locations
function AdminService.GetAllLocations()
    local LocationManager = (DCE and DCE.GetService) and DCE.GetService("LocationManager")
    if not LocationManager then
        return {}
    end

    local locations = LocationManager.GetAllLocations and LocationManager.GetAllLocations() or {}
    return locations
end

--- Get a single location by ID
---@param id string Location ID
---@return table|nil Location data
function AdminService.GetLocation(id)
    local LocationManager = (DCE and DCE.GetService) and DCE.GetService("LocationManager")
    if not LocationManager then
        return nil
    end

    return LocationManager.GetLocation and LocationManager.GetLocation(id) or nil
end

--- Create a new location
---@param locationData table Location data
---@return table Result
function AdminService.CreateLocation(locationData)
    local LocationManager = (DCE and DCE.GetService) and DCE.GetService("LocationManager")
    if not LocationManager then
        return { success = false, error = "LocationManager service not available" }
    end

    local success, err = LocationManager.CreateLocation and LocationManager.CreateLocation(locationData) or false, "CreateLocation method missing"
    if success then
        DCE.AdminService.LogAction(0, "create_location", { id = locationData.id, type = locationData.type })
    end

    return { success = success, error = err }
end

--- Update a location
---@param id string Location ID
---@param locationData table Updated location data
---@return table Result
function AdminService.UpdateLocation(id, locationData)
    local LocationManager = (DCE and DCE.GetService) and DCE.GetService("LocationManager")
    if not LocationManager then
        return { success = false, error = "LocationManager service not available" }
    end

    local success, err = LocationManager.UpdateLocation and LocationManager.UpdateLocation(id, locationData) or false, "UpdateLocation method missing"
    if success then
        DCE.AdminService.LogAction(0, "update_location", { id = id })
    end

    return { success = success, error = err, location = locationData }
end

--- Delete a location
---@param id string Location ID
---@return table Result
function AdminService.DeleteLocation(id)
    local LocationManager = (DCE and DCE.GetService) and DCE.GetService("LocationManager")
    if not LocationManager then
        return { success = false, error = "LocationManager service not available" }
    end

    local success = LocationManager.DeleteLocation and LocationManager.DeleteLocation(id) or false
    if success then
        DCE.AdminService.LogAction(0, "delete_location", { id = id })
    end

    return { success = success }
end

--- Get all territories
---@return table Array of territories
function AdminService.GetAllTerritories()
    local LocationManager = (DCE and DCE.GetService) and DCE.GetService("LocationManager")
    if not LocationManager then
        return {}
    end

    return LocationManager.GetAllTerritories and LocationManager.GetAllTerritories() or {}
end

--- Get a single territory by ID
---@param id string Territory ID
---@return table|nil Territory data
function AdminService.GetTerritory(id)
    local LocationManager = (DCE and DCE.GetService) and DCE.GetService("LocationManager")
    if not LocationManager then
        return nil
    end

    return LocationManager.GetTerritory and LocationManager.GetTerritory(id) or nil
end

--- Create a new territory
---@param territoryData table Territory data
---@return table Result
function AdminService.CreateTerritory(territoryData)
    local LocationManager = (DCE and DCE.GetService) and DCE.GetService("LocationManager")
    if not LocationManager then
        return { success = false, error = "LocationManager service not available" }
    end

    local success, err = LocationManager.CreateTerritory and LocationManager.CreateTerritory(territoryData) or false, "CreateTerritory method missing"
    if success then
        DCE.AdminService.LogAction(0, "create_territory", { id = territoryData.id })
    end

    return { success = success, error = err }
end

--- Update a territory
---@param id string Territory ID
---@param territoryData table Updated territory data
---@return table Result
function AdminService.UpdateTerritory(id, territoryData)
    local LocationManager = (DCE and DCE.GetService) and DCE.GetService("LocationManager")
    if not LocationManager then
        return { success = false, error = "LocationManager service not available" }
    end

    local success, err = LocationManager.UpdateTerritory and LocationManager.UpdateTerritory(id, territoryData) or false, "UpdateTerritory method missing"
    if success then
        DCE.AdminService.LogAction(0, "update_territory", { id = id })
    end

    return { success = success, error = err, territory = territoryData }
end

--- Delete a territory
---@param id string Territory ID
---@return table Result
function AdminService.DeleteTerritory(id)
    local LocationManager = (DCE and DCE.GetService) and DCE.GetService("LocationManager")
    if not LocationManager then
        return { success = false, error = "LocationManager service not available" }
    end

    local success = LocationManager.DeleteTerritory and LocationManager.DeleteTerritory(id) or false
    if success then
        DCE.AdminService.LogAction(0, "delete_territory", { id = id })
    end

    return { success = success }
end

--- Get facilities for an organization
---@param orgId string Organization ID
---@return table Array of facilities
function AdminService.GetOrganizationFacilities(orgId)
    local Locations = AdminService.GetAllLocations()
    local facilities = {}

    for _, loc in ipairs(Locations) do
        if loc.organizationId == orgId then
            table.insert(facilities, {
                id = loc.id,
                type = loc.type,
                location = loc.coords and (loc.coords.x .. ", " .. loc.coords.y .. ", " .. loc.coords.z) or "N/A",
                active = loc.active,
            })
        end
    end

    return facilities
end

_G.DCEAdminService = AdminService

-- ============================================================================
-- Service Complete
