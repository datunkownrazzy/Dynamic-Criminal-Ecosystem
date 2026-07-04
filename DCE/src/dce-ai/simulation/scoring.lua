-- DCE Scoring Engine
-- Computes composite scores for candidate activities.
-- Formula: S = BaseWeight + Sum(Modifiers) - Sum(Deterrents)
-- Spec: docs/08_AI/AIDirector.md

local Scoring = {}

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

--- Compute the score for an activity given an organization and region context.
---@param activity table Activity definition
---@param orgIdentity table Organization identity (personality traits)
---@param orgRuntime table Organization runtime state
---@param regionState table|nil Region state (optional, may be nil if region not found)
---@param timeState table|nil Current time state
---@param weather string|nil Current weather
---@return number score The computed score (0-100)
function Scoring.Compute(activity, orgIdentity, orgRuntime, regionState, timeState, weather)
    local score = activity.baseWeight or 50

    local Config = getConfig()

    -- Personality affinity modifiers
    for traitName, multiplier in pairs(activity.personalityAffinities or {}) do
        local traitValue = orgIdentity.personality[traitName] or 50
        local personalityWeight = 0.25
        if Config.AI and Config.AI.Scoring and Config.AI.Scoring.PersonalityWeight then
            personalityWeight = Config.AI.Scoring.PersonalityWeight
        end
        score = score + ((traitValue - 50) * multiplier * personalityWeight)
    end

    -- Resource-based modifiers
    -- If money is low, increase score for high-payout activities
    local defaultMoney = 10000
    if Config.AI and Config.AI.Organization and Config.AI.Organization.DefaultMoney then
        defaultMoney = Config.AI.Organization.DefaultMoney
    end
    local moneyRatio = orgRuntime.money / defaultMoney
    if moneyRatio < 0.5 then
        -- Desperation: org has low money, increase score for activities that pay well
        local desperationModifier = (1 - moneyRatio) * 10
        local resourceWeight = 1.0
        if Config.AI and Config.AI.Scoring and Config.AI.Scoring.ResourceWeight then
            resourceWeight = Config.AI.Scoring.ResourceWeight
        end
        score = score + (desperationModifier * resourceWeight)
    end

    -- Heat deterrent: higher heat reduces score for high-profile activities
    local heatDeterrent = 0.5
    if Config.AI and Config.AI.Scoring and Config.AI.Scoring.HeatDeterrent then
        heatDeterrent = Config.AI.Scoring.HeatDeterrent
    end
    score = score - (orgRuntime.heat * heatDeterrent)

    -- Environmental modifiers
    if regionState then
        -- Police presence deterrent
        local policeDeterrent = 0.6
        if Config.AI and Config.AI.Scoring and Config.AI.Scoring.PoliceDeterrent then
            policeDeterrent = Config.AI.Scoring.PoliceDeterrent
        end
        score = score - (regionState.policePresence * policeDeterrent)

        -- Gang influence boost
        local orgInfluence = regionState.gangInfluence[orgIdentity.id] or 0
        if orgInfluence > 0 then
            score = score + (orgInfluence * 0.1)
        end
    end

    -- Perception Pressure deterrents (visible and covert enforcement presence)
    if Config.AI and Config.AI.PerceptionPressure and Config.AI.PerceptionPressure.Enabled and regionState then
        -- Safely get enforcement signals with defaults
        local enforcementSignals = regionState.enforcementSignals or {}
        local visiblePressure = enforcementSignals.visible or 0
        local covertPressure = enforcementSignals.covert or 0
        local perceptionPressure = visiblePressure + covertPressure
        
        -- Calculate base deterrents
        local visibleWeight = 0.3
        local covertWeight = 0.4
        if Config.AI.PerceptionPressure.VisibleWeight then
            visibleWeight = Config.AI.PerceptionPressure.VisibleWeight
        end
        if Config.AI.PerceptionPressure.CovertWeight then
            covertWeight = Config.AI.PerceptionPressure.CovertWeight
        end
        
        local visibleDeterrent = visiblePressure * visibleWeight
        local covertDeterrent = covertPressure * covertWeight
        
        -- Apply heat multiplier if organization is already hot
        local heatMultiplier = 1.0
        if orgRuntime.heat > 50 then
            heatMultiplier = Config.AI.PerceptionPressure.HighHeatMultiplier or 0.6
        end
        
        -- Apply deterrents to score
        score = score - (visibleDeterrent * heatMultiplier)
        score = score - (covertDeterrent * heatMultiplier)
        
        -- Threshold-based behavior
        local visibleThreshold = 35
        local covertThreshold = 25
        local spikeThreshold = 60
        if Config.AI.PerceptionPressure.VisibleThreshold then
            visibleThreshold = Config.AI.PerceptionPressure.VisibleThreshold
        end
        if Config.AI.PerceptionPressure.CovertThreshold then
            covertThreshold = Config.AI.PerceptionPressure.CovertThreshold
        end
        if Config.AI.PerceptionPressure.SpikeThreshold then
            spikeThreshold = Config.AI.PerceptionPressure.SpikeThreshold
        end
        
        -- High visible pressure: penalize high-profile activities more heavily
        if visiblePressure >= visibleThreshold then
            if activity.heatOutput and activity.heatOutput > 15 then
                score = score - 10  -- extra penalty for high-heat activities
            end
            if activity.violenceOutput and activity.violenceOutput > 10 then
                score = score - 10  -- extra penalty for violent activities
            end
        end
        
        -- High covert pressure: penalize suspicious or visible activities
        if covertPressure >= covertThreshold then
            if activity.type == "narcotics" or activity.type == "extortion" then
                score = score - 8  -- penalize street-level crimes
            end
        end
        
        -- Spike threshold: strongly reduce aggressive/high-heat activity scores
        if perceptionPressure >= spikeThreshold then
            if orgRuntime.state == "Aggressive Expansion" then
                score = score - 20  -- strong penalty during aggressive expansion
            end
            if activity.heatOutput and activity.heatOutput > 20 then
                score = score - 15  -- very strong penalty for extreme heat activities
            end
        end
    end

    -- Time of day modifier
    if timeState and timeState.isNight then
        -- Night: bonus for activities that benefit from darkness (smuggling, etc.)
        local smugglingAffinity = orgIdentity.personality.smuggling or 50
        if smugglingAffinity > 50 then
            score = score + ((smugglingAffinity - 50) * 0.2)
        end
    end

    -- Weather modifier
    if weather then
        if weather == "RAIN" or weather == "THUNDER" then
            -- Bad weather: fewer witnesses, but more suspicious
            -- Slight bonus for planning-heavy orgs
            local planning = orgIdentity.personality.planning or 50
            if planning > 50 then
                score = score + ((planning - 50) * 0.1)
            end
        end
    end

    -- State-based behavioral unlocks per AI Director spec
    if orgRuntime.state == "Aggressive Expansion" then
        -- Flat +25 weight for turf-related activities
        if activity.type == "narcotics" or activity.type == "extortion" then
            score = score + 25
        end
    elseif orgRuntime.state == "Under Investigation" then
        -- Filter out activities with high heat output
        if activity.heatOutput and activity.heatOutput > 10 then
            score = score - 20 -- strongly penalize
        end
    elseif orgRuntime.state == "Suppressed" or orgRuntime.state == "Dormant" then
        -- Only low-profile activities
        if activity.violenceOutput and activity.violenceOutput > 0 then
            score = score - 30 -- strongly penalize violent activities
        end
    end

    -- Clamp score to 0-100
    score = math.max(0, math.min(100, score))

    return score
end

--- Select an activity from available candidates using weighted lottery.
---@param candidates table Array of { activity, score } tables
---@return table|nil The selected { activity, score }
function Scoring.SelectWeighted(candidates)
    if not candidates or #candidates == 0 then
        return nil
    end

    -- Filter out candidates below minimum score
    local valid = {}
    local minScore = 20
    local Config = getConfig()
    if Config.AI and Config.AI.Scoring and Config.AI.Scoring.MinimumScore then
        minScore = Config.AI.Scoring.MinimumScore
    end
    for _, candidate in ipairs(candidates) do
        if candidate.score >= minScore then
            table.insert(valid, candidate)
        end
    end

    if #valid == 0 then
        return nil
    end

    -- Weighted random selection
    local totalWeight = 0
    for _, candidate in ipairs(valid) do
        totalWeight = totalWeight + candidate.score
    end

    local roll = math.random() * totalWeight
    local cumulative = 0

    for _, candidate in ipairs(valid) do
        cumulative = cumulative + candidate.score
        if roll <= cumulative then
            return candidate
        end
    end

    -- Fallback: return last candidate
    return valid[#valid]
end

_G.DCEScoring = Scoring