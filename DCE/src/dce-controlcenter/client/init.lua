-- DCE Control Center v2 - Client Entry Point — Sprint 1.11.3
--
-- SOLE OWNER: /dce command registration, TriggerServerEvent to open/close sessions
-- Uses sticky lifecycle events for guaranteed delivery.
-- No polling. No retry loops.
---
---@diagnostic disable: undefined-global

local DCE = nil
local initialized = false

-- ============================================================================
-- SDK Acquisition — Single Call, No Polling
-- ============================================================================

local function AcquireSDK()
    local success, api = pcall(function()
        if exports and exports['dce-core'] and exports['dce-core'].GetDCEAPI then
            return exports['dce-core']:GetDCEAPI()
        end
        return nil
    end)
    if success then
        DCE = api
    end
    return DCE
end

-- ============================================================================
-- Commands - Single public entry point: /dce
-- ============================================================================

RegisterCommand('dce', function(source, args)
    -- NOTE: In FiveM, client-side RegisterCommand callbacks always receive
    -- source == 0 because the command executes locally on the client.
    -- The server-side handler (ControlCenterService.RequestOpen) validates
    -- the actual player source from the event context. Do NOT filter here.
    print("[DCE ControlCenter] /dce invoked")
    TriggerServerEvent('dce-cc:server:open')
end, false)

RegisterCommand('dceclose', function(source, args)
    -- Same as above: client-side commands always have source == 0.
    -- The server-side handler validates the player source from event context.
    print("[DCE ControlCenter] /dceclose invoked")
    TriggerServerEvent('dce-cc:server:close')
end, false)

RegisterKeyMapping('dce', 'Open DCE Control Center', 'keyboard', 'F6')

-- ============================================================================
-- Lifecycle
-- ============================================================================

Citizen.CreateThread(function()
    Citizen.Wait(0)
    DCE = AcquireSDK()
    if DCE then
        DCE:On("lifecycle:running", function(payload)
            if not initialized then
                initialized = true
                print("[DCE Client] Connected to DCE Core successfully")
            end
        end)
    end
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if not DCE then
        DCE = AcquireSDK()
    end
end)

print("[DCE Client] Client entry point loaded - /dce command registered")