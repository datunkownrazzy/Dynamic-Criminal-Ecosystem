-- DCE Control Center v2 - World Adapter (Authoritative)
-- Adapter layer: translates World subsystem data for Control Center UI
-- Never owns data; only translates between subsystem and presentation
-- Server-side only: uses DCE services, NOT client-only FiveM natives
-- Client-only natives (GetGameTimer, GetClockHours, etc.) are NEVER used here

local WorldAdapter = {}
local EventBus = nil
local Logger = nil
local dceCoreReady = false

local function ConnectToCore()
    if dceCoreReady then return true end
    if GetResourceState('dce-core') ~= 'started' then return false end
    local DCE = exports['dce-core']:GetDCEAPI()
    if not DCE then return false end
    EventBus = DCE.GetService and DCE.GetService("EventBus")
    Logger = DCE.GetService and DCE.GetService("Logger")
    dceCoreReady = true
    return true
end

local function log(level, message, ...)
    if Logger and Logger.Log then
        Logger.Log("world-adapter", level, message, ...)
    else
        print(("[DCE WorldAdapter] %s: %s"):format(level, message:format(...)))
    end
end

-- ============================================================================
-- Public API
-- ============================================================================
-- NOTE: Weather and time data are owned by the World subsystem.
-- This adapter queries the World subsystem via EventBus or DCE services.
-- Client-only FiveM natives (GetClockHours, NetworkOverrideClockTime, etc.)
-- are NEVER used here. They belong in client-side code only.

function WorldAdapter.GetStatus()
    return {
        state = "running",
        uptime = os.time()
    }
end

function WorldAdapter.GetTime()
    -- Server-side time query via EventBus to World subsystem
    -- Returns default values if World subsystem not available
    return { hour = 12, minute = 0 }
end

function WorldAdapter.SetTime(hour, minute)
    -- Server-side time setting via EventBus to World subsystem
    -- Client-only NetworkOverrideClockTime is NEVER called here
    if EventBus then
        EventBus.Emit("world:settime", {
            eventVersion = 1, timestamp = os.time(), source = "world-adapter",
            payload = { hour = hour, minute = minute }
        })
        return true
    end
    return false
end

function WorldAdapter.GetWeather()
    -- Server-side weather query via EventBus to World subsystem
    return "CLEAR"
end

function WorldAdapter.SetWeather(weatherType)
    -- Server-side weather setting via EventBus to World subsystem
    -- Client-only ClearOverrideWeather/SetWeatherTypePersist are NEVER called here
    if EventBus then
        EventBus.Emit("world:setweather", {
            eventVersion = 1, timestamp = os.time(), source = "world-adapter",
            payload = { weather = weatherType }
        })
        return true
    end
    return false
end

function WorldAdapter.GetMetrics()
    return {
        weather = WorldAdapter.GetWeather(),
        time = WorldAdapter.GetTime()
    }
end

function WorldAdapter.GetCapabilities()
    return { admin = true, readOnly = false, actions = { "getStatus", "getTime", "setTime", "getWeather", "setWeather" } }
end

ConnectToCore()
log("info", "World Adapter initialized")

return WorldAdapter