-- DCE Control Center v2 - Shared Configuration
-- All runtime-tunable values with validation

Config = Config or {}
Config.CC = Config.CC or {}

-- NUI Lifecycle Configuration
Config.CC.NUI = Config.CC.NUI or {}
Config.CC.NUI.Enabled = Config.CC.NUI.Enabled ~= false
Config.CC.NUI.DebugMode = Config.CC.NUI.DebugMode or false
Config.CC.NUI.TransitionTime = Config.CC.NUI.TransitionTime or 150

-- Permission Configuration
Config.CC.Permissions = Config.CC.Permissions or {}
Config.CC.Permissions.CheckFunction = Config.CC.Permissions.CheckFunction or nil
-- Default permission check uses ACE permissions
Config.CC.Permissions.Roles = Config.CC.Permissions.Roles or {
    admin = { "group.admin", "group.superadmin", "command.dce" },
    developer = { "command.dce_dev" },
    moderator = { "command.dce_mod" },
}

-- Window Manager Configuration
Config.CC.Windows = Config.CC.Windows or {}
Config.CC.Windows.DefaultWidth = Config.CC.Windows.DefaultWidth or 600
Config.CC.Windows.DefaultHeight = Config.CC.Windows.DefaultHeight or 400
Config.CC.Windows.MinWidth = Config.CC.Windows.MinWidth or 300
Config.CC.Windows.MinHeight = Config.CC.Windows.MinHeight or 200
Config.CC.Windows.MaxWidth = Config.CC.Windows.MaxWidth or 1200
Config.CC.Windows.MaxHeight = Config.CC.Windows.MaxHeight or 800
Config.CC.Windows.SnapThreshold = Config.CC.Windows.SnapThreshold or 20

-- Plugin System Configuration
Config.CC.Plugins = Config.CC.Plugins or {}
Config.CC.Plugins.AutoDiscover = Config.CC.Plugins.AutoDiscover ~= false
Config.CC.Plugins.MaxPlugins = Config.CC.Plugins.MaxPlugins or 50

-- Location Editor Configuration
Config.CC.LocationEditor = Config.CC.LocationEditor or {}
Config.CC.LocationEditor.EnableRaycastPlacement = Config.CC.LocationEditor.EnableRaycastPlacement ~= false
Config.CC.LocationEditor.EnableGroundSnap = Config.CC.LocationEditor.EnableGroundSnap ~= false
Config.CC.LocationEditor.EnablePreview = Config.CC.LocationEditor.EnablePreview ~= false
Config.CC.LocationEditor.UndoHistorySize = Config.CC.LocationEditor.UndoHistorySize or 50

-- Organization Editor Configuration
Config.CC.OrganizationEditor = Config.CC.OrganizationEditor or {}
Config.CC.OrganizationEditor.EnableLiveEdit = Config.CC.OrganizationEditor.EnableLiveEdit ~= false
Config.CC.OrganizationEditor.ValidationStrict = Config.CC.OrganizationEditor.ValidationStrict ~= false

-- Developer Tools Configuration
Config.CC.DevTools = Config.CC.DevTools or {}
Config.CC.DevTools.Enabled = Config.CC.DevTools.Enabled ~= false
Config.CC.DevTools.ShowEventBusMonitor = Config.CC.DevTools.ShowEventBusMonitor ~= false
Config.CC.DevTools.ShowServiceInspector = Config.CC.DevTools.ShowServiceInspector ~= false
Config.CC.DevTools.ShowPerformanceMetrics = Config.CC.DevTools.ShowPerformanceMetrics ~= false

-- Keybind Configuration
Config.CC.Keybind = Config.CC.Keybind or {}
Config.CC.Keybind.Enabled = Config.CC.Keybind.Enabled ~= false
Config.CC.Keybind.Key = Config.CC.Keybind.Key or "KC_LMENU + K"

-- Theme Configuration
Config.CC.Theme = Config.CC.Theme or {}
Config.CC.Theme.Default = Config.CC.Theme.Default or "dark"

_G.Config = Config
return Config