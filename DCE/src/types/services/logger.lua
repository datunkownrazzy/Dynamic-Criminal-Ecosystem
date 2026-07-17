-- DCE Logger Service Type Declarations
-- This file contains ONLY type declarations for the Logger service.
-- No runtime logic, no business logic.

--- @class ILogger
--- Logger service for module-tagged logging with configurable levels.
---@field Init fun():nil Initialize the logger
---@field Log fun(module:string, level:string, message:string, ...:any):nil Log with module/tag
---@field Debug fun(module:string, message:string, ...:any):nil Debug level log
---@field Info fun(module:string, message:string, ...:any):nil Info level log
---@field Warn fun(module:string, message:string, ...:any):nil Warning level log
---@field Error fun(module:string, message:string, ...:any):nil Error level log
---@field SetLevel fun(level:string):nil Set minimum log level
---@field Format fun(module:string, level:string, message:string, ...:any):string Format a message

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