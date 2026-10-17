-- DCE World Engine — Sprint 1.11.6 FiveM Loader Compliance
--
-- PLATFORM CONSUMER.
-- Does NOT own runtime state. Does NOT poll. Does NOT retry.
--
-- SDK acquisition is DIRECT and UNCONDITIONAL:
--   local DCE = exports['dce-core']:GetDCEAPI()
--
-- Deterministic because fxmanifest.lua declares dependencies { 'dce-core' },
-- which per the FiveM resource manifest reference REQUIRES dce-core to load
-- and fully start BEFORE this resource executes any script.
---
---@diagnostic disable: undefined-global

-- ============================================================================
-- SDK Acquisition — Direct, single call, no polling, no retries
-- ============================================================================
local DCE = exports['dce-core']:GetDCEAPI()

if not DCE then
    error("dce-world: exports['dce-core']:GetDCEAPI() returned nil. Add 'dce-core' to dependencies and ensure it starts first.")
end

local initialized = false

-- ============================================================================
-- Module Initialization
-- ============================================================================

local function OnWorldStart()
    if initialized then return end

    DCE:Log("world", "info", "=== DCE World Engine Starting ===")

    -- Initialize the world engine
    if DCEWorldService and DCEWorldService.Initialize then
        DCEWorldService.Initialize()
    end

    -- Register the World service
    DCE:RegisterService("World", {
        GetRegionState = function(regionId) return DCEWorldService and DCEWorldService.GetRegionState(regionId) end,
        GetAdjacentRegions = function(regionId) return DCEWorldService and DCEWorldService.GetAdjacentRegions(regionId) end,
        GetAllRegionIds = function() return DCEWorldService and DCEWorldService.GetAllRegionIds() end,
        GetRegionLayer = function(regionId) return DCEWorldService and DCEWorldService.GetRegionLayer(regionId) end,
        GetTime = function() return DCEWorldService and DCEWorldService.GetTime() end,
        GetWeather = function() return DCEWorldService and DCEWorldService.GetWeather() end,
        GetAllRegionStates = function() return DCEWorldService and DCEWorldService.GetAllRegionStates() end,
    })

    -- Initialize and register the location manager
    if DCELocationManager and DCELocationManager.Init then
        DCELocationManager.Init(function(module, level, message, ...)
            DCE:Log(module, level, message, ...)
        end, function(eventName, payload)
            DCE:Emit(eventName, payload)
        end)
    end

    DCE:RegisterService("LocationManager", {
        GetLocation = function(locationId) return DCELocationManager and DCELocationManager.GetLocation(locationId) end,
        GetOrganizationLocations = function(orgId) return DCELocationManager and DCELocationManager.GetOrganizationLocations(orgId) end,
        ListLocations = function(locationType) return DCELocationManager and DCELocationManager.ListLocations(locationType) end,
        ListProviders = function() return DCELocationManager and DCELocationManager.ListProviders() end,
        GetAllLocations = function() return DCELocationManager and DCELocationManager.GetAllLocations() end,
        GetTerritory = function(id) return DCELocationManager and DCELocationManager.GetLocation(id) end,
        GetAllTerritories = function() return DCELocationManager and DCELocationManager.GetAllTerritories() end,
        CreateLocation = function(data) return DCELocationManager and DCELocationManager.CreateLocation(data) end,
        UpdateLocation = function(id, data) return DCELocationManager and DCELocationManager.UpdateLocation(id, data) end,
        DeleteLocation = function(id) return DCELocationManager and DCELocationManager.DeleteLocation(id) end,
        CreateTerritory = function(data) return DCELocationManager and DCELocationManager.CreateTerritory(data) end,
        UpdateTerritory = function(id, data) return DCELocationManager and DCELocationManager.UpdateTerritory(id, data) end,
        DeleteTerritory = function(id) return DCELocationManager and DCELocationManager.DeleteTerritory(id) end,
        RegisterLocation = function(location) return DCELocationManager and DCELocationManager.RegisterLocation(location) end,
        GetLocationRevision = function(id) return DCELocationManager and DCELocationManager.GetLocationRevision(id) end,
        GetHotSnapshot = function(id) return DCELocationManager and DCELocationManager.GetHotSnapshot(id) end,
    })

    local configurationService = DCE:GetService("ConfigurationService")
    if configurationService then
        local function registerLocationTarget(targetName, locationType)
            local registered, registerError = configurationService:RegisterTarget(targetName, {
                GetSnapshot = function(id)
                    return DCELocationManager.GetHotSnapshot(id)
                end,
                GetRevision = function(id) return DCELocationManager.GetLocationRevision(id) end,
                GetCapabilities = function()
                    if locationType == "location" then
                        return {
                            state = "available",
                            actions = { "create", "update", "delete" },
                            persisted = true,
                        }
                    end
                    return {
                        state = "unavailable",
                        actions = {},
                        message = "Territory hot editing has no verified area-geometry contract in V1.",
                    }
                end,
                ValidateChange = function(id, operation, patch)
                    return DCELocationManager.ValidateHotChange(id, operation, patch, locationType)
                end,
                ApplyChange = function(id, operation, patch)
                    return DCELocationManager.ApplyHotChange(id, operation, patch, locationType)
                end,
            })
            if not registered then
                DCE:Log("world", "error", "Failed to register %s: %s", targetName, tostring(registerError))
            end
        end
        registerLocationTarget("world.location", "location")
        registerLocationTarget("world.territory", "territory")
    else
        DCE:Log("world", "warn", "ConfigurationService unavailable; world hot editing disabled")
    end

    -- Schedule simulation ticks via canonical Scheduler
    local layer0Interval = DCE:GetConfig("World.Layer0Interval", 30000)
    local layer1Interval = DCE:GetConfig("World.Layer1Interval", 5000)

    DCE:Schedule("world:layer0:tick", layer0Interval, function()
        if DCEWorldService and DCEWorldService.Layer0Tick then
            DCEWorldService.Layer0Tick()
        end
    end, { immediate = true })

    DCE:Schedule("world:layer1:tick", layer1Interval, function()
        if DCEWorldService and DCEWorldService.Layer1Tick then
            DCEWorldService.Layer1Tick()
        end
    end, { immediate = true })

    -- Time tick
    local timeEnabled = DCE:GetConfig("World.Time.Enabled", false)
    if timeEnabled then
        local timeTickInterval = DCE:GetConfig("World.Time.TickInterval", 10000)
        DCE:Schedule("world:time:tick", timeTickInterval, function()
            if DCEWorldService and DCEWorldService.TimeTick then
                DCEWorldService.TimeTick()
            end
        end, { immediate = true })
    end

    -- Weather tick
    local weatherEnabled = DCE:GetConfig("World.Weather.Enabled", false)
    if weatherEnabled then
        local weatherTickInterval = DCE:GetConfig("World.Weather.TickInterval", 60000)
        DCE:Schedule("world:weather:tick", weatherTickInterval, function()
            if DCEWorldService and DCEWorldService.WeatherTick then
                DCEWorldService.WeatherTick()
            end
        end, { immediate = true })
    end

    initialized = true
    DCE:Log("world", "info", "=== DCE World Engine Started ===")
end

local function OnWorldStop()
    if not DCE then return end

    DCE:Log("world", "info", "=== DCE World Engine Stopping ===")

    DCE:UnregisterService("World")
    DCE:UnregisterService("LocationManager")

    if DCELocationManager and DCELocationManager.Shutdown then
        DCELocationManager.Shutdown()
    end
    if DCEWorldService and DCEWorldService.Shutdown then
        DCEWorldService.Shutdown()
    end

    initialized = false
    DCE:Log("world", "info", "=== DCE World Engine Stopped ===")
end

-- ============================================================================
-- Lifecycle — Unconditional sticky subscription
-- ============================================================================
-- The EventBus replays sticky events to new subscribers.
-- This guarantees delivery even if lifecycle:running was already emitted.
DCE:On("lifecycle:running", function(payload)
    OnWorldStart()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnWorldStop()
    end
end)