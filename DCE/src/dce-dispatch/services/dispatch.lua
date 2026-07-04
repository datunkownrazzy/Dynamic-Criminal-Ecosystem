-- DCE Dispatch Service
-- Manages dispatch call lifecycle: created -> updated -> resolved.
-- Adapter-based: works with native fallback or third-party CAD/MDT.

local Call = DCECall

local DispatchService = {}
local calls = {}  -- callId -> Call instance
local activeAdapter = nil
local isInitialized = false

function DispatchService.Initialize()
    if isInitialized then
        return
    end
    DCE.Log("dispatch", "info", "Dispatch Service initializing...")
    isInitialized = true
    DCE.Log("dispatch", "info", "Dispatch Service initialized")
end

-- ============================================================================
-- Adapter Management
-- ============================================================================

--- Set the active dispatch adapter.
---@param adapter table Must implement: CreateCall, UpdateCall, ResolveCall, CancelCall
function DispatchService.SetAdapter(adapter)
    activeAdapter = adapter
    if adapter then
        DCE.Log("dispatch", "info", "Dispatch adapter set")
    else
        DCE.Log("dispatch", "warn", "Dispatch adapter cleared (falling back to none)")
    end
end

--- Get the current adapter.
---@return table|nil
function DispatchService.GetAdapter()
    return activeAdapter
end

-- ============================================================================
-- Service Interface
-- ============================================================================

--- Create a new dispatch call.
---@param data table { incidentId, description, regionId, priority?, organizationId?, scenarioId? }
---@return table|nil Call summary
function DispatchService.CreateCall(data)
    if not data then
        return nil
    end

    local call = Call.New(data)
    calls[call.id] = call

    DCE.Log("dispatch", "info", "Call created: %s - %s", call.id, call.description)

    -- Notify adapter
    if activeAdapter and activeAdapter.CreateCall then
        activeAdapter.CreateCall(call:GetSummary())
    end

    -- Emit event
    DCE.Emit("dispatch:call:created", {
        eventName = "dispatch:call:created",
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-dispatch",
        correlationId = call.id,
        payload = call:GetSummary(),
    })

    return call:GetSummary()
end

--- Get call details by ID.
---@param callId string
---@return table|nil
function DispatchService.GetCallDetails(callId)
    local call = calls[callId]
    if not call then
        return nil
    end
    return call:GetSummary()
end

--- Get all active calls.
---@return table Array of call summaries
function DispatchService.GetActiveCalls()
    local active = {}
    for _, call in pairs(calls) do
        if call.status == "pending" or call.status == "active" then
            table.insert(active, call:GetSummary())
        end
    end
    return active
end

--- Activate a call.
---@param callId string
---@return boolean success
function DispatchService.ActivateCall(callId)
    local call = calls[callId]
    if not call then
        return false
    end

    call:Activate()

    if activeAdapter and activeAdapter.UpdateCall then
        activeAdapter.UpdateCall(call:GetSummary())
    end

    DCE.Emit("dispatch:call:updated", {
        eventName = "dispatch:call:updated",
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-dispatch",
        correlationId = callId,
        payload = call:GetSummary(),
    })

    return true
end

--- Update a call with new information.
---@param callId string
---@param updateText string
---@return boolean success
function DispatchService.UpdateCall(callId, updateText)
    local call = calls[callId]
    if not call then
        return false
    end

    call:AddUpdate(updateText)

    if activeAdapter and activeAdapter.UpdateCall then
        activeAdapter.UpdateCall(call:GetSummary())
    end

    DCE.Emit("dispatch:call:updated", {
        eventName = "dispatch:call:updated",
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-dispatch",
        correlationId = callId,
        payload = call:GetSummary(),
    })

    return true
end

--- Resolve a call.
---@param callId string
---@param disposition string How the call was resolved
---@return boolean success
function DispatchService.ResolveCall(callId, disposition)
    local call = calls[callId]
    if not call then
        return false
    end

    call:Resolve(disposition)

    if activeAdapter and activeAdapter.ResolveCall then
        activeAdapter.ResolveCall(call:GetSummary())
    end

    DCE.Emit("dispatch:call:resolved", {
        eventName = "dispatch:call:resolved",
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-dispatch",
        correlationId = callId,
        payload = call:GetSummary(),
    })

    return true
end

--- Check if an incident is officially reported.
---@param incidentId string
---@return boolean
function DispatchService.IsIncidentReported(incidentId)
    for _, call in pairs(calls) do
        if call.incidentId == incidentId and call.status ~= "cancelled" then
            return true
        end
    end
    return false
end

--- Get all calls.
---@return table Array of call summaries
function DispatchService.GetAllCalls()
    local all = {}
    for _, call in pairs(calls) do
        table.insert(all, call:GetSummary())
    end
    return all
end

--- Clean up timed-out calls.
function DispatchService.Cleanup()
    local toRemove = {}
    for callId, call in pairs(calls) do
        if call:HasTimedOut() then
            call:Cancel()
            table.insert(toRemove, callId)
        end
        -- Remove resolved calls older than 10 minutes
        if call.status == "resolved" and call.resolvedAt then
            if os.time() - call.resolvedAt > 600 then
                table.insert(toRemove, callId)
            end
        end
    end
    for _, callId in ipairs(toRemove) do
        calls[callId] = nil
    end
end

-- ============================================================================
-- Shutdown
-- ============================================================================

function DispatchService.Shutdown()
    DCE.Log("dispatch", "info", "Dispatch Service shutting down...")
    for callId, _ in pairs(calls) do
        calls[callId] = nil
    end
    activeAdapter = nil
    isInitialized = false
    DCE.Log("dispatch", "info", "Dispatch Service shutdown complete")
end

_G.DCEDispatchService = DispatchService
