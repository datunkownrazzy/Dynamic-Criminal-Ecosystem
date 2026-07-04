-- DCE Dispatch Service - Resource Entry Point

local DispatchService = DCEDispatchService
local NativeAdapter = DCENativeAdapter
local ERSAdapter = DCERSAdapter

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

local function GetDCEAPI()
    local DCEAPI = nil
    local attempts = 0
    while not DCEAPI and attempts < 50 do
        attempts = attempts + 1
        Citizen.Wait(100)
        local success, api = pcall(function()
            return exports['dce-core']:GetDCEAPI()
        end)
        if success then
            DCEAPI = api
        end
    end
    return DCEAPI
end

local function GetConfiguredAdapter()
    local integration = Config.Dispatch.Integration or {}
    local mode = integration.Mode or "native"

    if mode == "custom" and integration.Adapter then
        return integration.Adapter
    end

    if mode == "ers" then
        local adapter = ERSAdapter.New(integration)
        if adapter:IsAvailable() then
            return adapter
        end

        if integration.EnableStandaloneFallback ~= false then
            DCE.Log("dispatch", "warn", "ERS dispatch adapter unavailable; falling back to native standalone")
        end
    end

    return NativeAdapter
end

local function OnDispatchStart()
    local DCEAPI = GetDCEAPI()
    if not DCEAPI then
        print("^1[DCE Dispatch] FATAL: Could not obtain DCE API from dce-core^0")
        return
    end
    _G.DCE = DCEAPI

    DCE.Log("dispatch", "info", "=== DCE Dispatch Service Starting ===")

    DispatchService.Initialize()

    DispatchService.SetAdapter(GetConfiguredAdapter())

    -- Register the Dispatch service
    DCE.RegisterService("Dispatch", {
        CreateCall = function(data) return DispatchService.CreateCall(data) end,
        GetCallDetails = function(callId) return DispatchService.GetCallDetails(callId) end,
        GetActiveCalls = function() return DispatchService.GetActiveCalls() end,
        GetAllCalls = function() return DispatchService.GetAllCalls() end,
        ActivateCall = function(callId) return DispatchService.ActivateCall(callId) end,
        UpdateCall = function(callId, updateText) return DispatchService.UpdateCall(callId, updateText) end,
        ResolveCall = function(callId, disposition) return DispatchService.ResolveCall(callId, disposition) end,
        IsIncidentReported = function(incidentId) return DispatchService.IsIncidentReported(incidentId) end,
        SetAdapter = function(adapter) DispatchService.SetAdapter(adapter) end,
    })

    -- Subscribe to dispatch call requests from the scenario engine
    DCE.On("dispatch:call:requested", function(payload)
        local data = payload.payload or payload
        DispatchService.CreateCall({
            incidentId = data.scenarioId,
            description = data.description or "Suspicious activity reported",
            regionId = data.regionId,
            priority = data.priority or "medium",
            organizationId = data.organizationId,
            scenarioId = data.scenarioId,
        })
    end)

    DCE.Log("dispatch", "info", "=== DCE Dispatch Service Started ===")
end

local function OnDispatchStop()
    DCE.Log("dispatch", "info", "=== DCE Dispatch Service Stopping ===")

    DCE.UnregisterService("Dispatch")
    DispatchService.Shutdown()

    DCE.Log("dispatch", "info", "=== DCE Dispatch Service Stopped ===")
end

-- ============================================================================
-- Lifecycle Hooks
-- ============================================================================

-- Wait for events to be ready before initializing
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == "dce-events" then
        OnDispatchStart()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnDispatchStop()
    end
end)