-- DCE Admin UI - Resource Entry Point
-- Provides admin dashboard, monitoring, and debug console
-- v1.0 Scope: Organization overview, Active incidents, Performance metrics
-- Uses event-driven initialization per Architecture rules

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

local function OnAdminStart()
    -- Wait for DCE to be available via event or direct check
    if not DCE or not DCE.RegisterService then
        -- Try to get DCE from core export
        if exports and exports['dce-core'] and exports['dce-core'].GetDCEAPI then
            local DCEAPI = exports['dce-core']:GetDCEAPI()
            if DCEAPI then
                -- NOTE: DCEAPI is a FiveM proxy table; function members are
                -- proxy tables with __call, not real functions (see ADR-0020).
                -- This is fine for DCE.Log, DCE.Emit, DCE.RegisterService which
                -- only take string/table arguments. Do NOT call DCE.On() through
                -- this proxy — use exports['dce-core']:DCE_Subscribe() instead.
                _G.DCE = DCEAPI
            end
        end
    end

    if not DCE then
        print("^1[DCE Admin] FATAL: Could not obtain DCE API from dce-core^0")
        return
    end

    if DCE and DCE.Log then
        DCE.Log("admin", "info", "=== DCE Admin UI Starting ===")
    end

    -- Initialize the admin service (DCEAdminService is set by services/admin.lua at load time)
    if DCEAdminService and DCEAdminService.Initialize then
        DCEAdminService.Initialize()
    end

    -- Register the Admin service with DCE
    if DCE and DCE.RegisterService then
        DCE.RegisterService("Admin", {
            HasPermission = function(source)
                if DCEAdminService and DCEAdminService.HasPermission then
                    return DCEAdminService.HasPermission(source)
                end
                return false
            end,
            GetOrganizationOverview = function()
                if DCEAdminService and DCEAdminService.GetOrganizationOverview then
                    return DCEAdminService.GetOrganizationOverview()
                end
                return {}
            end,
            GetActiveIncidents = function()
                if DCEAdminService and DCEAdminService.GetActiveIncidents then
                    return DCEAdminService.GetActiveIncidents()
                end
                return {}
            end,
            GetPerformanceMetrics = function()
                if DCEAdminService and DCEAdminService.GetPerformanceMetrics then
                    return DCEAdminService.GetPerformanceMetrics()
                end
                return {}
            end,
            GetIntegrationHealth = function()
                if DCEAdminService and DCEAdminService.GetIntegrationHealth then
                    return DCEAdminService.GetIntegrationHealth()
                end
                return {}
            end,
            ExecuteDebugCommand = function(source, command, args)
                if DCEAdminService and DCEAdminService.ExecuteDebugCommand then
                    return DCEAdminService.ExecuteDebugCommand(source, command, args)
                end
                return {}
            end,
            GetAuditLog = function(limit)
                if DCEAdminService and DCEAdminService.GetAuditLog then
                    return DCEAdminService.GetAuditLog(limit)
                end
                return {}
            end,
            GetDebugHistory = function(limit)
                if DCEAdminService and DCEAdminService.GetDebugHistory then
                    return DCEAdminService.GetDebugHistory(limit)
                end
                return {}
            end,
            GetDashboardData = function()
                if DCEAdminService and DCEAdminService.GetDashboardData then
                    return DCEAdminService.GetDashboardData()
                end
                return {}
            end,
            LogAction = function(adminId, action, target)
                if DCEAdminService and DCEAdminService.LogAction then
                    DCEAdminService.LogAction(adminId, action, target)
                end
            end,
            GetAllConfigs = function()
                if DCEAdminService and DCEAdminService.GetAllConfigs then
                    return DCEAdminService.GetAllConfigs()
                end
                return {}
            end,
            UpdateConfig = function(resource, key, value)
                if DCEAdminService and DCEAdminService.UpdateConfig then
                    return DCEAdminService.UpdateConfig(resource, key, value)
                end
                return false, "Admin service not available"
            end,
            GetConfig = function()
                if DCEAdminService and DCEAdminService.GetConfig then
                    return DCEAdminService.GetConfig()
                end
                return {}
            end,
            GetServicesList = function()
                if DCEAdminService and DCEAdminService.GetServicesList then
                    return DCEAdminService.GetServicesList()
                end
                return {}
            end,
             GetTasksList = function()
                 if DCEAdminService and DCEAdminService.GetTasksList then
                     return DCEAdminService.GetTasksList()
                 end
                 return {}
             end,
             -- World Editor endpoints
             GetAllLocations = function()
                 if DCEAdminService and DCEAdminService.GetAllLocations then
                     return DCEAdminService.GetAllLocations()
                 end
                 return {}
             end,
             GetLocation = function(id)
                 if DCEAdminService and DCEAdminService.GetLocation then
                     return DCEAdminService.GetLocation(id)
                 end
                 return nil
             end,
             CreateLocation = function(locationData)
                 if DCEAdminService and DCEAdminService.CreateLocation then
                     return DCEAdminService.CreateLocation(locationData)
                 end
                 return { success = false, error = "Admin service not available" }
             end,
             UpdateLocation = function(id, locationData)
                 if DCEAdminService and DCEAdminService.UpdateLocation then
                     return DCEAdminService.UpdateLocation(id, locationData)
                 end
                 return { success = false, error = "Admin service not available" }
             end,
             DeleteLocation = function(id)
                 if DCEAdminService and DCEAdminService.DeleteLocation then
                     return DCEAdminService.DeleteLocation(id)
                 end
                 return { success = false, error = "Admin service not available" }
             end,
             GetAllTerritories = function()
                 if DCEAdminService and DCEAdminService.GetAllTerritories then
                     return DCEAdminService.GetAllTerritories()
                 end
                 return {}
             end,
             GetTerritory = function(id)
                 if DCEAdminService and DCEAdminService.GetTerritory then
                     return DCEAdminService.GetTerritory(id)
                 end
                 return nil
             end,
             CreateTerritory = function(territoryData)
                 if DCEAdminService and DCEAdminService.CreateTerritory then
                     return DCEAdminService.CreateTerritory(territoryData)
                 end
                 return { success = false, error = "Admin service not available" }
             end,
             UpdateTerritory = function(id, territoryData)
                 if DCEAdminService and DCEAdminService.UpdateTerritory then
                     return DCEAdminService.UpdateTerritory(id, territoryData)
                 end
                 return { success = false, error = "Admin service not available" }
             end,
             DeleteTerritory = function(id)
                 if DCEAdminService and DCEAdminService.DeleteTerritory then
                     return DCEAdminService.DeleteTerritory(id)
                 end
                 return { success = false, error = "Admin service not available" }
             end,
             GetOrganizationFacilities = function(orgId)
                 if DCEAdminService and DCEAdminService.GetOrganizationFacilities then
                     return DCEAdminService.GetOrganizationFacilities(orgId)
                 end
                 return {}
             end,
         })
    end

    -- Initialize commands after service registration
    if DCEAdminCommands and DCEAdminCommands.RegisterCommands then
        DCEAdminCommands.RegisterCommands()
    end
    if DCE and DCE.Log then
        DCE.Log("admin", "info", "Admin commands registered")
    end

    -- Subscribe to admin action events via FiveM event bridge
    -- ADR-0020: DCE.On cannot be called cross-resource because FiveM marshals
    -- function arguments into proxy tables. Instead, we:
    -- 1. Register a FiveM event handler (stays a real function in our VM)
    -- 2. Use the DCE_Subscribe export to bridge the DCE event to our FiveM event
    AddEventHandler("dce-admin:on:action:executed", function(payload)
        if DCE and DCE.Log then
            local data = payload and (payload.payload or payload)
            if data then
                DCE.Log("admin", "debug", "Admin action: %s by %s on %s", data.action, data.adminId, tostring(data.target))
            end
        end
    end)
    
    -- Bridge: subscribe the DCE event to our FiveM event handler
    -- No function reference crosses the resource boundary
    if exports and exports['dce-core'] and exports['dce-core'].DCE_Subscribe then
        exports['dce-core']:DCE_Subscribe("admin:action:executed", "dce-admin:on:action:executed")
        if DCE and DCE.Log then
            DCE.Log("admin", "info", "Subscribed to admin:action:executed via event bridge")
        end
    else
        print("^1[DCE Admin] WARNING: DCE_Subscribe export not available^0")
    end

    if DCE and DCE.Log then
        DCE.Log("admin", "info", "=== DCE Admin UI Started ===")
    end
end

local function OnAdminStop()
    -- Safely clean up - DCE may be nil if core shut down first
    if DCE and DCE.Log then
        DCE.Log("admin", "info", "=== DCE Admin UI Stopping ===")
    end

    if DCE and DCE.UnregisterService then
        DCE.UnregisterService("Admin")
    end

    if DCEAdminService and DCEAdminService.Shutdown then
        DCEAdminService.Shutdown()
    end

    if DCE and DCE.Log then
        DCE.Log("admin", "info", "=== DCE Admin UI Stopped ===")
    end
end

-- ============================================================================
-- Lifecycle Hooks
-- ============================================================================

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnAdminStart()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnAdminStop()
    end
end)

-- ============================================================================
-- Export Functions
-- ============================================================================

--- Get the config table for exports
function GetConfig()
    return _G.Config or {}
end