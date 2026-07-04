-- DCE Organization State Transitions
-- Logic governing when an organization transitions between states.
-- Spec: docs/08_AI/AIDirector.md

local StateTransitions = {}

--- Evaluate and apply state transitions for an organization.
---@param org table Organization instance
---@return string|nil New state if transition occurred, nil otherwise
function StateTransitions.Evaluate(org)
    local currentState = org.runtime.state
    local newState = nil

    if currentState == "Dormant" then
        -- Dormant -> Growing: when org has enough members and money
        if org.runtime.members >= 10 and org.runtime.money >= 5000 then
            newState = "Growing"
        end

    elseif currentState == "Growing" then
        -- Growing -> Stable: when org has established territory and members
        local territoryCount = 0
        for _, _ in pairs(org.runtime.territories) do
            territoryCount = territoryCount + 1
        end
        if territoryCount >= 1 and org.runtime.members >= 15 and org.runtime.morale >= 50 then
            newState = "Stable"
        end

    elseif currentState == "Stable" then
        -- Stable -> Aggressive Expansion: money > 150% baseline, morale > 70, heat < 40
        local thresholds = Config.AI.StateTransitions.StableToAggressive
        local moneyRatio = org.runtime.money / Config.AI.Organization.DefaultMoney
        if moneyRatio >= thresholds.MoneyRatio
            and org.runtime.morale >= thresholds.MinMorale
            and org.runtime.heat <= thresholds.MaxHeat then
            newState = "Aggressive Expansion"
        end

    elseif currentState == "Aggressive Expansion" then
        -- Aggressive Expansion -> Conflict: triggered by external events (handled via event)
        -- Aggressive Expansion -> Stable: if heat gets too high or morale drops
        if org.runtime.heat > 60 or org.runtime.morale < 40 then
            newState = "Stable"
        end

    elseif currentState == "Under Investigation" then
        -- Under Investigation -> Suppressed: triggered by major raid (handled via event)
        -- Under Investigation -> Stable: if intelligence drops below threshold
        if org.runtime.intelligence < Config.AI.StateTransitions.UnderInvestigationThreshold then
            newState = "Stable"
        end

    elseif currentState == "Suppressed" then
        -- Suppressed -> Recovering: heat below threshold and cooldown elapsed
        if org.runtime.heat <= Config.AI.StateTransitions.SuppressedHeatDecay then
            local cooldownSeconds = Config.AI.StateTransitions.SuppressedCooldownMinutes * 60
            local timeSinceSuppressed = os.time() - org.runtime.suppressedSince
            if timeSinceSuppressed >= cooldownSeconds then
                newState = "Recovering"
            end
        end

    elseif currentState == "Recovering" then
        -- Recovering -> Growing: when org has rebuilt enough
        if org.runtime.members >= 15 and org.runtime.money >= 10000 and org.runtime.morale >= 50 then
            newState = "Growing"
        end
    end

    if newState then
        org:SetState(newState)
    end

    return newState
end

--- Force a state transition (used by event handlers for external triggers).
---@param org table Organization instance
---@param newState string Target state
---@return boolean success
function StateTransitions.ForceTransition(org, newState)
    return org:SetState(newState)
end

return StateTransitions