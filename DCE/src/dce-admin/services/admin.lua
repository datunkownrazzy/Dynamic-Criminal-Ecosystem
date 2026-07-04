-- DCE Admin Service
-- Provides admin dashboard, monitoring, and debug console functionality
-- v1.0 Scope: Organization overview, Active incidents, Performance metrics

local AdminService = {}
local logger
local auditLog = {}
local debugHistory = {}

--- Initialize the admin service
---@param log function Logger function
function AdminService.Initialize(log)
    logger = log
end

--- Check if a source has admin permission
---@param source number Player server ID
---@return boolean
function AdminService.HasPermission(source)
    local Config = _G.Config or {}
    if not Config.Admin or not Config.Admin.PermissionCheck then
        return false
    end
    return Config.Admin.PermissionCheck(source)
end

--- Get overview of all organizations
---@return table Array of organization summaries
function AdminService.GetOrganizationOverview()
    local orgsService = DCE.GetService("Organizations")
    if not orgsService then
        return {}
    end

    local orgIds = orgsService.GetAllOrgIds()
    local overview = {}

    for _, orgId in ipairs(orgIds) do
        local state = orgsService.GetOrgState(orgId)
        local identity = orgsService.GetIdentity(orgId)
        local leadership = orgsService.GetLeadership(orgId)

        if state then
            table.insert(overview, {
                id = orgId,
                name = identity and identity.name or "Unknown",
                type = identity and identity.type or "Unknown",
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
    local scenarioEngine = DCE.GetService("ScenarioEngine")
    if not scenarioEngine then
        return {}
    end

    local scenarios = scenarioEngine.GetActiveScenarios()
    local incidents = {}

    for _, scenario in ipairs(scenarios) do
        table.insert(incidents, {
            id = scenario.id,
            organizationId = scenario.organizationId,
            activity = scenario.activity,
            regionId = scenario.regionId,
            stage = scenario.stage or "Unknown",
            state = scenario.state or "Unknown",
            startedAt = scenario.startedAt,
            priority = scenario.priority or "medium",
        })
    end

    return incidents
end

--- Get performance metrics for all systems
---@return table Performance metrics
function AdminService.GetPerformanceMetrics()
    local scheduler = DCE.GetService("CoreRegistry")
    local tasks = {}

    if scheduler then
        tasks = scheduler.ListTasks()
    end

    -- Calculate aggregate metrics
    local totalTasks = 0
    local activeTasks = 0
    local totalErrors = 0
    local taskDetails = {}

    for _, task in ipairs(tasks) do
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
    local dispatch = DCE.GetService("Dispatch")
    if dispatch then
        integrations.dispatch.status = "active"
        -- Adapter info would come from dispatch service
        integrations.dispatch.adapter = "native" -- Default
    end

    -- Check Evidence
    local evidence = DCE.GetService("Evidence")
    if evidence then
        integrations.evidence.status = "active"
        local adapter = evidence.GetAdapter()
        if adapter then
            integrations.evidence.adapter = adapter.GetName and adapter:GetName() or "custom"
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
            local export = exports[resource]
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
---@return boolean success
function AdminService.UpdateConfig(resource, key, value)
    if not Config.Admin.ConfigRuntime.Enabled then
        return false, "Runtime config updates are disabled"
    end
    
    local targetService = DCE.GetService("ConfigLoader")
    if not targetService then
        return false, "Config loader not available"
    end
    
    -- This would emit an event for the target resource to handle
    -- Resources own their own configs, so they need to respond to updates
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
    
    return true
end

--- Execute a debug command
---@param source number Player server ID
---@param command string Command name
---@param args table Command arguments
---@return table Result
function AdminService.ExecuteDebugCommand(source, command, args)
    -- Log the debug command
    DCE.Log("admin", "info", "Debug command from %s: %s %s", source, command, table.concat(args or {}, " "))

    -- Add to debug history
    table.insert(debugHistory, {
        timestamp = os.time(),
        source = source,
        command = command,
        args = args,
    })

    -- Limit history size
    if #debugHistory > Config.Admin.DebugConsole.MaxHistorySize then
        table.remove(debugHistory, 1)
    end

    -- Emit event for debug command
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

    -- Process debug command based on system
    local output = {}
    
    if command == "orgs" or command == "organizations" then
        output = AdminService.GetOrganizationOverview()
    elseif command == "incidents" or command == "scenarios" then
        output = AdminService.GetActiveIncidents()
    elseif command == "services" then
        output = { services = DCE.GetService("CoreRegistry").ListServices() }
    elseif command == "tasks" then
        output = { tasks = DCE.GetService("CoreRegistry").ListTasks() }
    elseif command == "events" then
        output = { events = DCE.GetService("CoreRegistry").ListEvents() }
    elseif command == "integrations" then
        output = AdminService.GetIntegrationHealth()
    elseif command == "plugins" then
        output = { plugins = DCE.GetService("CoreRegistry").ListPlugins() }
    elseif command == "configs" then
        output = AdminService.GetAllConfigs()
    else
        -- Try to emit for event-based handlers
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
    if not Config.Admin.AuditLog.Enabled then
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
    if #auditLog > Config.Admin.AuditLog.MaxEntries then
        table.remove(auditLog, 1)
    end

    -- Emit audit event
    DCE.Emit("admin:action:executed", {
        eventName = "admin:action:executed",
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-admin",
        payload = entry,
    })
end

--- Get audit log entries
---@param limit number|nil Maximum entries to return
---@return table Array of audit log entries
function AdminService.GetAuditLog(limit)
    limit = limit or 50
    local entries = {}

    for i = #auditLog, math.max(1, #auditLog - limit + 1), -1 do
        table.insert(entries, auditLog[i])
    end

    return entries
end

--- Get debug console history
---@param limit number|nil Maximum entries to return
---@return table Array of debug history entries
function AdminService.GetDebugHistory(limit)
    limit = limit or 50
    local entries = {}

    for i = #debugHistory, math.max(1, #debugHistory - limit + 1), -1 do
        table.insert(entries, debugHistory[i])
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

--- Get config export (for NUI/commands access)
---@return table Current config
function AdminService.GetConfig()
    return Config
end

--- Shutdown the admin service
function AdminService.Shutdown()
    if logger then
        logger("admin", "info", "Admin service shutting down")
    end
    auditLog = {}
    debugHistory = {}
end

_G.DCEAdminService = AdminService

--- Export for shared config access
_G.DCEAdminConfig = Config

-- ============================================================================
-- Service Complete
-- ============================================================================