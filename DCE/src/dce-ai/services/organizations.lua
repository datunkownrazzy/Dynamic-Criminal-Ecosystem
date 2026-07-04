-- DCE Organizations Service
-- Owns organization identity, runtime state, leadership, and state exposure.
-- Per ADR-0001: shares dce-ai resource with AI Director.
-- Spec: docs/05_Organizations/Organizations.md

local Organization = require("models.organization")
local StateTransitions = require("simulation.state-transitions")

local OrganizationsService = {}
local organizations = {}  -- orgId -> Organization instance
local isInitialized = false

--- Initialize the Organizations service.
function OrganizationsService.Initialize()
    if isInitialized then
        return
    end

    DCE:Log("ai", "info", "Organizations Service initializing...")

    local orgData = require("data.organizations")
    for id, data in pairs(orgData) do
        organizations[id] = Organization.New(id, data)
        DCE:Log("ai", "info", "  Organization loaded: %s (%s)", id, data.displayName)
    end

    DCE:Log("ai", "info", "Organizations Service initialized with %d organizations", #orgData)
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
    DCE:Emit("organization:state:changed", {
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

    DCE:Log("ai", "info", "Organization '%s' state changed: %s -> %s", orgId, oldState, newState)
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
    DCE:Log("ai", "info", "Organizations Service shutting down...")
    for orgId, _ in pairs(organizations) do
        organizations[orgId] = nil
    end
    isInitialized = false
    DCE:Log("ai", "info", "Organizations Service shutdown complete")
end

return OrganizationsService