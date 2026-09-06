-- DCE Control Center v2 - Workspace Manager (Authoritative)
-- Manages window state persistence across sessions
-- Registered with DCE Core via DCE:RegisterService() - never globals
--
-- Sprint 1.11.6 FiveM Loader Compliance:
--   fxmanifest.lua declares dependencies { 'dce-core' }, which per the FiveM
--   resource manifest reference REQUIRES dce-core to load and fully start
--   BEFORE this resource executes any script. No polling, no Wait(), no retries.

local WorkspaceManager = {}
local DCE = nil
local dceCoreReady = false

local function ConnectToCore()
    if dceCoreReady then return true end
    -- Deterministic: dce-core is guaranteed started by the dependency directive.
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

RegisterNetEvent('dce-cc:workspace:save')
AddEventHandler('dce-cc:workspace:save', function(workspaceData)
    local playerSource = source
    if not workspaceData or not workspaceData.sessionId then return end

    ConnectToCore()
    local sessionManager = DCE and DCE:GetService("SessionManager")
    local session = sessionManager and sessionManager.GetSession(workspaceData.sessionId)
    if not session or session.playerSource ~= playerSource then return end

    WorkspaceManager.SaveWorkspace(playerSource, {
        windows = workspaceData.windows or {},
        sessionId = workspaceData.sessionId
    })
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    -- Deterministic single-pass init. No polling, no Wait(), no retries.
    ConnectToCore()
    if DCE and DCE.RegisterService then
        DCE:RegisterService("WorkspaceManager", WorkspaceManager)
    end
end)

return WorkspaceManager