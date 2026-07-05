-- DCE Admin Service
-- Provides admin dashboard, monitoring, and debug console functionality
-- v1.0 Scope: Organization overview, Active incidents, Performance metrics

local AdminService = {}
local logger
local auditLog = {}
local debugHistory = {}

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

--- Initialize the admin service
---@param log ILogger Logger function
function AdminService.Initialize(log)
    logger = log
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

--- Get integration health status
---@return table Integration status
function AdminService.GetIntegrationHealth()
    local integrations = {
        dispatch = { status = "unknown", adapter = "none" },
        evidence = { status = "unknown", adapter = "none" },
    }

    -- Check Dispatch
    local dispatch = (DCE and DCE.GetService) and DCE.GetService("Dispatch")
    if dispatch then
        integrations.dispatch.status = "active"
        -- Adapter info would come from dispatch service
        integrations.dispatch.adapter = "native" -- Default
    end

    -- Check Evidence
    local evidence = (DCE and DCE.GetService) and DCE.GetService("Evidence")
    if evidence then
        integrations.evidence.status = "active"
        local adapter = evidence.GetAdapter and evidence.GetAdapter()
        if adapter then
            integrations.evidence.adapter = (adapter.GetName and adapter.GetName()) or "custom"
        else
            integrations.evidence.adapter = "none"
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
                tasks = 0,
                running = true, -- Services are assumed active if registered
            })
        end
    end
    
    return services
end

--- Get tasks list for UI
---@return table Array of task info objects
function AdminService.GetTasksList()
    local CoreRegistry = (DCE and DCE.GetService) and DCE.GetService("CoreRegistry")
    if not CoreRegistry then
        return {}
    end
    
    return CoreRegistry.ListTasks and CoreRegistry.ListTasks() or {}
end

--- Get config export (for NUI/commands access)
---@return table Current config
function AdminService.GetConfig()
    return getConfig()
end

--- Shutdown the admin service
function AdminService.Shutdown()
    if logger and logger.Log then
        logger.Log("admin", "info", "Admin service shutting down")
    end
    auditLog = {}
    debugHistory = {}
end

_G.DCEAdminService = AdminService

-- ============================================================================
-- Service Complete
-- ============================================================================