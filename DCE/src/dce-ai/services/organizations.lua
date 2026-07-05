-- DCE Organizations Service
-- Owns organization identity, runtime state, leadership, and state exposure.
-- Per ADR-0001: shares dce-ai resource with AI Director.
-- Spec: docs/05_Organizations/Organizations.md

-- Get modules safely from _G
local function getModule(name)
    return _G[name] or {}
end

local Organization = getModule("DCEOrganization")
local StateTransitions = getModule("DCEStateTransitions")
local DCEOrganizations = getModule("DCEOrganizations")

local OrganizationsService = {}
local organizations = {}  -- orgId -> Organization instance
local isInitialized = false

--- Initialize the Organizations service.
function OrganizationsService.Initialize()
    if isInitialized then
        return
    end

    if DCE and DCE.Log then
        DCE.Log("ai", "info", "Organizations Service initializing...")
    end

    local orgData = DCEOrganizations
    for id, data in pairs(orgData) do
        if Organization.New then
            organizations[id] = Organization.New(id, data)
            if DCE and DCE.Log then
                DCE.Log("ai", "info", "  Organization loaded: %s (%s)", id, data.displayName)
            end
        end
    end

    if DCE and DCE.Log then
        DCE.Log("ai", "info", "Organizations Service initialized with %d organizations", #orgData)
    end
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
    if DCE and DCE.Emit then
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

        if DCE and DCE.Log then
            DCE.Log("ai", "info", "Organization '%s' state changed: %s -> %s", orgId, oldState, newState)
        end
    end

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
    if org.AddHeat then
        org:AddHeat(amount)
    end
end

--- Add money to an organization.
---@param orgId string
---@param amount number
function OrganizationsService.AddMoney(orgId, amount)
    local org = organizations[orgId]
    if not org then
        return
    end
    if org.AddMoney then
        org:AddMoney(amount)
    end
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

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

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

    local Config = getConfig()
    if not Config.AI or not Config.AI.PerceptionPressure or not Config.AI.PerceptionPressure.Enabled then
        return
    end

    local oldPerception = org.runtime.perceptionPressure
    if org.SetPerceptionPressure then
        org:SetPerceptionPressure(visible, covert)
    end
    org.runtime.lastPressureSource = source

    local newPerception = org.runtime.perceptionPressure

    -- Emit pressure updated event if changed
    if DCE and DCE.Emit and newPerception ~= oldPerception then
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
    local spikeThreshold = (Config.AI.PerceptionPressure and Config.AI.PerceptionPressure.SpikeThreshold) or 60
    if newPerception >= spikeThreshold and oldPerception < spikeThreshold then
        if org.ResetPressureCooldown then
            org:ResetPressureCooldown()
        end

        if DCE and DCE.Emit then
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

            if DCE and DCE.Log then
                DCE.Log("ai", "warn", "Organization '%s' perception pressure spiked: %d (visible: %d, covert: %d)", 
                    orgId, newPerception, org.runtime.visiblePressure, org.runtime.covertPressure)
            end
        end
    end
end

---@param orgId string
---@param visible number Visible pressure to add
---@param covert number Covert pressure to add
---@param source string Description of pressure source
function OrganizationsService.ApplyPerceptionPressure(orgId, visible, covert, source)
    local org = organizations[orgId]
    if not org then
        return
    end

    local Config = getConfig()
    if not Config.AI or not Config.AI.PerceptionPressure or not Config.AI.PerceptionPressure.Enabled then
        return
    end

    local oldPerception = org.runtime.perceptionPressure
    if org.ApplyPerceptionPressure then
        org:ApplyPerceptionPressure(visible, covert, source)
    end
    local newPerception = org.runtime.perceptionPressure

    -- Emit pressure updated event if changed
    if DCE and DCE.Emit and newPerception ~= oldPerception then
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
    local spikeThreshold = (Config.AI.PerceptionPressure and Config.AI.PerceptionPressure.SpikeThreshold) or 60
    if newPerception >= spikeThreshold and oldPerception < spikeThreshold then
        if org.ResetPressureCooldown then
            org:ResetPressureCooldown()
        end

        if DCE and DCE.Emit then
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

            if DCE and DCE.Log then
                DCE.Log("ai", "warn", "Organization '%s' perception pressure spiked: %d (visible: %d, covert: %d)", 
                    orgId, newPerception, org.runtime.visiblePressure, org.runtime.covertPressure)
            end
        end
    end
end

---@param orgId string
---@param deltaTime number Time elapsed since last tick (seconds)
function OrganizationsService.DecayPerceptionPressure(orgId, deltaTime)
    local org = organizations[orgId]
    if not org then
        return
    end

    if org.DecayPerceptionPressure then
        org:DecayPerceptionPressure(deltaTime)
    end
end

--- Get perception pressure state for an organization.
---@param orgId string
---@return table|nil { visible, covert, perception, onCooldown }
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
        if StateTransitions and StateTransitions.Evaluate then
            local newState = StateTransitions.Evaluate(org)
            if newState then
                table.insert(transitions, {
                    orgId = orgId,
                    fromState = org.runtime.state,
                    toState = newState,
                })
            end
        end
    end
    return transitions
end

-- ============================================================================
-- Shutdown
-- ============================================================================

function OrganizationsService.Shutdown()
    if DCE and DCE.Log then
        DCE.Log("ai", "info", "Organizations Service shutting down...")
    end
    for orgId, _ in pairs(organizations) do
        organizations[orgId] = nil
    end
    isInitialized = false
    if DCE and DCE.Log then
        DCE.Log("ai", "info", "Organizations Service shutdown complete")
    end
end

_G.DCEOrganizationsService = OrganizationsService