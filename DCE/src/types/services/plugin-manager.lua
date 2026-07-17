-- DCE Plugin Manager Service Type Declarations
-- This file contains ONLY type declarations for the Plugin Manager service.
-- No runtime logic, no business logic.

--- @class IPluginManager
--- Plugin Manager: Registers and manages DCE plugins.
---@field Init fun():boolean Initialize the plugin manager
---@field Register fun(pluginId:string, manifest:table):boolean Register a plugin by ID and manifest
---@field Unregister fun(pluginId:string):boolean Unregister a plugin
---@field GetManifest fun(pluginId:string):table|nil Get plugin manifest
---@field ListPlugins fun(category:string|nil):table[] List plugins by optional category

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

---@alias DCEPluginManager IPluginManager
