-- DCE Configuration Framework — Sprint 1.9 Completion
-- Supports:
--   schema validation
--   defaults
--   migration
--   versioning
--   hot reload
--   runtime overrides
--   readonly values
--   environment overrides
---@diagnostic disable: undefined-global

local ConfigFramework = {}

-- ============================================================================
-- State
-- ============================================================================

local configs = {}
local schemas = {}
local defaults = {}
local overrides = {}
local readonlyKeys = {}
local migrations = {}
local currentVersion = "1.0.0"

-- ============================================================================
-- Schema Validation
-- ============================================================================

--- Validate a value against a schema type
---@param value any Value to validate
---@param schema table Schema definition
---@return boolean valid, string error
local function validateValue(value, schema)
    -- Type check
    if schema.type then
        local actualType = type(value)
        -- Allow nil for optional fields
        if value == nil then
            return schema.optional or false, schema.optional and "" or "Value is required but nil"
        end
        if actualType ~= schema.type then
            return false, string.format("Expected type %s, got %s", schema.type, actualType)
        end
    end

    -- Range check for numbers
    if schema.type == "number" and schema.range then
        if value < schema.range[1] or value > schema.range[2] then
            return false, string.format("Value %s out of range [%s, %s]",
                tostring(value), tostring(schema.range[1]), tostring(schema.range[2]))
        end
    end

    -- Enum check
    if schema.enum then
        local valid = false
        for _, option in ipairs(schema.enum) do
            if value == option then valid = true break end
        end
        if not valid then
            return false, string.format("Value '%s' not in allowed options", tostring(value))
        end
    end

    -- Pattern check for strings
    if schema.type == "string" and schema.pattern then
        if not value:match(schema.pattern) then
            return false, string.format("Value '%s' does not match pattern '%s'", value, schema.pattern)
        end
    end

    return true, ""
end

--- Validate a config table against a schema
---@param config table Config table
---@param schema table Schema definition
---@return boolean valid, table errors
function ConfigFramework.Validate(config, schema)
    local errors = {}
    if type(config) ~= "table" then
        return false, { "Config must be a table" }
    end

    for key, fieldSchema in pairs(schema) do
        local value = config[key]
        local valid, err = validateValue(value, fieldSchema)
        if not valid then
            table.insert(errors, string.format("%s: %s", key, err))
        end
    end

    return #errors == 0, errors
end

-- ============================================================================
-- Config Registration
-- ============================================================================

--- Register a configuration schema
---@param name string Config name
---@param schema table Schema definition
---@param defaultValues table Default values
function ConfigFramework.RegisterSchema(name, schema, defaultValues)
    if schemas[name] then
        error(string.format("Schema already registered: %s", name))
    end
    schemas[name] = schema
    defaults[name] = defaultValues or {}

    -- Auto-populate with defaults
    for key, value in pairs(defaultValues or {}) do
        local fieldSchema = schema[key]
        if fieldSchema and fieldSchema.readonly then
            readonlyKeys[name .. "." .. key] = true
        end
    end
end

--- Load a configuration
---@param name string Config name
---@param values table|nil Config values (nil to use defaults)
---@return table
function ConfigFramework.Load(name, values)
    local schema = schemas[name]
    if not schema then
        error(string.format("No schema registered for config: %s", name))
    end

    -- Start with defaults
    local config = {}
    for k, v in pairs(defaults[name] or {}) do
        config[k] = v
    end

    -- Apply provided values
    if values then
        for k, v in pairs(values) do
            -- Check readonly
            if not readonlyKeys[name .. "." .. k] then
                config[k] = v
            end
        end
    end

    -- Apply overrides
    if overrides[name] then
        for k, v in pairs(overrides[name]) do
            config[k] = v
        end
    end

    -- Validate
    local valid, errors = ConfigFramework.Validate(config, schema)
    if not valid then
        -- Log errors but still load (graceful degradation)
        local logger = _G.DCELogger
        if logger and logger.Warn then
            for _, err in ipairs(errors) do
                logger.Warn("Config", "Config '%s' validation: %s", name, err)
            end
        end
    end

    configs[name] = config
    return config
end

--- Get a loaded configuration
---@param name string Config name
---@return table|nil
function ConfigFramework.Get(name)
    return configs[name]
end

--- Set a runtime override
---@param name string Config name
---@param key string Config key
---@param value any Config value
function ConfigFramework.SetOverride(name, key, value)
    if readonlyKeys[name .. "." .. key] then
        local logger = _G.DCELogger
        if logger and logger.Warn then
            logger.Warn("Config", "Cannot override readonly key %s.%s", name, key)
        end
        return
    end

    overrides[name] = overrides[name] or {}
    overrides[name][key] = value

    -- Apply immediately if config is loaded
    if configs[name] then
        configs[name][key] = value
    end
end

--- Hot-reload a configuration
---@param name string Config name
---@param newValues table New config values
---@return table
function ConfigFramework.HotReload(name, newValues)
    if not schemas[name] then
        error(string.format("No schema registered for config: %s", name))
    end
    return ConfigFramework.Load(name, newValues)
end

--- Register a migration (version upgrade path)
---@param fromVersion string Source version
---@param toVersion string Target version
---@param migrateFn function Migration function (config) -> config
function ConfigFramework.RegisterMigration(fromVersion, toVersion, migrateFn)
    table.insert(migrations, {
        from = fromVersion,
        to = toVersion,
        fn = migrateFn,
    })
end

--- Migrate a configuration to the current version
---@param name string Config name
---@param config table Config to migrate
---@param fromVersion string Current version of the config
---@return table Migrated config
function ConfigFramework.Migrate(name, config, fromVersion)
    -- Find migration path
    local current = fromVersion
    local migrated = config

    -- Simple linear migration
    local migratedCount = 0
    local maxMigrations = 10

    while current ~= currentVersion and migratedCount < maxMigrations do
        local found = false
        for _, migration in ipairs(migrations) do
            if migration.from == current then
                local ok, result = pcall(migration.fn, migrated)
                if ok then
                    migrated = result
                end
                current = migration.to
                found = true
                migratedCount = migratedCount + 1
                break
            end
        end
        if not found then
            break
        end
    end

    return migrated
end

--- Apply environment overrides
--- Override pattern: DCE_CONFIG_{name}_{key}={value}
function ConfigFramework.ApplyEnvironmentOverrides()
    for envKey, envValue in pairs(os) do
        local name, key = envKey:match("^DCE_CONFIG_(.+)_(.+)$")
        if name and key then
            local lowerName = name:lower()
            local lowerKey = key:lower()
            ConfigFramework.SetOverride(lowerName, lowerKey, envValue)
        end
    end
end

--- List all registered configs
---@return table
function ConfigFramework.List()
    local list = {}
    for name, schema in pairs(schemas) do
        table.insert(list, {
            name = name,
            schemaFields = #schema,
            defaults = defaults[name] ~= nil,
            loaded = configs[name] ~= nil,
        })
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- ============================================================================
-- Init
-- ============================================================================

function ConfigFramework.Init()
    local gd = _G.DCEGracefulDegradation
    if gd and gd.MarkOperational then
        gd.MarkOperational("ConfigFramework")
    end
end

-- ============================================================================
-- Register
-- ============================================================================

_G.DCEConfigFramework = ConfigFramework
return ConfigFramework