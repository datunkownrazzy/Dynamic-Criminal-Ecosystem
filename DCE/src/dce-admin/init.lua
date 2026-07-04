-- DCE Admin UI - Resource Entry Point
-- Provides admin dashboard, monitoring, and debug console
-- v1.0 Scope: Organization overview, Active incidents, Performance metrics

local AdminService = DCEAdminService

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

local function GetDCEAPI()
    local DCEAPI = nil
    local attempts = 0
    while not DCEAPI and attempts < 50 do
        attempts = attempts + 1
        Citizen.Wait(100)
        local success, api = pcall(function()
            return exports['dce-core']:GetDCEAPI()
        end)
        if success then
            DCEAPI = api
        end
    end
    return DCEAPI
end

local function OnAdminStart()
    local DCEAPI = GetDCEAPI()
    if not DCEAPI then
        print("^1[DCE Admin] FATAL: Could not obtain DCE API from dce-core^0")
        return
    end
    _G.DCE = DCEAPI

    DCE.Log("admin", "info", "=== DCE Admin UI Starting ===")

    -- Initialize the admin service
    AdminService.Initialize(function(module, level, message, ...)
        DCE.Log(module, level, message, ...)
    end)

    -- Register the Admin service
    DCE.RegisterService("Admin", {
        HasPermission = function(source) return AdminService.HasPermission(source) end,
        GetOrganizationOverview = function() return AdminService.GetOrganizationOverview() end,
        GetActiveIncidents = function() return AdminService.GetActiveIncidents() end,
        GetPerformanceMetrics = function() return AdminService.GetPerformanceMetrics() end,
        GetIntegrationHealth = function() return AdminService.GetIntegrationHealth() end,
        ExecuteDebugCommand = function(source, command, args) return AdminService.ExecuteDebugCommand(source, command, args) end,
        GetAuditLog = function(limit) return AdminService.GetAuditLog(limit) end,
        GetDebugHistory = function(limit) return AdminService.GetDebugHistory(limit) end,
        GetDashboardData = function() return AdminService.GetDashboardData() end,
        LogAction = function(adminId, action, target) AdminService.LogAction(adminId, action, target) end,
    })

    -- Subscribe to admin action events for logging
    DCE.On("admin:action:executed", function(payload)
        local data = payload.payload or payload
        DCE.Log("admin", "debug", "Admin action: %s by %s on %s", data.action, data.adminId, tostring(data.target))
    end)

    DCE.Log("admin", "info", "=== DCE Admin UI Started ===")
end

local function OnAdminStop()
    DCE.Log("admin", "info", "=== DCE Admin UI Stopping ===")

    -- Unregister service
    DCE.UnregisterService("Admin")

    -- Shutdown service
    AdminService.Shutdown()

    DCE.Log("admin", "info", "=== DCE Admin UI Stopped ===")
end

-- ============================================================================
-- Lifecycle Hooks
-- ============================================================================

-- Ready immediately (no strong dependencies)
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