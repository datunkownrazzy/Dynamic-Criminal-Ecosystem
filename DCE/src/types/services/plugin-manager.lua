-- DCE Plugin Manager Service Type Declarations
-- This file contains ONLY type declarations for the Plugin Manager service.
-- No runtime logic, no business logic.

--- @class IPluginManager
--- Plugin Manager: Registers and manages DCE plugins.
--- All methods are COLON-defined (self is the first parameter).
---@field Register fun(self:IPluginManager, manifest:table):boolean Register a plugin manifest
---@field Unregister fun(self:IPluginManager, name:string):boolean Unregister a plugin by name
---@field Get fun(self:IPluginManager, name:string):table|nil Get plugin manifest by name
---@field List fun(self:IPluginManager):string[] List registered plugin names
---@field Count fun(self:IPluginManager):number Count registered plugins
---@field Clear fun(self:IPluginManager):nil Clear all plugin registrations

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
