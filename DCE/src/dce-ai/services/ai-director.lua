-- DCE AI Director Service
-- Operational logic center: evaluates world state and organization state,
-- scores activities, and selects what organizations do.
-- Spec: docs/08_AI/AIDirector.md

local Activity = require("models.activity")
local Scoring = require("simulation.scoring")
local OrganizationsService = require("services.organizations")

local AIDirectorService = {}
local activities = {}     -- activityId -> Activity definition
local activeDecisions = {} -- orgId -> current decision state
local currentOrgIndex = 1
local isInitialized = false

--- Initialize the AI Director.
function AIDirectorService.Initialize()
    if isInitialized then
        return
    end

    DCE:Log("ai", "info", "AI Director initializing...")

    -- Load activity definitions
    local activityData = require("data.activities")
    for id, data in pairs(activityData) do
        activities[id] = Activity.New(id, data)
        DCE:Log("ai", "info", "  Activity loaded: %s", id)
    end

    DCE:Log("ai", "info", "AI Director initialized with %d activity types", #activityData)
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

    local orgIds = OrganizationsService.GetAllOrgIds()
    if #orgIds == 0 then
        return nil
    end

    -- Time-sliced: process one org per tick (round-robin)
    if currentOrgIndex > #orgIds then
        currentOrgIndex = 1
    end

    local orgId = orgIds[currentOrgIndex]
    currentOrgIndex = currentOrgIndex + 1

    return AIDirectorService.EvaluateOrganization(orgId)
end

--- Evaluate a single organization for possible activity decisions.
---@param orgId string
---@return table|nil The decision made { organizationId, activityId, regionId, score, activity }
function AIDirectorService.EvaluateOrganization(orgId)
    local org = OrganizationsService.GetOrgInstance(orgId)
    if not org then
        return nil
    end

    local orgIdentity = org:GetIdentity()
    local orgState = org:GetState()

    -- Get world state context
    local World = DCE:GetService("World")
    if not World then
        return nil
    end

    local timeState = World.GetTime()
    local weather = World.GetWeather()

    -- Score each available activity
    local candidates = {}
    for activityId, activityDef in pairs(activities) do
        -- Check state-based availability
        if activityDef:IsAvailable(orgState.state) and activityDef:MeetsRequirements(orgState) then
            -- Check which regions this org has influence in
            local regionIds = World.GetAllRegionIds()
            local bestScore = 0
            local bestRegionId = nil

            for _, regionId in ipairs(regionIds) do
                local regionState = World.GetRegionState(regionId)
                local score = Scoring.Compute(activityDef, orgIdentity, orgState, regionState, timeState, weather)

                if score > bestScore then
                    bestScore = score
                    bestRegionId = regionId
                end
            end

            if bestScore >= Config.AI.Scoring.MinimumScore then
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

    local selected = Scoring.SelectWeighted(candidates)
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
    DCE:Emit("organization:activity:started", {
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

    DCE:Log("ai", "info", "AI Director: %s selected '%s' in %s (score: %d)",
        orgId, selected.activityId, selected.regionId, selected.score)

    return decision
end

-- ============================================================================
-- AI Director Events
-- ============================================================================

--- Emit AI Director event for decision executed.
---@param decision table
function AIDirectorService.EmitDecisionExecuted(decision)
    DCE:Emit("ai:director:decision:executed", {
        eventName = "ai:director:decision:executed",
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-ai",
        payload = decision,
    })
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
    DCE:Log("ai", "info", "AI Director shutting down...")
    for orgId, _ in pairs(activeDecisions) do
        activeDecisions[orgId] = nil
    end
    isInitialized = false
    DCE:Log("ai", "info", "AI Director shutdown complete")
end

return AIDirectorService