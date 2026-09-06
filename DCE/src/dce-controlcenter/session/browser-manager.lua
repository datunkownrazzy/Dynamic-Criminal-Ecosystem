-- DCE Control Center v2 - Browser Manager (Authoritative)
-- Owns browser lifecycle operations only
-- FiveM creates/destroys the actual CEF browser; this manages the abstraction
-- Registered with DCE Core via DCE:RegisterService() - never globals
--
-- Sprint 1.11.6 FiveM Loader Compliance:
--   fxmanifest.lua declares dependencies { 'dce-core' }, which per the FiveM
--   resource manifest reference REQUIRES dce-core to load and fully start
--   BEFORE this resource executes any script. No polling, no Wait(), no retries.

local BrowserManager = {}
local DCE = nil
local dceCoreReady = false

local function ConnectToCore()
    if dceCoreReady then return true end
    -- Deterministic: dce-core is guaranteed started by the dependency directive.
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
    -- Deterministic single-pass init. No polling, no Wait(), no retries.
    ConnectToCore()
    if DCE and DCE.RegisterService then
        DCE:RegisterService("BrowserManager", BrowserManager)
    end
end)

return BrowserManager