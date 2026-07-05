-- DCE Organization State Transitions
-- Logic governing when an organization transitions between states.
-- Spec: docs/08_AI/AIDirector.md

local StateTransitions = {}

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

--- Evaluate and apply state transitions for an organization.
---@param org table Organization instance
---@return string|nil New state if transition occurred, nil otherwise
function StateTransitions.Evaluate(org)
    local currentState = org.runtime.state
    local newState = nil

    if currentState == "Dormant" then
        -- Dormant -> Growing: when org has enough members and money
        local Config = getConfig()
        local membersThreshold = 10
        local moneyThreshold = 5000
        if Config.AI and Config.AI.StateTransitions and Config.AI.StateTransitions.DormantToGrowing then
            membersThreshold = Config.AI.StateTransitions.DormantToGrowing.MembersThreshold or membersThreshold
            moneyThreshold = Config.AI.StateTransitions.DormantToGrowing.MoneyThreshold or moneyThreshold
        end
        if org.runtime.members >= membersThreshold and org.runtime.money >= moneyThreshold then
            newState = "Growing"
        end

    elseif currentState == "Growing" then
        -- Growing -> Stable: when org has established territory and members
        local territoryCount = 0
        for _, _ in pairs(org.runtime.territories) do
            territoryCount = territoryCount + 1
        end
        
        local Config = getConfig()
        local minTerritory = 1
        local membersThreshold = 15
        local minMorale = 50
        if Config.AI and Config.AI.StateTransitions and Config.AI.StateTransitions.GrowingToStable then
            minTerritory = Config.AI.StateTransitions.GrowingToStable.TerritoryCount or minTerritory
            membersThreshold = Config.AI.StateTransitions.GrowingToStable.MembersThreshold or membersThreshold
            minMorale = Config.AI.StateTransitions.GrowingToStable.MinMorale or minMorale
        end
        
        if territoryCount >= minTerritory and org.runtime.members >= membersThreshold and org.runtime.morale >= minMorale then
            newState = "Stable"
        end

    elseif currentState == "Stable" then
        -- Stable -> Aggressive Expansion: money > 150% baseline, morale > 70, heat < 40
        local Config = getConfig()
        local thresholds = {
            MoneyRatio = 1.5,
            MinMorale = 70,
            MaxHeat = 40,
        }
        if Config.AI and Config.AI.StateTransitions and Config.AI.StateTransitions.StableToAggressive then
            thresholds = Config.AI.StateTransitions.StableToAggressive
        end
        
        local defaultMoney = 10000
        if Config.AI and Config.AI.Organization and Config.AI.Organization.DefaultMoney then
            defaultMoney = Config.AI.Organization.DefaultMoney
        end
        
        local moneyRatio = org.runtime.money / defaultMoney
        if moneyRatio >= thresholds.MoneyRatio
            and org.runtime.morale >= thresholds.MinMorale
            and org.runtime.heat <= thresholds.MaxHeat then
            newState = "Aggressive Expansion"
        end

    elseif currentState == "Aggressive Expansion" then
        -- Aggressive Expansion -> Conflict: triggered by external events (handled via event)
        -- Aggressive Expansion -> Stable: if heat gets too high or morale drops
        local Config = getConfig()
        local maxHeat = 60
        local minMorale = 40
        if Config.AI and Config.AI.StateTransitions and Config.AI.StateTransitions.AggressiveToStable then
            maxHeat = Config.AI.StateTransitions.AggressiveToStable.MaxHeat or maxHeat
            minMorale = Config.AI.StateTransitions.AggressiveToStable.MinMorale or minMorale
        end
        if org.runtime.heat > maxHeat or org.runtime.morale < minMorale then
            newState = "Stable"
        end

    elseif currentState == "Under Investigation" then
        -- Under Investigation -> Suppressed: triggered by major raid (handled via event)
        -- Under Investigation -> Stable: if intelligence drops below threshold
        local Config = getConfig()
        local underInvestigationThreshold = 20
        if Config.AI and Config.AI.StateTransitions and Config.AI.StateTransitions.UnderInvestigationThreshold then
            underInvestigationThreshold = Config.AI.StateTransitions.UnderInvestigationThreshold
        end
        if org.runtime.intelligence < underInvestigationThreshold then
            newState = "Stable"
        end

    elseif currentState == "Suppressed" then
        -- Suppressed -> Recovering: heat below threshold and cooldown elapsed
        local Config = getConfig()
        local suppressedHeatDecay = 30
        local suppressedCooldownMinutes = 15
        if Config.AI and Config.AI.StateTransitions then
            if Config.AI.StateTransitions.SuppressedHeatDecay then
                suppressedHeatDecay = Config.AI.StateTransitions.SuppressedHeatDecay
            end
            if Config.AI.StateTransitions.SuppressedCooldownMinutes then
                suppressedCooldownMinutes = Config.AI.StateTransitions.SuppressedCooldownMinutes
            end
        end
        
        if org.runtime.heat <= suppressedHeatDecay then
            local cooldownSeconds = suppressedCooldownMinutes * 60
            local timeSinceSuppressed = os.time() - org.runtime.suppressedSince
            if timeSinceSuppressed >= cooldownSeconds then
                newState = "Recovering"
            end
        end

    elseif currentState == "Recovering" then
        -- Recovering -> Growing: when org has rebuilt enough
        local Config = getConfig()
        local membersThreshold = 15
        local moneyThreshold = 10000
        local minMorale = 50
        if Config.AI and Config.AI.StateTransitions and Config.AI.StateTransitions.RecoveringToGrowing then
            membersThreshold = Config.AI.StateTransitions.RecoveringToGrowing.MembersThreshold or membersThreshold
            moneyThreshold = Config.AI.StateTransitions.RecoveringToGrowing.MoneyThreshold or moneyThreshold
            minMorale = Config.AI.StateTransitions.RecoveringToGrowing.MinMorale or minMorale
        end
        
        if org.runtime.members >= membersThreshold and org.runtime.money >= moneyThreshold and org.runtime.morale >= minMorale then
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

_G.DCEStateTransitions = StateTransitions