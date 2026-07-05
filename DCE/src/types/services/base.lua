-- DCE Base Service Interface Type Declarations
-- This file contains ONLY type declarations for base service interfaces.
-- No runtime logic, no business logic.

--- @class IService
--- Base interface for all DCE services. Services are registered via DCE.RegisterService
--- and retrieved via DCE.GetService. Each service owns a specific domain area.
--- All services must implement Initialize and Shutdown lifecycle methods.
---@field Initialize fun(self:IService):nil
---@field Shutdown fun(self:IService):nil