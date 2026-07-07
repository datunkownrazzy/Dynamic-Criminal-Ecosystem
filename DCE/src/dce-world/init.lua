-- DCE World Engine - Resource Entry Point
-- Registers the World service and schedules simulation ticks.

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

local function GetDCEAPI()
    local DCEAPI = nil
    local attempts = 0
    while not DCEAPI and attempts < 50 do
        attempts = attempts + 1
        Citizen.Wait(100)
        local success, api = pcall(function()
            if exports and exports['dce-core'] and exports['dce-core'].GetDCEAPI then
                return exports['dce-core']:GetDCEAPI()
            end
            return nil
        end)
        if success then
            DCEAPI = api
        end
    end
    return DCEAPI
end

local function OnWorldStart()
    -- Ensure DCE is available via export from dce-core
    local DCEAPI = GetDCEAPI()
    if not DCEAPI then
        print("^1[DCE World] FATAL: Could not obtain DCE API from dce-core^0")
        return
    end

    -- _G.DCE is owned by dce-core; use the API locally
    -- Do NOT overwrite _G.DCE to prevent race conditions

    if DCE and DCE.Log then
        DCE.Log("world", "info", "=== DCE World Engine Starting ===")
    end

    -- Initialize the world engine (DCEWorldService is set by services/world.lua at load time)
    if DCEWorldService and DCEWorldService.Initialize then
        DCEWorldService.Initialize()
    end

    -- Register the World service
    -- Defensive patterns: return nil OR actual value for service timing safety
    -- Register World service
    if DCE and DCE.RegisterService then
        DCE.RegisterService("World", {
            GetRegionState = function(regionId) return DCEWorldService and DCEWorldService.GetRegionState(regionId) end,
            GetAdjacentRegions = function(regionId) return DCEWorldService and DCEWorldService.GetAdjacentRegions(regionId) end,
            GetAllRegionIds = function() return DCEWorldService and DCEWorldService.GetAllRegionIds() end,
            GetRegionLayer = function(regionId) return DCEWorldService and DCEWorldService.GetRegionLayer(regionId) end,
            GetTime = function() return DCEWorldService and DCEWorldService.GetTime() end,
            GetWeather = function() return DCEWorldService and DCEWorldService.GetWeather() end,
            GetAllRegionStates = function() return DCEWorldService and DCEWorldService.GetAllRegionStates() end,
        })
    end
    
    -- Register Location Manager service
    -- Initialize and register the location manager
    if DCELocationManager and DCELocationManager.Init then
        DCELocationManager.Init(DCELogger)
    end
    
    if DCE and DCE.RegisterService then
        DCE.RegisterService("LocationManager", {
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
        })
    end

    -- Schedule simulation ticks
    local Config = _G.Config or {}
    local layer0Interval = 30000
    local layer1Interval = 5000
    if Config.World then
        layer0Interval = Config.World.Layer0Interval or 30000
        layer1Interval = Config.World.Layer1Interval or 5000
    end
    
    if DCE and DCE.Schedule then
        DCE.Schedule("world:layer0:tick", layer0Interval, function()
            if DCEWorldService and DCEWorldService.Layer0Tick then
                DCEWorldService.Layer0Tick()
            end
        end, { immediate = true })

        DCE.Schedule("world:layer1:tick", layer1Interval, function()
            if DCEWorldService and DCEWorldService.Layer1Tick then
                DCEWorldService.Layer1Tick()
            end
        end, { immediate = true })
    end

    if Config.World and Config.World.Time and Config.World.Time.Enabled and DCE and DCE.Schedule then
        DCE.Schedule("world:time:tick", Config.World.Time.TickInterval, function()
            if DCEWorldService and DCEWorldService.TimeTick then
                DCEWorldService.TimeTick()
            end
        end, { immediate = true })
    end

    if Config.World and Config.World.Weather and Config.World.Weather.Enabled and DCE and DCE.Schedule then
        DCE.Schedule("world:weather:tick", Config.World.Weather.TickInterval, function()
            if DCEWorldService and DCEWorldService.WeatherTick then
                DCEWorldService.WeatherTick()
            end
        end, { immediate = true })
    end

    if DCE and DCE.Log then
        DCE.Log("world", "info", "=== DCE World Engine Started ===")
    end
end

local function OnWorldStop()
    -- Safely clean up - DCE may be nil if core shut down first
    if DCE and DCE.Log then
        DCE.Log("world", "info", "=== DCE World Engine Stopping ===")
    end
    
    -- Unregister services
    if DCE and DCE.UnregisterService then
        DCE.UnregisterService("World")
        DCE.UnregisterService("LocationManager")
    end
    
    -- Shutdown services
    if DCELocationManager and DCELocationManager.Shutdown then
        DCELocationManager.Shutdown()
    end
    
    if DCEWorldService and DCEWorldService.Shutdown then
        DCEWorldService.Shutdown()
    end
    
    if DCE and DCE.Log then
        DCE.Log("world", "info", "=== DCE World Engine Stopped ===")
    end
end

-- ============================================================================
-- Lifecycle Hooks
-- ============================================================================

-- Wait for core to be ready before initializing
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == "dce-core" then
        OnWorldStart()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnWorldStop()
    end
end)