-- DCE Alert Handler Type Declarations
-- This file contains ONLY type declarations for the Alert Handler service.
-- No runtime logic, no business logic.

---@class DCEAlertHandler
--- Performance Alert Handler: Automatic alerts when performance budgets are exceeded.
---@field Init fun(log:ILogger|nil):nil
---@field Setup fun():nil
---@field Shutdown fun():nil
---@field HandleBudgetExceeded fun(self:DCEAlertHandler, payload:table):nil
---@field GetRecommendation fun(self:DCEAlertHandler, serviceId:string, actualMs:number, budgetMs:number):string
---@field GetRecentAlerts fun(self:DCEAlertHandler, limit:number|nil):table
---@field ClearAlerts fun(self:DCEAlertHandler):nil

---@type DCEAlertHandler
DCEAlertHandler = nil
