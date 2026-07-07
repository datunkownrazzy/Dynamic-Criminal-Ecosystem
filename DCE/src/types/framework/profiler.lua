-- DCE Profiler Service Type Declarations
-- This file contains ONLY type declarations for the Profiler service.
-- No runtime logic, no business logic.

---@class DCEProfiler
--- Profiler Service: Central performance measurement and monitoring.
---@field RecordStart fun(serviceId:string):nil
---@field RecordEnd fun(serviceId:string):nil
---@field SetBudget fun(serviceId:string, budgetMs:number):nil
---@field GetMetrics fun(serviceId:string):table|nil
---@field GetAllMetrics fun():table
---@field GetHistory fun(serviceId:string, limit:number|nil):table
---@field ListServices fun():table
---@field GetStats fun():table
---@field Reset fun(serviceId:string|nil):nil
---@field Shutdown fun():nil

---@type DCEProfiler
DCEProfiler = nil