-- DCE Admin Domain Type Declarations
-- This file contains ONLY type declarations for the Admin domain.
-- No runtime logic, no business logic.

--- @class IAdminService
--- Admin Service: Provides admin dashboard, monitoring, and debug console functionality.
---@field Initialize fun(self:IAdminService):nil
---@field HasPermission fun(self:IAdminService, source:number):boolean
---@field GetOrganizationOverview fun(self:IAdminService):table
---@field GetActiveIncidents fun(self:IAdminService):table
---@field GetPerformanceMetrics fun(self:IAdminService):table
---@field GetIntegrationHealth fun(self:IAdminService):table
---@field GetAllConfigs fun(self:IAdminService):table
---@field UpdateConfig fun(self:IAdminService, resource:string, key:string|table, value:any):boolean, string|nil
---@field ExecuteDebugCommand fun(self:IAdminService, source:number, command:string, args:table):table
---@field LogAction fun(self:IAdminService, adminId:number, action:string, target:string|table):nil
---@field GetAuditLog fun(self:IAdminService, limit:number|nil):table
---@field GetDebugHistory fun(self:IAdminService, limit:number|nil):table
---@field GetDashboardData fun(self:IAdminService):table
---@field GetServicesList fun(self:IAdminService):table
---@field GetTasksList fun(self:IAdminService):table
---@field GetConfig fun(self:IAdminService):table
---@field Shutdown fun(self:IAdminService):nil

--- @class IAdminConfig
--- Admin configuration structure.
---@field PermissionCheck fun(source:number):boolean Function to check admin permissions
---@field AuditLog IAuditLogConfig Audit log configuration
---@field DebugConsole IDebugConsoleConfig Debug console configuration
---@field ConfigRuntime IConfigRuntime Runtime config update configuration
---@field Dashboard IDashboardConfig Dashboard configuration

--- @class IAuditLogConfig
--- Audit log configuration.
---@field Enabled boolean Whether audit logging is enabled
---@field MaxEntries number Maximum audit log entries

--- @class IConfigRuntime
--- Runtime config update configuration.
---@field Enabled boolean Whether runtime config updates are enabled

--- @class IDebugConsoleConfig
--- Debug console configuration.
---@field Enabled boolean Whether debug console is enabled
---@field MaxHistorySize number Maximum debug history entries

--- @class IDashboardConfig
--- Dashboard configuration.
---@field Enabled boolean Whether dashboard is enabled
---@field RefreshInterval number Refresh interval in milliseconds

--- @class IAdapterDiagnostics
--- Adapter diagnostics interface for all DCE adapters.
---@field status "active"|"inactive"|"error" Current adapter state
---@field health number 0-100 Health score
---@field latency number Milliseconds
---@field queue number Pending operations
---@field errors number Total errors
---@field lastCheck number Unix timestamp
---@field capabilities string[] Supported features