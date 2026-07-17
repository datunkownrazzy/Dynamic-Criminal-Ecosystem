-- DCE Control Center v2 - Browser Manager (Authoritative)
-- Owns browser lifecycle operations only
-- FiveM creates/destroys the actual CEF browser; this manages the abstraction
-- Registered with DCE Core via DCE:RegisterService() - never globals

local BrowserManager = {}
local DCE = nil
local dceCoreReady = false

local function ConnectToCore()
    if dceCoreReady then return true end
    if GetResourceState('dce-core') ~= 'started' then return false end
    DCE = exports['dce-core']:GetDCEAPI()
    dceCoreReady = true
    return true
end

function BrowserManager.Activate()
    SendNUIMessage({ action = "bootstrap:ready", data = { state = "dormant" } })
    return true
end

function BrowserManager.Notify(action, data)
    if SendNUIMessage then
        SendNUIMessage({ action = action, data = data or {} })
    end
    return true
end

function BrowserManager.EnsureCleanState()
    SendNUIMessage({ action = "lifecycle:cleanup", data = {} })
    return true
end

AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    local attempts = 0
    while not ConnectToCore() and attempts < 50 do
        Wait(100); attempts = attempts + 1
    end
    if DCE and DCE.RegisterService then
        DCE.RegisterService("BrowserManager", BrowserManager)
    end
end)

return BrowserManager