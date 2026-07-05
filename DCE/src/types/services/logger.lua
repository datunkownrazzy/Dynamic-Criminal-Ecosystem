-- DCE Logger Service Type Declarations
-- This file contains ONLY type declarations for the Logger service.
-- No runtime logic, no business logic.

--- @class ILogger
--- Logger service for module-tagged logging with configurable levels.
---@field Init fun(self:ILogger, config?:table):nil Initialize the logger
---@field Log fun(self:ILogger, module:string, level:string, message:string, ...:any):nil Log with module/tag
---@field Debug fun(self:ILogger, module:string, message:string, ...:any):nil Debug level log
---@field Info fun(self:ILogger, module:string, message:string, ...:any):nil Info level log
---@field Warn fun(self:ILogger, module:string, message:string, ...:any):nil Warning level log
---@field Error fun(self:ILogger, module:string, message:string, ...:any):nil Error level log
---@field SetLevel fun(self:ILogger, level:string):string Set minimum log level
---@field Format fun(self:ILogger, module:string, level:string, message:string, ...:any):string Format a message

--- @class LogLevel
--- Log level enum values.
LogLevel = {
    Debug = "debug",
    Info = "info",
    Warn = "warn",
    Error = "error"
}