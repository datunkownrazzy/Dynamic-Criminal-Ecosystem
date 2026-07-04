-- DCE Admin Commands
-- Chat commands for admin panel access and debugging
-- v1.0 Required for testing and admin visibility

local AdminCommands = {}
local logger

--- Initialize the commands module
function AdminCommands.Initialize(log)
    logger = log
end

--- Check if a player has admin permission
local function HasPermission(source)
    local AdminService = DCE.GetService('Admin')
    if AdminService and AdminService.HasPermission then
        return AdminService.HasPermission(source)
    end
    if Config.Admin and Config.Admin.PermissionCheck then
        return Config.Admin.PermissionCheck(source)
    end
    return false
end

--- Open admin dashboard UI
---@param source number Player server ID
local function OpenAdminDashboard(source)
    if not HasPermission(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "[DCE] ", "You do not have permission to use this command." }
        })
        return
    end

    logger("admin", "info", "Admin dashboard opened by %s", source)

    -- Emit event for audit trail
    DCE.Emit("admin:dashboard:opened", {
        eventName = "admin:dashboard:opened",
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-admin",
        payload = {
            adminId = source,
        },
    })

    -- Trigger NUI to open (will work once NUI is implemented)
    TriggerClientEvent('dce-admin:client:openDashboard', source)
    
    TriggerClientEvent('chat:addMessage', source, {
        color = { 0, 255, 0 },
        args = { "[DCE] ", "Admin dashboard opened. Use /dce config <resource> <key> <value> to modify settings." }
    })
end

--- Execute debug command
---@param source number Player server ID
---@param args table Command arguments
local function ExecuteDebug(source, args)
    if not HasPermission(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "[DCE] ", "You do not have permission to use debug commands." }
        })
        return
    end

    if not args or #args < 1 then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 255, 0 },
            args = { "[DCE] ", "Usage: /dce debug <system> [args...]" }
        })
        return
    end

    local debugSystem = args[1]
    local remainingArgs = {}
    for i = 2, #args do
        table.insert(remainingArgs, args[i])
    end

    logger("admin", "info", "Debug command from %s: %s %s", source, debugSystem, table.concat(remainingArgs, " "))

    local AdminService = DCE.GetService("Admin")
    if AdminService and AdminService.ExecuteDebugCommand then
        local result = AdminService.ExecuteDebugCommand(source, debugSystem, remainingArgs)
        
        if AdminService.LogAction then
            AdminService.LogAction(source, "debug_command", { system = debugSystem, args = remainingArgs })
        end

        if result.success then
            local outputMsg = result.message or "Command executed"
            if result.output then
                outputMsg = outputMsg .. " | Data: " .. json.encode(result.output):sub(1, 500)
            end
            TriggerClientEvent('chat:addMessage', source, {
                color = { 0, 255, 0 },
                args = { "[DCE Debug] ", outputMsg }
            })
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 0, 0 },
                args = { "[DCE Debug] ", result.message or "Command failed" }
            })
        end
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "[DCE] ", "Admin service not available." }
        })
    end
end

--- Show quick status
---@param source number Player server ID
local function ShowStatus(source)
    if not HasPermission(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "[DCE] ", "You do not have permission to use this command." }
        })
        return
    end

    local AdminService = DCE.GetService("Admin")
    if not AdminService then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "[DCE] ", "Admin service not available." }
        })
        return
    end

    local perf = AdminService.GetPerformanceMetrics()
    local integrations = AdminService.GetIntegrationHealth()
    
    TriggerClientEvent('chat:addMessage', source, {
        color = { 0, 255, 255 },
        args = { "[DCE Status] ", string.format("Tasks: %d active/%d total | Errors: %d | Dispatch: %s | Evidence: %s", 
            perf.activeTasks, perf.totalTasks, perf.totalErrors,
            integrations.dispatch.status, integrations.evidence.status) }
    })
end

--- Update config at runtime
---@param source number Player server ID
---@param args table Command arguments
local function UpdateConfig(source, args)
    if not HasPermission(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "[DCE] ", "You do not have permission to use this command." }
        })
        return
    end

    if not args or #args < 3 then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 255, 0 },
            args = { "[DCE] ", "Usage: /dce config <resource> <key> <value>" }
        })
        return
    end

    local resource = args[1]
    local key = args[2]
    local value = args[3]

    if value == "true" then
        value = true
    elseif value == "false" then
        value = false
    elseif tonumber(value) then
        value = tonumber(value)
    end

    local AdminService = DCE.GetService("Admin")
    if AdminService and AdminService.UpdateConfig then
        local success, err = AdminService.UpdateConfig(resource, key, value)
        if success then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 0, 255, 0 },
                args = { "[DCE Config] ", "Updated " .. resource .. "." .. key .. " = " .. tostring(value) }
            })
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 0, 0 },
                args = { "[DCE Config] ", err or "Failed to update config" }
            })
        end
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "[DCE] ", "Admin service not available." }
        })
    end
end

