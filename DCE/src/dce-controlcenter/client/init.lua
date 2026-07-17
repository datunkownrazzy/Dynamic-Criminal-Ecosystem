-- DCE Control Center v2 - Client Entry Point (Authoritative)
-- SOLE OWNER: /dce command registration, TriggerServerEvent to open/close sessions
-- Per ADR-0026: Single entry point: /dce command.
-- Commands belong to the client. Per CC-v2-ARCHITECTURE:
-- Player -> /dce -> TriggerServerEvent -> Server validation -> Session -> Browser

local DCE = nil
local dceCoreReady = false

local function ConnectToCore()
    if dceCoreReady then return true end
    if GetResourceState('dce-core') ~= 'started' then return false end
    DCE = exports['dce-core']:GetDCEAPI()
    dceCoreReady = true
    return true
end

local function GetService(serviceName)
    if not DCE then return nil end
    return DCE.GetService and DCE.GetService(serviceName)
end

-- ============================================================================
-- Commands - Single public entry point: /dce
-- ============================================================================
-- Commands execute on the client. They call TriggerServerEvent to reach server.
-- Server validates permissions and creates sessions.

RegisterCommand('dce', function(source, args)
    if source == 0 then return end
    TriggerServerEvent('dce-cc:server:open', source)
end, true)

RegisterCommand('dceclose', function(source, args)
    if source == 0 then return end
    TriggerServerEvent('dce-cc:server:close', source)
end, true)

RegisterKeyMapping('dce', 'Open DCE Control Center', 'keyboard', 'F6')

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

ConnectToCore()

AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if not dceCoreReady then
        ConnectToCore()
    end
end)

print("[DCE Client] Client entry point loaded - /dce command registered")