-- DCE Admin UI Configuration
-- Admin dashboard and monitoring system

local Config = {}

Config.Admin = {
    -- Permission check function (server admin can override this)
    -- Should return true if the player has admin access
    PermissionCheck = function(source)
        -- Default: check if player is admin (server can override)
        if IsPlayerAceAllowed(source, "command") then
            return true
        end
        return false
    end,

    -- Dashboard settings
    Dashboard = {
        Enabled = true,
        RefreshInterval = 5000, -- 5 seconds
    },

    -- Debug console settings
    DebugConsole = {
        Enabled = true,
        MaxHistorySize = 100,
    },

    -- Performance monitoring
    PerformanceMonitor = {
        Enabled = true,
        WarningThreshold = 80, -- percentage of budget
    },

    -- Audit logging
    AuditLog = {
        Enabled = true,
        MaxEntries = 1000,
    },

    -- Runtime configuration updates (for admin panel)
    ConfigRuntime = {
        Enabled = true,
    },
}

-- Event emissions configuration
Config.Events = {
    "admin:action:executed",
    "admin:dashboard:opened",
    "admin:dashboard:closed",
    "admin:debug:command",
    "admin:config:update",
    "admin:config:changed",
}

return Config