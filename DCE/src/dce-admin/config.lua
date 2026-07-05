-- DCE Admin UI Configuration
-- Admin dashboard and monitoring system

-- Merge with global Config if it exists
Config = Config or {}

-- Ensure nested tables exist before setting values
Config.Admin = Config.Admin or {}

-- Permission check function (server admin can override this)
-- Should return true if the player has admin access
-- Note: source may be nil during resource start; check at runtime
Config.Admin.PermissionCheck = function(source)
    -- Default: check if player is admin (server can override)
    -- Uses group.admin as default - server owners can override with custom permission check
    if source == nil then
        return false
    end
    local success, result = pcall(function()
        if IsPlayerAceAllowed then
            return IsPlayerAceAllowed(source, "group.admin") or IsPlayerAceAllowed(source, "group.superadmin") or IsPlayerAceAllowed(source, "command.dce")
        end
        return false
    end)
    if success and result then
        return true
    end
    return false
end

-- Dashboard settings
Config.Admin.Dashboard = Config.Admin.Dashboard or {}
Config.Admin.Dashboard.Enabled = Config.Admin.Dashboard.Enabled or true
Config.Admin.Dashboard.RefreshInterval = Config.Admin.Dashboard.RefreshInterval or 5000 -- 5 seconds

-- Debug console settings
Config.Admin.DebugConsole = Config.Admin.DebugConsole or {}
Config.Admin.DebugConsole.Enabled = Config.Admin.DebugConsole.Enabled ~= false
Config.Admin.DebugConsole.MaxHistorySize = Config.Admin.DebugConsole.MaxHistorySize or 100

-- Performance monitoring
Config.Admin.PerformanceMonitor = Config.Admin.PerformanceMonitor or {}
Config.Admin.PerformanceMonitor.Enabled = Config.Admin.PerformanceMonitor.Enabled ~= false
Config.Admin.PerformanceMonitor.WarningThreshold = Config.Admin.PerformanceMonitor.WarningThreshold or 80 -- percentage of budget

-- Audit logging
Config.Admin.AuditLog = Config.Admin.AuditLog or {}
Config.Admin.AuditLog.Enabled = Config.Admin.AuditLog.Enabled ~= false
Config.Admin.AuditLog.MaxEntries = Config.Admin.AuditLog.MaxEntries or 1000

-- Runtime configuration updates (for admin panel)
Config.Admin.ConfigRuntime = Config.Admin.ConfigRuntime or {}
Config.Admin.ConfigRuntime.Enabled = Config.Admin.ConfigRuntime.Enabled ~= false

-- Set/update global Config
_G.Config = Config
return Config