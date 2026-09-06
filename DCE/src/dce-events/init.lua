-- DCE Scenario Engine — Sprint 1.11.6 FiveM Loader Compliance
--
-- PLATFORM CONSUMER.
-- Does NOT own runtime state. Does NOT poll. Does NOT retry.
--
-- SDK acquisition is DIRECT and UNCONDITIONAL:
--   local DCE = exports['dce-core']:GetDCEAPI()
--
-- This is deterministic because fxmanifest.lua declares
--   dependencies { 'dce-core' }
-- which per the FiveM resource manifest reference REQUIRES dce-core to load
-- and fully start BEFORE this resource executes any script. Therefore the
-- exports["dce-core"].GetDCEAPI export is guaranteed to exist.
---
---@diagnostic disable: undefined-global

-- ============================================================================
-- SDK Acquisition — Direct, single call, no polling, no retries
-- ============================================================================
local DCE = exports['dce-core']:GetDCEAPI()

if not DCE then
    error("dce-events: exports['dce-core']:GetDCEAPI() returned nil. Add 'dce-core' to dependencies and ensure it starts first.")
end

local initialized = false

local function OnEventsStart()
    if initialized then return end

    DCE:Log("events", "info", "=== DCE Scenario Engine Starting ===")

    if DCEScenarioEngine and DCEScenarioEngine.Initialize then
        DCEScenarioEngine.Initialize()
    end

    DCE:RegisterService("ScenarioEngine", {
        CreateScenario = function(data) return DCEScenarioEngine and DCEScenarioEngine.CreateScenario(data) end,
        Tick = function() return DCEScenarioEngine and DCEScenarioEngine.Tick() end,
        GetScenario = function(scenarioId) return DCEScenarioEngine and DCEScenarioEngine.GetScenario(scenarioId) end,
        GetActiveScenarios = function() return DCEScenarioEngine and DCEScenarioEngine.GetActiveScenarios() end,
        GetAllScenarios = function() return DCEScenarioEngine and DCEScenarioEngine.GetAllScenarios() end,
        InterdictScenario = function(scenarioId) return DCEScenarioEngine and DCEScenarioEngine.InterdictScenario(scenarioId) end,
    })

    local tickInterval = DCE:GetConfig("Scenario.TickInterval", 5000)
    DCE:Schedule("events:scenario:tick", tickInterval, function()
        if DCEScenarioEngine and DCEScenarioEngine.Tick then
            DCEScenarioEngine.Tick()
        end
    end)

    initialized = true
    DCE:Log("events", "info", "=== DCE Scenario Engine Started ===")
end

local function OnEventsStop()
    if not DCE then return end
    DCE:Log("events", "info", "=== DCE Scenario Engine Stopping ===")
    DCE:UnregisterService("ScenarioEngine")
    if DCEScenarioEngine and DCEScenarioEngine.Shutdown then
        DCEScenarioEngine.Shutdown()
    end
    initialized = false
    DCE:Log("events", "info", "=== DCE Scenario Engine Stopped ===")
end

-- ============================================================================
-- Lifecycle — Unconditional sticky subscription
-- ============================================================================
-- The EventBus replays sticky events to new subscribers, guaranteeing delivery
-- even if lifecycle:running was already emitted before this resource loaded.
DCE:On("lifecycle:running", function(payload)
    OnEventsStart()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnEventsStop()
    end
end)