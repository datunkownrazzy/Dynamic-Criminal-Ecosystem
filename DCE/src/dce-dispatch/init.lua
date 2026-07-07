-- DCE Dispatch Service - Resource Entry Point
-- Defensive nil-check patterns are intentional for FiveM resource timing safety per ADR-0001

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
            if exports and exports['dce-core'] and exports['dce-core'].GetDCEAPI then
                return exports['dce-core']:GetDCEAPI()
            end
            return nil
        end)
        if success then
            DCEAPI = api
        end
    end
    return DCEAPI
end

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

local function GetConfiguredAdapter()
    local Config = getConfig()
    local integration = {}
    if Config.Dispatch and Config.Dispatch.Integration then
        integration = Config.Dispatch.Integration
    end
    local mode = integration.Mode or "native"

    if mode == "custom" and integration.Adapter then
        return integration.Adapter
    end

    if mode == "ers" then
        -- ERS adapter is optional - check at runtime
        if _G.DCEERSDispatchAdapter and _G.DCEERSDispatchAdapter.New then
            local adapter = _G.DCEERSDispatchAdapter.New(integration)
            if adapter and adapter.IsAvailable and adapter:IsAvailable() then
                return adapter
            end
        end

        if integration.EnableStandaloneFallback ~= false then
            if DCE and DCE.Log then
                DCE.Log("dispatch", "warn", "ERS dispatch adapter unavailable; falling back to native standalone")
            end
        end
    end

    if mode == "native" or mode == "ers" or mode == "custom" then
        local nativeAdapter = _G.DCENativeDispatchAdapter
        if nativeAdapter and nativeAdapter.New then
            return nativeAdapter.New()
        end
    end

    return {}
end

local function OnDispatchStart()
    local DCEAPI = GetDCEAPI()
    if not DCEAPI then
        print("^1[DCE Dispatch] FATAL: Could not obtain DCE API from dce-core^0")
        return
    end
    -- _G.DCE is owned by dce-core; use the API locally
    -- Do NOT overwrite _G.DCE to prevent race conditions

    if DCE and DCE.Log then
        DCE.Log("dispatch", "info", "=== DCE Dispatch Service Starting ===")
    end

    -- Initialize dispatch service (DCEDispatchService is set by services/dispatch.lua at load time)
    if DCEDispatchService and DCEDispatchService.Initialize then
        DCEDispatchService.Initialize()
    end

    if DCEDispatchService and DCEDispatchService.SetAdapter then
        DCEDispatchService.SetAdapter(GetConfiguredAdapter())
    end

    -- Register the Dispatch service
    -- Defensive patterns: return nil OR actual value for service timing safety
    if DCE and DCE.RegisterService then
        DCE.RegisterService("Dispatch", {
            CreateCall = function(data) return DCEDispatchService and DCEDispatchService.CreateCall(data) end,
            GetCallDetails = function(callId) return DCEDispatchService and DCEDispatchService.GetCallDetails(callId) end,
            GetActiveCalls = function() return DCEDispatchService and DCEDispatchService.GetActiveCalls() end,
            GetAllCalls = function() return DCEDispatchService and DCEDispatchService.GetAllCalls() end,
            ActivateCall = function(callId) return DCEDispatchService and DCEDispatchService.ActivateCall(callId) end,
            UpdateCall = function(callId, updateText) return DCEDispatchService and DCEDispatchService.UpdateCall(callId, updateText) end,
            ResolveCall = function(callId, disposition) return DCEDispatchService and DCEDispatchService.ResolveCall(callId, disposition) end,
            IsIncidentReported = function(incidentId) return DCEDispatchService and DCEDispatchService.IsIncidentReported(incidentId) end,
            SetAdapter = function(adapter) 
                if DCEDispatchService and DCEDispatchService.SetAdapter then 
                    DCEDispatchService.SetAdapter(adapter) 
                end 
            end,
        })
    end

    -- Subscribe to dispatch call requests from the scenario engine
    if DCE and DCE.On then
        -- AUDIT: dce-dispatch/init.lua:113 DCE.On event=dispatch:call:requested
        print("[AUDIT-SITE] dce-dispatch/init.lua:113 DCE.On event=dispatch:call:requested cb_type=" .. type(function(payload) end))
        DCE.On("dispatch:call:requested", function(payload)
            local data = payload and (payload.payload or payload)
            if data and DCEDispatchService and DCEDispatchService.CreateCall then
                DCEDispatchService.CreateCall({
                    incidentId = data.scenarioId,
                    description = data.description or "Suspicious activity reported",
                    regionId = data.regionId,
                    priority = data.priority or "medium",
                    organizationId = data.organizationId,
                    scenarioId = data.scenarioId,
                })
            end
        end)
    end

    if DCE and DCE.Log then
        DCE.Log("dispatch", "info", "=== DCE Dispatch Service Started ===")
    end
end

local function OnDispatchStop()
    -- Safely clean up - DCE may be nil if core shut down first
    if DCE and DCE.Log then
        DCE.Log("dispatch", "info", "=== DCE Dispatch Service Stopping ===")
    end
    
    if DCE and DCE.UnregisterService then
        DCE.UnregisterService("Dispatch")
    end
    
    if DCEDispatchService and DCEDispatchService.Shutdown then
        DCEDispatchService.Shutdown()
    end
    
    if DCE and DCE.Log then
        DCE.Log("dispatch", "info", "=== DCE Dispatch Service Stopped ===")
    end
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