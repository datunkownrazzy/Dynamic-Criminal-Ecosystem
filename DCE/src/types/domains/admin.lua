-- DCE Admin Domain Type Declarations
-- This file contains ONLY type declarations for the Admin domain.
-- No runtime logic, no business logic.

--- @class IAdminService
--- Admin Service: Provides admin dashboard, monitoring, and debug console functionality.
---@field Initialize fun(self:IAdminService, log:ILogger):nil
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
---@field AuditLog table Audit log configuration
---@field DebugConsole table Debug console configuration

--- @class IAuditLogConfig
--- Audit log configuration.
---@field Enabled boolean Whether audit logging is enabled
---@field MaxEntries number Maximum audit log entries

--- @class IConfigRuntime
--- Runtime config update configuration.
---@field Enabled boolean Whether runtime config updates are enabled


--- @class IDebugConsoleConfig
--- Debug console configuration.
---@field MaxHistorySize number Maximum debug history entries