-- DCE Control Center — Sprint 1.11.4 Platform Consumer
--
-- This module is a PLATFORM CONSUMER only.
-- Uses sticky lifecycle events for guaranteed delivery.
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

-- Acquire SDK immediately at module load time
AcquireSDK()

-- ============================================================================
-- Module Initialization
-- ============================================================================

local function OnControlCenterStart()
    if initialized then return end
    if not DCE then
        AcquireSDK()
        if not DCE then return end
    end

    DCE:Log("controlcenter", "info", "=== DCE Control Center Starting ===")

    -- The authoritative "ControlCenter" service is registered by
    -- server/services/controlcenter.lua (ControlCenterService — SOLE OWNER)
    -- via its onResourceStart handler. Registers here would collide and
    -- produce a duplicate-registration warning. Do NOT register again.
    -- Consumers resolve the authoritative service via DCE:GetService("ControlCenter").

    initialized = true
    DCE:Log("controlcenter", "info", "=== DCE Control Center Started ===")
end

local function OnControlCenterStop()
    if not DCE then return end
    DCE:Log("controlcenter", "info", "=== DCE Control Center Stopping ===")
    initialized = false
    DCE:Log("controlcenter", "info", "=== DCE Control Center Stopped ===")
end

-- ============================================================================
-- Exports
-- ============================================================================

local function GetPluginAPI()
    local api = AcquireSDK()
    if not api then return nil end
    return {
        registerPlugin = function(manifest)
            return api:RegisterPlugin(manifest)
        end,
        getPlugins = function()
            return api:ListPlugins()
        end,
    }
end

local function GetSessionManager()
    if not DCE then return nil end
    return DCE:GetService("SessionManager")
end

local function GetWorkspaceManager()
    if not DCE then return nil end
    return DCE:GetService("WorkspaceManager")
end

exports('GetPluginAPI', GetPluginAPI)
exports('GetSessionManager', GetSessionManager)
exports('GetWorkspaceManager', GetWorkspaceManager)

-- ============================================================================
-- Lifecycle
-- ============================================================================

if DCE then
    DCE:On("lifecycle:running", function(payload)
        OnControlCenterStart()
    end)
end

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnControlCenterStop()
    end
end)