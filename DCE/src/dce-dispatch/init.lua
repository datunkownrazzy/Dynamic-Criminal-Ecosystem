-- DCE Dispatch Service - Resource Entry Point

local DispatchService = require("services.dispatch")
local NativeAdapter = require("adapters.native")

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

local function OnDispatchStart()
    DCE:Log("dispatch", "info", "=== DCE Dispatch Service Starting ===")

    DispatchService.Initialize()

    -- Set the native adapter as the default (fallback)
    DispatchService.SetAdapter(NativeAdapter)

    -- Register the Dispatch service
    DCE:RegisterService("Dispatch", {
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
    DCE:On("dispatch:call:requested", function(payload)
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

    DCE:Log("dispatch", "info", "=== DCE Dispatch Service Started ===")
end

local function OnDispatchStop()
    DCE:Log("dispatch", "info", "=== DCE Dispatch Service Stopping ===")

    DCE:UnregisterService("Dispatch")
    DispatchService.Shutdown()

    DCE:Log("dispatch", "info", "=== DCE Dispatch Service Stopped ===")
end

-- ============================================================================
-- Lifecycle Hooks
-- ============================================================================

DCE:Once("core:initialized", function()
    OnDispatchStart()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        OnDispatchStop()
    end
end)