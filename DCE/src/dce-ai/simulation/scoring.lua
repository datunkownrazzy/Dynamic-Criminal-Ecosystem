-- DCE Scoring Engine
-- Computes composite scores for candidate activities.
-- Formula: S = BaseWeight + Sum(Modifiers) - Sum(Deterrents)
-- Spec: docs/08_AI/AIDirector.md

local Scoring = {}

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

    -- Personality affinity modifiers
    for traitName, multiplier in pairs(activity.personalityAffinities or {}) do
        local traitValue = orgIdentity.personality[traitName] or 50
        score = score + ((traitValue - 50) * multiplier * Config.AI.Scoring.PersonalityWeight)
    end

    -- Resource-based modifiers
    -- If money is low, increase score for high-payout activities
    local moneyRatio = orgRuntime.money / Config.AI.Organization.DefaultMoney
    if moneyRatio < 0.5 then
        -- Desperation: org has low money, increase score for activities that pay well
        local desperationModifier = (1 - moneyRatio) * 10
        score = score + (desperationModifier * Config.AI.Scoring.ResourceWeight)
    end

    -- Heat deterrent: higher heat reduces score for high-profile activities
    local heatDeterrent = orgRuntime.heat * Config.AI.Scoring.HeatDeterrent
    score = score - heatDeterrent

    -- Environmental modifiers
    if regionState then
        -- Police presence deterrent
        local policeDeterrent = regionState.policePresence * Config.AI.Scoring.PoliceDeterrent
        score = score - policeDeterrent

        -- Gang influence boost
        local orgInfluence = regionState.gangInfluence[orgIdentity.id] or 0
        if orgInfluence > 0 then
            score = score + (orgInfluence * 0.1)
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
    for _, candidate in ipairs(candidates) do
        if candidate.score >= Config.AI.Scoring.MinimumScore then
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

return Scoring