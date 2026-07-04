-- DCE World Engine - Resource Entry Point
-- Registers the World service and schedules simulation ticks.

local WorldService = DCEWorldService

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

local function OnWorldStart()
    -- Ensure DCE is available via export from dce-core
    local DCEAPI = nil
    local attempts = 0
    while not DCEAPI and attempts < 50 do
        attempts = attempts + 1
        Citizen.Wait(100)
        local success, api = pcall(function()
            return exports['dce-core']:GetDCEAPI()
        end)
        if success then
            DCEAPI = api
        end
    end

    if not DCEAPI then
        print("^1[DCE World] FATAL: Could not obtain DCE API from dce-core^0")
        return
    end

    _G.DCE = DCEAPI

    DCE.Log("world", "info", "=== DCE World Engine Starting ===")

    -- Initialize the world engine
    WorldService.Initialize()

    -- Register the World service
    DCE.RegisterService("World", {
        GetRegionState = function(regionId) return WorldService.GetRegionState(regionId) end,
        GetAdjacentRegions = function(regionId) return WorldService.GetAdjacentRegions(regionId) end,
        GetAllRegionIds = function() return WorldService.GetAllRegionIds() end,
        GetRegionLayer = function(regionId) return WorldService.GetRegionLayer(regionId) end,
        GetTime = function() return WorldService.GetTime() end,
        GetWeather = function() return WorldService.GetWeather() end,
        GetAllRegionStates = function() return WorldService.GetAllRegionStates() end,
    })

    -- Schedule simulation ticks
    DCE.Schedule("world:layer0:tick", Config.World.Layer0Interval, function()
        WorldService.Layer0Tick()
    end, { immediate = true })

    DCE.Schedule("world:layer1:tick", Config.World.Layer1Interval, function()
        WorldService.Layer1Tick()
    end, { immediate = true })

    if Config.World.Time.Enabled then
        DCE.Schedule("world:time:tick", Config.World.Time.TickInterval, function()
            WorldService.TimeTick()
        end, { immediate = true })
    end

    if Config.World.Weather.Enabled then
        DCE.Schedule("world:weather:tick", Config.World.Weather.TickInterval, function()
            WorldService.WeatherTick()
        end, { immediate = true })
    end

    DCE.Log("world", "info", "=== DCE World Engine Started ===")
end

local function OnWorldStop()
    DCE.Log("world", "info", "=== DCE World Engine Stopping ===")

    -- Unschedule tasks
    -- Note: actual cleanup is done in WorldService.Shutdown

    WorldService.Shutdown()

    DCE.Log("world", "info", "=== DCE World Engine Stopped ===")
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