--- Register all admin commands
function AdminCommands.RegisterCommands()
    RegisterCommand('dce', function(source, args, rawCommand)
        if #args == 0 or args[1] == 'admin' then
            OpenAdminDashboard(source)
        elseif args[1] == 'debug' then
            local remainingArgs = {}
            for i = 2, #args do
                table.insert(remainingArgs, args[i])
            end
            ExecuteDebug(source, remainingArgs)
        elseif args[1] == 'status' then
            ShowStatus(source)
        elseif args[1] == 'config' then
            local remainingArgs = {}
            for i = 2, #args do
                table.insert(remainingArgs, args[i])
            end
            UpdateConfig(source, remainingArgs)
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 255, 0 },
                args = { "[DCE] ", "Usage: /dce admin | /dce debug <system> [args] | /dce status | /dce config <resource> <key> <value>" }
            })
        end
    end, true)

    TriggerEvent('chat:addSuggestion', '/dce', 'DCE Admin commands', {{ name = 'action', help = '[admin] [debug] [status] [config]' }})
    TriggerEvent('chat:addSuggestion', '/dce admin', 'Open admin dashboard')
    TriggerEvent('chat:addSuggestion', '/dce debug', 'Execute debug command', {{ name = 'system', help = 'System name (orgs, scenarios, services, tasks, events, integrations, plugins)' }})
    TriggerEvent('chat:addSuggestion', '/dce status', 'Show quick system status')
    TriggerEvent('chat:addSuggestion', '/dce config', 'Update config value', {{ name = 'resource', help = 'Resource name' }, { name = 'key', help = 'Config key' }, { name = 'value', help = 'New value (true/false/number)' }})
end

-- ============================================================================
-- NUI Server Event Handlers
-- ============================================================================

RegisterNetEvent('dce-admin:server:getDashboardData', function()
    local src = source
    if not HasPermission(src) then return end
    
    local AdminService = DCE.GetService("Admin")
    if AdminService then
        TriggerClientEvent('dce-admin:server:receiveDashboardData', src, AdminService.GetDashboardData())
    end
end)

RegisterNetEvent('dce-admin:server:getOrganizations', function()
    local src = source
    if not HasPermission(src) then return end
    
    local AdminService = DCE.GetService("Admin")
    if AdminService then
        TriggerClientEvent('dce-admin:server:receiveOrganizations', src, AdminService.GetOrganizationOverview())
    end
end)

RegisterNetEvent('dce-admin:server:getIncidents', function()
    local src = source
    if not HasPermission(src) then return end
    
    local AdminService = DCE.GetService("Admin")
    if AdminService then
        TriggerClientEvent('dce-admin:server:receiveIncidents', src, AdminService.GetActiveIncidents())
    end
end)

RegisterNetEvent('dce-admin:server:getServices', function()
    local src = source
    if not HasPermission(src) then return end
    
    local CoreRegistry = DCE.GetService("CoreRegistry")
    if CoreRegistry then
        TriggerClientEvent('dce-admin:server:receiveServices', src, CoreRegistry.ListServices())
    end
end)

RegisterNetEvent('dce-admin:server:getTasks', function()
    local src = source
    if not HasPermission(src) then return end
    
    local CoreRegistry = DCE.GetService("CoreRegistry")
    if CoreRegistry then
        TriggerClientEvent('dce-admin:server:receiveTasks', src, CoreRegistry.ListTasks())
    end
end)

RegisterNetEvent('dce-admin:server:getEvents', function()
    local src = source
    if not HasPermission(src) then return end
    
    local CoreRegistry = DCE.GetService("CoreRegistry")
    if CoreRegistry then
        TriggerClientEvent('dce-admin:server:receiveEvents', src, CoreRegistry.ListEvents())
    end
end)

RegisterNetEvent('dce-admin:server:getConfigs', function()
    local src = source
    if not HasPermission(src) then return end
    
    local AdminService = DCE.GetService("Admin")
    if AdminService then
        TriggerClientEvent('dce-admin:server:receiveConfigs', src, AdminService.GetAllConfigs())
    end
end)

RegisterNetEvent('dce-admin:server:getDebugHistory', function()
    local src = source
    if not HasPermission(src) then return end
    
    local AdminService = DCE.GetService("Admin")
    if AdminService then
        TriggerClientEvent('dce-admin:server:receiveDebugHistory', src, AdminService.GetDebugHistory())
    end
end)

RegisterNetEvent('dce-admin:server:getAuditLog', function()
    local src = source
    if not HasPermission(src) then return end
    
    local AdminService = DCE.GetService("Admin")
    if AdminService then
        TriggerClientEvent('dce-admin:server:receiveAuditLog', src, AdminService.GetAuditLog())
    end
end)

RegisterNetEvent('dce-admin:server:executeDebug', function(command, args)
    local src = source
    if not HasPermission(src) then return end
    
    local AdminService = DCE.GetService("Admin")
    if AdminService then
        local result = AdminService.ExecuteDebugCommand(src, command, args or {})
        TriggerClientEvent('dce-admin:server:receiveDebugResult', src, result)
    end
end)

RegisterNetEvent('dce-admin:server:updateConfig', function(resource, key, value)
    local src = source
    if not HasPermission(src) then return end
    
    local AdminService = DCE.GetService("Admin")
    if AdminService then
        local success, err = AdminService.UpdateConfig(resource, key, value)
        if success then
            TriggerClientEvent('chat:addMessage', src, {
                color = { 0, 255, 0 },
                args = { "[DCE] ", "Config updated: " .. resource .. "." .. key .. " = " .. tostring(value) }
            })
        else
            TriggerClientEvent('chat:addMessage', src, {
                color = { 255, 0, 0 },
                args = { "[DCE] ", err or "Failed to update config" }
            })
        end
    end
end)

_G.DCEAdminCommands = AdminCommands
