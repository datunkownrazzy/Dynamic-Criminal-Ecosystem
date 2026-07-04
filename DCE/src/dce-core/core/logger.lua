-- DCE Logger
-- Module-tagged logging with configurable levels.
-- Accessed via DCE:Log(module, level, message) or the convenience methods.

local Logger = {}
local LogLevels = { debug = 1, info = 2, warn = 3, error = 4, off = 5 }

local currentLevel
local config

--- Initialize the logger with configuration.
function Logger.Init(cfg)
    config = cfg or Config.Logger
    currentLevel = LogLevels[config.Level] or LogLevels.info
end

--- Format a log message with the configured template.
---@param module string The module tag (e.g., "core", "world", "ai")
---@param level string The log level
---@param message string The log message
---@param ... any Additional values to format into the message
function Logger.Format(module, level, message, ...)
    if ... then
        message = string.format(message, ...)
    end

    local parts = {}
    if config.Timestamps then
        table.insert(parts, os.date("%H:%M:%S"))
    end

    local levelTag = level:upper():sub(1, 1)
    table.insert(parts, "[" .. levelTag .. "]")
    table.insert(parts, "[" .. module .. "]")
    table.insert(parts, message)

    return table.concat(parts, " ")
end

--- Log a message at the specified level.
---@param module string Module identifier
---@param level string "debug" | "info" | "warn" | "error"
---@param message string Log message (supports string.format patterns)
---@param ... any Optional format arguments
function Logger.Log(module, level, message, ...)
    local minLevel = LogLevels[level]
    if not minLevel or minLevel < currentLevel then
        return
    end

    local formatted = Logger.Format(module, level, message, ...)

    if level == "error" then
        print("^1" .. formatted .. "^0")
    elseif level == "warn" then
        print("^3" .. formatted .. "^0")
    elseif level == "debug" then
        print("^5" .. formatted .. "^0")
    else
        print(formatted)
    end
end

--- Convenience methods
function Logger.Debug(module, message, ...)
    Logger.Log(module, "debug", message, ...)
end

function Logger.Info(module, message, ...)
    Logger.Log(module, "info", message, ...)
end

function Logger.Warn(module, message, ...)
    Logger.Log(module, "warn", message, ...)
end

function Logger.Error(module, message, ...)
    Logger.Log(module, "error", message, ...)
end

--- Set the log level at runtime.
---@param level string "debug" | "info" | "warn" | "error" | "off"
function Logger.SetLevel(level)
    if LogLevels[level] then
        currentLevel = LogLevels[level]
        Logger.Info("core", "Log level set to: %s", level)
    end
end

return Logger