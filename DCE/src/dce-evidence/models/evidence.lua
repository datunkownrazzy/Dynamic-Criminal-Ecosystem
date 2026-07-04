-- DCE Evidence Model
-- Represents a single evidence item in the registry.

local Evidence = {}
Evidence.__index = Evidence

local evidenceCounter = 0

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

--- Create a new Evidence item.
---@param data table { type, description, source, organizationId?, scenarioId?, regionId?, confidence? }
---@return table Evidence instance
function Evidence.New(data)
    local Config = getConfig()
    evidenceCounter = evidenceCounter + 1
    local self = setmetatable({}, Evidence)

    self.id = "ev-" .. evidenceCounter
    self.type = data.type or "physical"
    
    local defaultType = "physical"
    local confidenceLow = 25
    local decayInterval = 3600
    local decayRate = 5
    
    if Config.Evidence then
        if Config.Evidence.Types and Config.Evidence.Types.Physical then
            defaultType = Config.Evidence.Types.Physical
        end
        if Config.Evidence.Confidence and Config.Evidence.Confidence.Low then
            confidenceLow = Config.Evidence.Confidence.Low
        end
        if Config.Evidence.DecayInterval then
            decayInterval = Config.Evidence.DecayInterval
        end
        if Config.Evidence.DecayRate then
            decayRate = Config.Evidence.DecayRate
        end
    end
    
    if self.type == "physical" and defaultType ~= "physical" then
        self.type = defaultType
    end
    
    self.description = data.description or "Unspecified evidence"
    self.source = data.source or "unknown"
    self.organizationId = data.organizationId
    self.scenarioId = data.scenarioId
    self.regionId = data.regionId
    self.confidence = data.confidence or confidenceLow
    self._decayInterval = decayInterval
    self._decayRate = decayRate
    self.verified = false
    self.createdAt = os.time()
    self.lastUpdatedAt = os.time()
    self.caseId = nil  -- linked investigation case
    self.metadata = data.metadata or {}

    return self
end

--- Get a summary of this evidence item.
---@return table
function Evidence:GetSummary()
    return {
        id = self.id,
        type = self.type,
        description = self.description,
        source = self.source,
        organizationId = self.organizationId,
        scenarioId = self.scenarioId,
        regionId = self.regionId,
        confidence = self.confidence,
        verified = self.verified,
        createdAt = self.createdAt,
        lastUpdatedAt = self.lastUpdatedAt,
        caseId = self.caseId,
    }
end

--- Update the confidence level.
---@param newConfidence number
function Evidence:SetConfidence(newConfidence)
    self.confidence = math.max(0, math.min(100, newConfidence))
    self.lastUpdatedAt = os.time()
end

--- Mark as verified.
function Evidence:Verify()
    self.verified = true
    self.lastUpdatedAt = os.time()
end

--- Link to an investigation case.
---@param caseId string
function Evidence:LinkToCase(caseId)
    self.caseId = caseId
    self.lastUpdatedAt = os.time()
end

--- Apply confidence decay over time.
function Evidence:ApplyDecay()
    local elapsed = os.time() - self.lastUpdatedAt
    if elapsed >= self._decayInterval then
        local decayCycles = math.floor(elapsed / self._decayInterval)
        local decay = decayCycles * self._decayRate
        self:SetConfidence(self.confidence - decay)
    end
end

_G.DCEEvidence = Evidence