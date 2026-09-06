-- DCE Logger Service Type Declarations
-- This file contains ONLY type declarations for the Logger service.
-- No runtime logic, no business logic.

--- @class ILogger
--- Logger service for module-tagged logging with configurable levels.
--- All methods are COLON-defined (self is the first parameter).
---@field Log fun(self:ILogger, module:string, level:string, message:string, ...:any):nil Log with module/tag
---@field LogInfo fun(self:ILogger, module:string, message:string, ...:any):nil Info level log
---@field LogWarn fun(self:ILogger, module:string, message:string, ...:any):nil Warning level log
---@field LogError fun(self:ILogger, module:string, message:string, ...:any):nil Error level log
---@field LogDebug fun(self:ILogger, module:string, message:string, ...:any):nil Debug level log
---@field GetState fun(self:ILogger):table Get the runtime state instance

--- @class LogLevel
--- Log level enum values.
LogLevel = {
    Debug = "debug",
    Info = "info",
    Warn = "warn",
    Error = "error"
}

---@alias DCELogger ILogger
--- Type alias for the Logger service instance (DCELogger global variable)