-- DCE Control Center v2 - Workspace Manager (Authoritative)
-- Manages window state persistence across sessions
-- Registered with DCE Core via DCE:RegisterService() - never globals

local WorkspaceManager = {}
local DCE = nil
local dceCoreReady = false

local function ConnectToCore()
    if dceCoreReady then return true end
    if GetResourceState('dce-core') ~= 'started' then return false end
    DCE = exports['dce-core']:GetDCEAPI()
    dceCoreReady = true
    return true
end

local workspaces = {}

function WorkspaceManager.SaveWorkspace(playerSource, workspaceData)
    workspaces[playerSource] = workspaceData
    return true
end

function WorkspaceManager.LoadWorkspace(playerSource)
    return workspaces[playerSource] or nil
end

function WorkspaceManager.ClearWorkspace(playerSource)
    workspaces[playerSource] = nil
    return true
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    local attempts = 0
    while not ConnectToCore() and attempts < 50 do
        Wait(100); attempts = attempts + 1
    end
    if DCE and DCE.RegisterService then
        DCE.RegisterService("WorkspaceManager", WorkspaceManager)
    end
end)

return WorkspaceManager