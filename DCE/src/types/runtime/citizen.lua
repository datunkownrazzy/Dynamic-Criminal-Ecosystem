-- DCE Citizen Runtime Type Declarations
-- This file contains ONLY type declarations for the FiveM Citizen runtime.
-- No runtime logic, no business logic.
-- This is the SINGLE authoritative source for Citizen type declarations.

---@class CitizenAPI
---@field CreateThread fun(callback:fun())
---@field Wait fun(ms:number)
---@field SetTimeout fun(milliseconds:number, callback:fun()):string
---@field ClearTimeout fun(id:string)
---@field SetInterval fun(interval:number, callback:fun()):string
---@field ClearInterval fun(id:string)
---@field Await fun(promise:table):...

---@type CitizenAPI
Citizen = nil

---@type fun(ms:number)
Wait = nil

---@type fun(callback:fun())
CreateThread = nil

---@type fun(milliseconds:number, callback:fun()):string
SetTimeout = nil

---@type fun(id:string)
ClearTimeout = nil

---@type fun(interval:number, callback:fun()):string
SetInterval = nil

---@type fun(id:string)
ClearInterval = nil

---@type fun(promise:table):...
Await = nil