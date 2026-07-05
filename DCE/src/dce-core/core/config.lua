-- DCE Config Loader
-- Loads and validates configuration files.
-- Every threshold, probability, and interval should be config-driven.

local ConfigLoader = {}
local loadedConfigs = {}  -- resourcePath -> config table
local logger

--- Initialize the config loader with a reference to the logger.
function ConfigLoader.Init(log)
    logger = log
end

--- Log a message through the logger if available.
local function log(level, module, message, ...)
    if logger then
        logger.Log(module, level, message, ...)
    end
end

--- Load a configuration file.
---@param path string Path to the config file (relative to resource root)
---@return table|nil The loaded config, or nil if it doesn't exist
function ConfigLoader.Load(path)
    if not path or type(path) ~= "string" then
        log("error", "core", "ConfigLoader.Load: path must be a string")
        return nil
    end

    if loadedConfigs[path] then
        return loadedConfigs[path]
    end

    local success, config = pcall(function()
        return LoadResourceFile(GetCurrentResourceName(), path)
    end)

    if not success or not config then
        log("warn", "core", "ConfigLoader: could not load '%s'", path)
        return nil
    end

    -- If it's a Lua file, compile and execute it
    if path:match("%.lua$") then
        local chunk, err = load(config, path)
        if not chunk then
            log("error", "core", "ConfigLoader: failed to compile '%s': %s", path, tostring(err))
            return nil
        end

        local ok, result = pcall(chunk)
        if not ok then
            log("error", "core", "ConfigLoader: failed to execute '%s': %s", path, tostring(result))
            return nil
        end

        -- Config files are expected to return a table or populate a global Config table
        if type(result) == "table" then
            loadedConfigs[path] = result
            return result
        end
    end

    -- If it's a JSON file, parse it
    if path:match("%.json$") then
        local ok, parsed = pcall(function()
            if json and json.decode then
                return json.decode(config)
            end
            return nil
        end)
        if not ok then
            log("error", "core", "ConfigLoader: failed to parse JSON '%s': %s", path, tostring(parsed))
            return nil
        end
        loadedConfigs[path] = parsed
        return parsed
    end

    log("warn", "core", "ConfigLoader: unsupported file format for '%s'", path)
    return nil
end

--- Merge a config table into an existing config, with validation.
---@param target table The target config to merge into
---@param source table The source config to merge from
---@param schema table|nil Optional schema defining expected fields and types
---@return boolean success
function ConfigLoader.Merge(target, source, schema)
    if not target or not source then
        log("error", "core", "ConfigLoader.Merge: target and source are required")
        return false
    end

    if schema then
        local valid, err = ConfigLoader.Validate(source, schema)
        if not valid then
            log("error", "core", "ConfigLoader.Merge: validation failed: %s", tostring(err))
            return false
        end
    end

    for key, value in pairs(source) do
        target[key] = value
    end

    return true
end

--- Validate a config table against a schema.
--- Schema format: { fieldName = { type = "string|number|boolean|table", required = true|false, min = number, max = number } }
---@param config table The config to validate
---@param schema table The schema to validate against
---@return boolean valid, string|nil errorMessage
function ConfigLoader.Validate(config, schema)
    if not config or type(config) ~= "table" then
        return false, "config must be a table"
    end

    if not schema or type(schema) ~= "table" then
        return true -- no schema = always valid
    end

    for fieldName, rules in pairs(schema) do
        local value = config[fieldName]

        if rules.required and value == nil then
            return false, string.format("missing required field '%s'", fieldName)
        end

        if value ~= nil then
            if rules.type and type(value) ~= rules.type then
                return false, string.format("field '%s' expected type '%s', got '%s'", fieldName, rules.type, type(value))
            end

            if rules.type == "number" then
                if rules.min and value < rules.min then
                    return false, string.format("field '%s' value %s is below minimum %s", fieldName, tostring(value), tostring(rules.min))
                end
                if rules.max and value > rules.max then
                    return false, string.format("field '%s' value %s is above maximum %s", fieldName, tostring(value), tostring(rules.max))
                end
            end
        end
    end

    return true
end

--- Get all loaded config paths.
---@return table Array of path strings
function ConfigLoader.ListLoaded()
    local paths = {}
    for path, _ in pairs(loadedConfigs) do
        table.insert(paths, path)
    end
    return paths
end

--- Clear all loaded configs. Called during shutdown.
function ConfigLoader.Clear()
    for path, _ in pairs(loadedConfigs) do
        loadedConfigs[path] = nil
    end
    log("info", "core", "ConfigLoader: all configs cleared")
end

_G.DCEConfigLoader = ConfigLoader
