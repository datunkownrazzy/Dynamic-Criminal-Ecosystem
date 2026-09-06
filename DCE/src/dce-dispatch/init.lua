-- DCE Dispatch — Sprint 1.11.6 FiveM Loader Compliance
--
-- PLATFORM CONSUMER.
-- Does NOT own runtime state. Does NOT poll. Does NOT retry.
--
-- SDK acquisition is DIRECT and UNCONDITIONAL:
--   local DCE = exports['dce-core']:GetDCEAPI()
--
-- Deterministic because fxmanifest.lua declares dependencies { 'dce-core' },
-- which per the FiveM resource manifest reference REQUIRES dce-core to load
-- and fully start BEFORE this resource executes any script.
---
---@diagnostic disable: undefined-global

-- ============================================================================
-- SDK Acquisition — Direct, single call, no polling, no retries
-- ============================================================================
local DCE = exports['dce-core']:GetDCEAPI()

if not DCE then
    error("dce-dispatch: exports['dce-core']:GetDCEAPI() returned nil. Add 'dce-core' to dependencies and ensure it starts first.")
end

local initialized = false

local function OnDispatchStart()
    if initialized then return end

    DCE:Log("dispatch", "info", "=== DCE Dispatch Starting ===")

    if DCEDispatchService and DCEDispatchService.Initialize then
        DCEDispatchService.Initialize()
    end

    DCE:RegisterService("Dispatch", {
        CreateCall = function(data) return DCEDispatchService and DCEDispatchService.CreateCall(data) end,
        GetCall = function(callId) return DCEDispatchService and DCEDispatchService.GetCall(callId) end,
        UpdateCall = function(callId, data) return DCEDispatchService and DCEDispatchService.UpdateCall(callId, data) end,
        CloseCall = function(callId) return DCEDispatchService and DCEDispatchService.CloseCall(callId) end,
        GetActiveCalls = function() return DCEDispatchService and DCEDispatchService.GetActiveCalls() end,
        GetAllCalls = function() return DCEDispatchService and DCEDispatchService.GetAllCalls() end,
        DispatchUnit = function(unitId, callId) return DCEDispatchService and DCEDispatchService.DispatchUnit(unitId, callId) end,
    })

    initialized = true
    DCE:Log("dispatch", "info", "=== DCE Dispatch Started ===")
end

local function OnDispatchStop()
    if not DCE then return end
    DCE:Log("dispatch", "info", "=== DCE Dispatch Stopping ===")
    DCE:UnregisterService("Dispatch")
    if DCEDispatchService and DCEDispatchService.Shutdown then
        DCEDispatchService.Shutdown()
    end
    initialized = false
    DCE:Log("dispatch", "info", "=== DCE Dispatch Stopped ===")
end

-- ============================================================================
-- Lifecycle — Unconditional sticky subscription
-- ============================================================================
-- The EventBus replays sticky events to new subscribers, guaranteeing delivery
-- even if lifecycle:running was already emitted before this resource loaded.
DCE:On("lifecycle:running", function(payload)
    OnDispatchStart()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnDispatchStop()
    end
end)