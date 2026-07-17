-- DCE Control Center v2 - Session Controller Client (Authoritative)
-- Handles unique NUI callbacks for session lifecycle
-- NOTE: dce-cc:application:booted is handled in bootstrap.lua (NUI communication owner)
-- Uses DCE:GetService() for dependencies - never globals

local SessionController = {}
local DCE = nil

local function GetService(serviceName)
    if not DCE then return nil end
    return DCE.GetService and DCE.GetService(serviceName)
end

local function ConnectToCore()
    if GetResourceState('dce-core') == 'started' then
        DCE = exports['dce-core']:GetDCEAPI()
    end
end

ConnectToCore()

RegisterNUICallback('dce-cc:session:started', function(data, cb)
    print("[DCE SessionController] Session started confirmed")
    cb({ status = "ok" })
end)

RegisterNUICallback('dce-cc:session:closed', function(data, cb)
    TriggerServerEvent('dce-cc:session:closed', {})
    cb({ status = "ok" })
end)

RegisterNUICallback('dce-cc:session:error', function(data, cb)
    print("[DCE SessionController] Session error: " .. tostring(data and data.error or "unknown"))
    cb({ status = "ok" })
end)

RegisterNUICallback('dce-cc:window:allClosed', function(data, cb)
    cb({})
end)

RegisterNUICallback('dce-cc:workspace:save', function(data, cb)
    local WM = GetService("WorkspaceManager")
    if WM and data and data.sessionId then
        WM.SaveWorkspace(GetPlayerServerId(PlayerId()), {
            windows = data.windows or {},
            sessionId = data.sessionId
        })
        print("[DCE SessionController] Workspace saved for session: " .. tostring(data.sessionId))
    end
    cb({ status = "ok" })
end)

AddEventHandler("onClientResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
end)

return SessionController