-- DCE Evidence Factory
-- Prepares evidence candidates from scenario activity for registration.
-- Scenarios request evidence creation; the Evidence Factory prepares the data.

local EvidenceFactory = {}

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

--- Create evidence from a scenario completion event.
---@param scenarioData table { scenarioId, organizationId, regionId, activityId, heatGenerated, violenceGenerated }
---@return table|nil Evidence data ready for EvidenceService.CreateEvidence
function EvidenceFactory.FromScenarioCompletion(scenarioData)
    if not scenarioData then
        return nil
    end

    local Config = getConfig()
    local evidenceType = "physical"
    local description = "Evidence recovered from scenario activity"

    -- Determine evidence type based on activity
    if scenarioData.activityId == "drug_sale" then
        evidenceType = "physical"
        description = "Drug paraphernalia and related materials"
    elseif scenarioData.activityId == "procurement_run" then
        evidenceType = "physical"
        description = "Illegal goods and transport documentation"
    elseif scenarioData.violenceGenerated and scenarioData.violenceGenerated > 0 then
        evidenceType = "forensic"
        description = "Forensic evidence from violent incident"
    end

    local defaultConfidence = 25
    if Config.Evidence and Config.Evidence.Factory and Config.Evidence.Factory.DefaultScenarioConfidence then
        defaultConfidence = Config.Evidence.Factory.DefaultScenarioConfidence
    end

    return {
        type = evidenceType,
        description = description,
        source = "simulation",
        organizationId = scenarioData.organizationId,
        scenarioId = scenarioData.scenarioId,
        regionId = scenarioData.regionId,
        confidence = defaultConfidence,
        metadata = {
            activityId = scenarioData.activityId,
            heatGenerated = scenarioData.heatGenerated or 0,
            violenceGenerated = scenarioData.violenceGenerated or 0,
        },
    }
end

--- Create evidence from a dispatch call.
---@param dispatchData table { callId, incidentId, description, regionId, organizationId? }
---@return table|nil Evidence data
function EvidenceFactory.FromDispatchCall(dispatchData)
    if not dispatchData then
        return nil
    end

    local Config = getConfig()
    local defaultConfidence = 30
    if Config.Evidence and Config.Evidence.Factory and Config.Evidence.Factory.DefaultDispatchConfidence then
        defaultConfidence = Config.Evidence.Factory.DefaultDispatchConfidence
    end

    return {
        type = "digital",
        description = "Dispatch call record: " .. (dispatchData.description or "Unknown"),
        source = "dispatch",
        organizationId = dispatchData.organizationId,
        regionId = dispatchData.regionId,
        confidence = defaultConfidence,
        metadata = {
            callId = dispatchData.callId,
            incidentId = dispatchData.incidentId,
        },
    }
end

_G.DCEEvidenceFactory = EvidenceFactory