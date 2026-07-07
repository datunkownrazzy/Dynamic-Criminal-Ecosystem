-- DCE Pool Service Type Declarations
-- This file contains ONLY type declarations for the Pool service.
-- No runtime logic, no business logic.

--- @class DCEPool
--- Pool: Object pooling for performance optimization.
---@field Init fun(logger:ILogger|nil):nil
---@field Create fun(poolName:string, createFn:function, resetFn:function, options?:table):table|nil
---@field Acquire fun(poolName:string):table|nil
---@field Return fun(poolName:string, object:table):nil
---@field InitializeDefaultPools fun():nil
---@field Shutdown fun():nil

--- @class DCEPoolObject
--- Pooled object wrapper.
---@field Acquire fun():nil