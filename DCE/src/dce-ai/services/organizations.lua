-- DCE Organizations Service
-- Owns organization identity, runtime state, leadership, and state exposure.
-- Per ADR-0001: shares dce-ai resource with AI Director.
-- Spec: docs/05_Organizations/Organizations.md

local Organization = DCEOrganization
local StateTransitions = DCEStateTransitions

local OrganizationsService = {}
local organizations = {}  -- orgId -> Organization instance
local isInitialized = false

--- Initialize the Organizations service.
function OrganizationsService.Initialize()
    if isInitialized then
        return
    end

    DCE.Log("ai", "info", "Organizations Service initializing...")

    local orgData = DCEOrganizations
    for id, data in pairs(orgData) do
        organizations[id] = Organization.New(id, data)
        DCE.Log("ai", "info", "  Organization loaded: %s (%s)", id, data.displayName)
    end

    DCE.Log("ai", "info", "Organizations Service initialized with %d organizations", #orgData)
    isInitialized = true
end

-- ============================================================================
-- Service Interface (Public API)
-- ============================================================================

--- Get the runtime state of an organization.
---@param orgId string
---@return table|nil Organization state (read model)
function OrganizationsService.GetState(orgId)
    local org = organizations[orgId]
    if not org then
        return nil
    end
    return org:GetState()
end

--- Get the identity data of an organization.
---@param orgId string
---@return table|nil { id, displayName, personality }
function OrganizationsService.GetIdentity(orgId)
    local org = organizations[orgId]
    if not org then
        return nil
    end
    return org:GetIdentity()
end

--- Get the leadership hierarchy of an organization.
---@param orgId string
---@return table|nil
function OrganizationsService.GetLeadership(orgId)
    local org = organizations[orgId]
    if not org then
        return nil
    end
    return org:GetLeadership()
end

--- Get all registered organization IDs.
---@return table Array of org ID strings
function OrganizationsService.GetAllOrgIds()
    local ids = {}
    for id, _ in pairs(organizations) do
        table.insert(ids, id)
    end
    return ids
end

--- Get the current state enum value for an organization.
---@param orgId string
---@return string|nil
function OrganizationsService.GetOrgState(orgId)
    local org = organizations[orgId]
    if not org then
        return nil
    end
    return org.runtime.state
end

--- Set the organization's state (called by AI Director).
---@param orgId string
---@param newState string
---@return boolean success
function OrganizationsService.SetOrganizationState(orgId, newState)
    local org = organizations[orgId]
    if not org then
        return false
    end

    local oldState = org.runtime.state
    if not org:SetState(newState) then
        return false
    end

    -- Emit state change event
    DCE.Emit("organization:state:changed", {
        eventName = "organization:state:changed",
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-ai",
        payload = {
            organizationId = orgId,
            fromState = oldState,
            toState = newState,
        },
    })

    DCE.Log("ai", "info", "Organization '%s' state changed: %s -> %s", orgId, oldState, newState)
    return true
end

--- Add heat to an organization.
---@param orgId string
---@param amount number
function OrganizationsService.AddHeat(orgId, amount)
    local org = organizations[orgId]
    if not org then
        return
    end
    org:AddHeat(amount)
end

--- Add money to an organization.
---@param orgId string
---@param amount number
function OrganizationsService.AddMoney(orgId, amount)
    local org = organizations[orgId]
    if not org then
        return
    end
    org:AddMoney(amount)
end

--- Get a summary of all organization states.
---@return table Array of org state summaries
function OrganizationsService.GetAllOrgStates()
    local states = {}
    for id, org in pairs(organizations) do
        table.insert(states, org:GetState())
    end
    return states
end

--- Get the internal organization instance (for AI Director use only).
---@param orgId string
---@return table|nil
function OrganizationsService.GetOrgInstance(orgId)
    return organizations[orgId]
end

-- ============================================================================
-- Perception Pressure API
-- ============================================================================

--- Set perception pressure for an organization from world signals.
---@param orgId string
---@param visible number Visible pressure (0-100)
---@param covert number Covert pressure (0-100)
---@param source string Description of pressure source
function OrganizationsService.SetPerceptionPressure(orgId, visible, covert, source)
    local org = organizations[orgId]
    if not org then
        return
    end
    
    if not Config.AI.PerceptionPressure or not Config.AI.PerceptionPressure.Enabled then
        return
    end
    
    local oldPerception = org.runtime.perceptionPressure
    org:SetPerceptionPressure(visible, covert)
    org.runtime.lastPressureSource = source
    
    local newPerception = org.runtime.perceptionPressure
    
    -- Emit pressure updated event if changed
    if newPerception ~= oldPerception then
        DCE.Emit("organization:perception:pressure_updated", {
            eventName = "organization:perception:pressure_updated",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-ai",
            payload = {
                organizationId = orgId,
                regionId = source,  -- source contains region context
                visiblePressure = org.runtime.visiblePressure,
                covertPressure = org.runtime.covertPressure,
                perceptionPressure = newPerception,
                reason = "enforcement_signals",
            },
        })
    end
    
    -- Check for spike threshold
    local spikeThreshold = Config.AI.PerceptionPressure.SpikeThreshold or 60
    if newPerception >= spikeThreshold and oldPerception < spikeThreshold then
        -- Pressure spiked - emit spike event and set cooldown
        org:ResetPressureCooldown()
        
        DCE.Emit("organization:perception:pressure_spiked", {
            eventName = "organization:perception:pressure_spiked",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-ai",
            payload = {
                organizationId = orgId,
                regionId = source,
                visiblePressure = org.runtime.visiblePressure,
                covertPressure = org.runtime.covertPressure,
                perceptionPressure = newPerception,
                reason = "enforcement_spike",
            },
        })
        
        DCE.Log("ai", "warning", "Organization '%s' perception pressure spiked: %d (visible: %d, covert: %d)", 
            orgId, newPerception, org.runtime.visiblePressure, org.runtime.covertPressure)
    end
end

--- Apply perception pressure incrementally (adds to existing pressure).
---@param orgId string
---@param visible number Visible pressure to add
---@param covert number Covert pressure to add
---@param source string Description of pressure source
function OrganizationsService.ApplyPerceptionPressure(orgId, visible, covert, source)
    local org = organizations[orgId]
    if not org then
        return
    end
    
    if not Config.AI.PerceptionPressure or not Config.AI.PerceptionPressure.Enabled then
        return
    end
    
    local oldPerception = org.runtime.perceptionPressure
    org:ApplyPerceptionPressure(visible, covert, source)
    local newPerception = org.runtime.perceptionPressure
    
    -- Emit pressure updated event if changed
    if newPerception ~= oldPerception then
        DCE.Emit("organization:perception:pressure_updated", {
            eventName = "organization:perception:pressure_updated",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-ai",
            payload = {
                organizationId = orgId,
                regionId = source,
                visiblePressure = org.runtime.visiblePressure,
                covertPressure = org.runtime.covertPressure,
                perceptionPressure = newPerception,
                reason = "enforcement_increment",
            },
        })
    end
    
    -- Check for spike threshold
    local spikeThreshold = Config.AI.PerceptionPressure.SpikeThreshold or 60
    if newPerception >= spikeThreshold and oldPerception < spikeThreshold then
        org:ResetPressureCooldown()
        
        DCE.Emit("organization:perception:pressure_spiked", {
            eventName = "organization:perception:pressure_spiked",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-ai",
            payload = {
                organizationId = orgId,
                regionId = source,
                visiblePressure = org.runtime.visiblePressure,
                covertPressure = org.runtime.covertPressure,
                perceptionPressure = newPerception,
                reason = "enforcement_spike",
            },
        })
        
        DCE.Log("ai", "warning", "Organization '%s' perception pressure spiked: %d (visible: %d, covert: %d)", 
            orgId, newPerception, org.runtime.visiblePressure, org.runtime.covertPressure)
    end
end

--- Decay perception pressure for an organization.
---@param orgId string
---@param deltaTime number Time elapsed since last tick (seconds)
function OrganizationsService.DecayPerceptionPressure(orgId, deltaTime)
    local org = organizations[orgId]
    if not org then
        return
    end
    
    org:DecayPerceptionPressure(deltaTime)
end

--- Get perception pressure state for an organization.
---@param orgId string
---@return table|nil { visible, covert, perception, onCooldown, source }
function OrganizationsService.GetPerceptionPressure(orgId)
    local org = organizations[orgId]
    if not org then
        return nil
    end
    return org:GetPerceptionPressure()
end

-- ============================================================================
-- Internal: State Transition Evaluation
-- ============================================================================

--- Evaluate state transitions for all organizations.
---@return table Array of { orgId, fromState, toState } for transitions that occurred
function OrganizationsService.EvaluateTransitions()
    local transitions = {}
    for orgId, org in pairs(organizations) do
        local newState = StateTransitions.Evaluate(org)
        if newState then
            table.insert(transitions, {
                orgId = orgId,
                fromState = org.runtime.state,
                toState = newState,
            })
        end
    end
    return transitions
end

-- ============================================================================
-- Shutdown
-- ============================================================================

function OrganizationsService.Shutdown()
    DCE.Log("ai", "info", "Organizations Service shutting down...")
    for orgId, _ in pairs(organizations) do
        organizations[orgId] = nil
    end
    isInitialized = false
    DCE.Log("ai", "info", "Organizations Service shutdown complete")
end

_G.DCEOrganizationsService = OrganizationsService
