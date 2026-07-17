-- DCE Control Center v2 - Shared Configuration
-- All runtime-tunable values with validation
-- Per ADR-0026: True Lazy Initialization

Config = Config or {}
Config.CC = Config.CC or {}

-- NUI Lifecycle
Config.CC.NUI = Config.CC.NUI or {}
Config.CC.NUI.Enabled = Config.CC.NUI.Enabled ~= false
Config.CC.NUI.TransitionTime = Config.CC.NUI.TransitionTime or 150

-- Permissions
Config.CC.Permissions = Config.CC.Permissions or {}
Config.CC.Permissions.CheckFunction = Config.CC.Permissions.CheckFunction or nil
Config.CC.Permissions.Roles = Config.CC.Permissions.Roles or {
    admin = { "group.admin", "group.superadmin", "command.dce" },
    developer = { "command.dce_dev" },
    moderator = { "command.dce_mod" },
}

-- Window Manager
Config.CC.Windows = Config.CC.Windows or {}
Config.CC.Windows.DefaultWidth = Config.CC.Windows.DefaultWidth or 600
Config.CC.Windows.DefaultHeight = Config.CC.Windows.DefaultHeight or 400
Config.CC.Windows.MinWidth = Config.CC.Windows.MinWidth or 300
Config.CC.Windows.MinHeight = Config.CC.Windows.MinHeight or 200
Config.CC.Windows.MaxWidth = Config.CC.Windows.MaxWidth or 1200
Config.CC.Windows.MaxHeight = Config.CC.Windows.MaxHeight or 800

-- Plugins
Config.CC.Plugins = Config.CC.Plugins or {}
Config.CC.Plugins.AutoDiscover = Config.CC.Plugins.AutoDiscover ~= false
Config.CC.Plugins.MaxPlugins = Config.CC.Plugins.MaxPlugins or 50

-- Keybind
Config.CC.Keybind = Config.CC.Keybind or {}
Config.CC.Keybind.Enabled = Config.CC.Keybind.Enabled ~= false
Config.CC.Keybind.Key = Config.CC.Keybind.Key or "KC_LMENU + K"

-- Theme
Config.CC.Theme = Config.CC.Theme or {}
Config.CC.Theme.Default = Config.CC.Theme.Default or "dark"

_G.Config = Config
return Config