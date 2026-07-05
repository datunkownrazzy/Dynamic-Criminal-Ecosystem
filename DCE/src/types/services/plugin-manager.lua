-- DCE Plugin Manager Service Type Declarations
-- This file contains ONLY type declarations for the Plugin Manager service.
-- No runtime logic, no business logic.

--- @class IPluginManager
--- Plugin Manager: Registers and manages DCE plugins.
---@field Init fun(self:IPluginManager, logger:ILogger):nil Initialize the plugin manager
---@field Register fun(self:IPluginManager, manifest:table):boolean Register a plugin
---@field Get fun(self:IPluginManager, pluginName:string):table|nil Get plugin manifest
---@field List fun(self:IPluginManager):table[] List all plugins
---@field Clear fun(self:IPluginManager):nil Clear all registrations
---@field Has fun(self:IPluginManager, pluginName:string):boolean Check if plugin exists

--- @class PluginManifest
--- Plugin manifest structure.
---@field name string Plugin identifier
---@field version string Plugin version
---@field author string Plugin author
---@field description string Plugin description
---@field main string|nil Main entry point
---@field requires string[]|nil Required plugins
---@field provides string[]|nil Provided services
---@field conflicts string[]|nil Conflicting plugins

--- @class PluginRegistration
--- Plugin registration record.
---@field name string Plugin name
---@field manifest PluginManifest Plugin manifest
---@field registeredAt number Registration timestamp