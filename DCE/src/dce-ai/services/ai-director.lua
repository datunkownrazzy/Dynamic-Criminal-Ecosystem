-- DCE AI Director Service
-- Operational logic center: evaluates world state and organization state,
-- scores activities, and selects what organizations do.
-- Spec: docs/08_AI/AIDirector.md

-- Get modules safely from _G
local function getModule(name)
    return _G[name] or {}
end

local Activity = getModule("DCEActivity")
local Scoring = getModule("DCEScoring")
local OrganizationsService = getModule("DCEOrganizationsService")
local DCEActivities = getModule("DCEActivities")

local AIDirectorService = {}
local activities = {}     -- activityId -> Activity definition
local activeDecisions = {} -- orgId -> current decision state
local currentOrgIndex = 1
local isInitialized = false

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

--- Initialize the AI Director.
function AIDirectorService.Initialize()
    if isInitialized then
        return
    end

    if DCE and DCE.Log then
        DCE.Log("ai", "info", "AI Director initializing...")
    end

    -- Load activity definitions
    local activityData = DCEActivities
    for id, data in pairs(activityData) do
        if Activity.New then
            activities[id] = Activity.New(id, data)
            if DCE and DCE.Log then
                DCE.Log("ai", "info", "  Activity loaded: %s", id)
            end
        end
    end

    if DCE and DCE.Log then
        DCE.Log("ai", "info", "AI Director initialized with %d activity types", #activityData)
    end
    isInitialized = true
end

-- ============================================================================
-- Service Interface
-- ============================================================================

--- Execute the AI Director's scoring pass for one organization (time-sliced).
--- This is called on each tick, processing one organization at a time.
---@return table|nil The decision made, if any { organizationId, activityId, regionId, score }
function AIDirectorService.Tick()
    if not isInitialized then
        return nil
    end

    local orgIds = OrganizationsService.GetAllOrgIds and OrganizationsService.GetAllOrgIds()
    if not orgIds or #orgIds == 0 then
        return nil
    end

    -- Time-sliced: process one org per tick (round-robin)
    if currentOrgIndex > #orgIds then
        currentOrgIndex = 1
    end

    local orgId = orgIds[currentOrgIndex]
    currentOrgIndex = currentOrgIndex + 1

    -- Decay perception pressure for this organization
    local Config = getConfig()
    local tickInterval = (Config.AI and Config.AI.DirectorTickInterval) or 5000
    local deltaTime = tickInterval / 1000.0  -- convert ms to seconds
    if OrganizationsService.DecayPerceptionPressure then
        OrganizationsService.DecayPerceptionPressure(orgId, deltaTime)
    end

    return AIDirectorService.EvaluateOrganization(orgId)
end

--- Evaluate a single organization for possible activity decisions.
---@param orgId string
---@return table|nil The decision made { organizationId, activityId, regionId, score, activity }
function AIDirectorService.EvaluateOrganization(orgId)
    local org = OrganizationsService.GetOrgInstance and OrganizationsService.GetOrgInstance(orgId)
    if not org then
        return nil
    end

    local orgIdentity = org:GetIdentity()
    local orgState = org:GetState()

    -- Get world state context
    local World = DCE and DCE.GetService and DCE.GetService("World")
    if not World then
        return nil
    end

    local timeState = World.GetTime and World.GetTime()
    local weather = World.GetWeather and World.GetWeather()

    -- Score each available activity
    local candidates = {}
    for activityId, activityDef in pairs(activities) do
        -- Check state-based availability
        if activityDef and activityDef.IsAvailable and activityDef.IsAvailable(orgState.state) and 
           activityDef.MeetsRequirements and activityDef.MeetsRequirements(orgState) then
            -- Check which regions this org has influence in
            local regionIds = World.GetAllRegionIds and World.GetAllRegionIds()
            local bestScore = 0
            local bestRegionId = nil

            for _, regionId in ipairs(regionIds) do
                local regionState = World.GetRegionState and World.GetRegionState(regionId)
                if Scoring and Scoring.Compute then
                    local score = Scoring.Compute(activityDef, orgIdentity, orgState, regionState, timeState, weather)

                    if score > bestScore then
                        bestScore = score
                        bestRegionId = regionId
                    end
                end
            end

            local minScore = 20  -- default
            local Config = getConfig()
            if Config.AI and Config.AI.Scoring and Config.AI.Scoring.MinimumScore then
                minScore = Config.AI.Scoring.MinimumScore
            end
            if bestScore >= minScore then
                table.insert(candidates, {
                    activityId = activityId,
                    activity = activityDef,
                    regionId = bestRegionId,
                    score = bestScore,
                })
            end
        end
    end

    -- Select from candidates using weighted lottery
    if #candidates == 0 then
        return nil
    end

    local selected = (Scoring and Scoring.SelectWeighted) and Scoring.SelectWeighted(candidates)
    if not selected then
        return nil
    end

    -- Record the decision
    activeDecisions[orgId] = {
        activityId = selected.activityId,
        regionId = selected.regionId,
        score = selected.score,
        startedAt = os.time(),
    }

    local decision = {
        organizationId = orgId,
        activityId = selected.activityId,
        regionId = selected.regionId,
        score = selected.score,
    }

    -- Emit the decision event
    if DCE and DCE.Emit then
        DCE.Emit("organization:activity:started", {
            eventName = "organization:activity:started",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-ai",
            correlationId = orgId .. ":" .. selected.activityId .. ":" .. os.time(),
            payload = {
                organizationId = orgId,
                activity = selected.activityId,
                location = selected.regionId,
                layer = 1,
                score = selected.score,
            },
        })
    end

    if DCE and DCE.Log then
        DCE.Log("ai", "info", "AI Director: %s selected '%s' in %s (score: %d)",
            orgId, selected.activityId, selected.regionId, selected.score)
    end

    return decision
end

-- ============================================================================
-- AI Director Events
-- ============================================================================

--- Emit AI Director event for decision executed.
---@param decision table
function AIDirectorService.EmitDecisionExecuted(decision)
    if DCE and DCE.Emit then
        DCE.Emit("ai:director:decision:executed", {
            eventName = "ai:director:decision:executed",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-ai",
            payload = decision,
        })
    end
end

--- Get the active decision for an organization, if any.
---@param orgId string
---@return table|nil
function AIDirectorService.GetActiveDecision(orgId)
    return activeDecisions[orgId]
end

--- Clear the active decision for an organization (when scenario completes).
---@param orgId string
function AIDirectorService.ClearDecision(orgId)
    activeDecisions[orgId] = nil
end

-- ============================================================================
-- Shutdown
-- ============================================================================

function AIDirectorService.Shutdown()
    if DCE and DCE.Log then
        DCE.Log("ai", "info", "AI Director shutting down...")
    end
    for orgId, _ in pairs(activeDecisions) do
        activeDecisions[orgId] = nil
    end
    isInitialized = false
    if DCE and DCE.Log then
        DCE.Log("ai", "info", "AI Director shutdown complete")
    end
end

_G.DCEAIDirectorService = AIDirectorService