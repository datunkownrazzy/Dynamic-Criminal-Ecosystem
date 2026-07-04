-- DCE Scenario Model
-- Represents a single active scenario instance with its lifecycle state.

local Scenario = {}
Scenario.__index = Scenario

-- Stage progression order
Scenario.Stages = {
    "Planning",
    "Travel",
    "Preparation",
    "Execution",
    "Reaction",
    "Escape",
    "Resolution",
}

-- Possible scenario statuses
Scenario.Statuses = {
    Active = "Active",
    Completed = "Completed",
    Failed = "Failed",
    Interdicted = "Interdicted",
    TimedOut = "Timed Out",
}

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

--- Create a new Scenario instance.
---@param id string Unique scenario ID
---@param data table Scenario definition data
---@return table Scenario instance
function Scenario.New(id, data)
    local self = setmetatable({}, Scenario)

    local Config = getConfig()
    local defaultStages = {"Planning", "Travel", "Preparation", "Execution", "Reaction", "Escape", "Resolution"}
    local stageDurations = {
        Planning = 30,
        Travel = 60,
        Preparation = 120,
        Execution = 180,
        Reaction = 60,
        Escape = 120,
        Resolution = 30,
    }
    local dispatchTriggerStages = {"Execution", "Reaction"}
    local scenarioTimeout = 1800

    if Config.Scenario then
        if Config.Scenario.Default then
            defaultStages = Config.Scenario.Default.Stages or defaultStages
        end
        if Config.Scenario.StageDurations then
            stageDurations = Config.Scenario.StageDurations
        end
        if Config.Scenario.Escalation then
            dispatchTriggerStages = Config.Scenario.Escalation.DispatchTriggerStages or dispatchTriggerStages
            scenarioTimeout = Config.Scenario.Escalation.ScenarioTimeout or scenarioTimeout
        end
    end

    self.id = id
    self.type = data.type or "Unknown"
    self.displayName = data.displayName or "Activity"
    self.organizationId = data.organizationId
    self.regionId = data.regionId
    self.activityId = data.activityId

    -- Stage tracking
    self.stages = data.stages or defaultStages
    self.currentStageIndex = 1
    self.currentStage = self.stages[1]
    self.stageStartedAt = os.time()
    self.stageDurations = {}

    -- Initialize stage durations from config
    for _, stageName in ipairs(self.stages) do
        self.stageDurations[stageName] = stageDurations[stageName] or 30
    end

    -- Status
    self.status = Scenario.Statuses.Active
    self.createdAt = os.time()
    self.completedAt = nil
    self.layer = 1  -- starts at Layer 1 (ambient), escalates to 2/3

    -- Impact tracking
    self.heatGenerated = 0
    self.violenceGenerated = 0
    self.evidenceGenerated = 0
    self.dispatchTriggered = false
    self.dispatchCallId = nil

    -- Metadata
    self.metadata = data.metadata or {}

    -- Store for later use
    self._dispatchTriggerStages = dispatchTriggerStages
    self._scenarioTimeout = scenarioTimeout

    return self
end

--- Get the current stage name.
---@return string
function Scenario:GetCurrentStage()
    return self.currentStage
end

--- Get the current stage index (1-based).
---@return number
function Scenario:GetStageIndex()
    return self.currentStageIndex
end

--- Get the total number of stages.
---@return number
function Scenario:GetStageCount()
    return #self.stages
end

--- Get the progress through the current stage (0.0 to 1.0).
---@return number
function Scenario:GetStageProgress()
    local elapsed = os.time() - self.stageStartedAt
    local duration = self.stageDurations[self.currentStage] or 30
    return math.min(1.0, elapsed / duration)
end

--- Check if the current stage is complete.
---@return boolean
function Scenario:IsStageComplete()
    return self:GetStageProgress() >= 1.0
end

--- Advance to the next stage.
---@return string|nil The new stage name, or nil if already at the last stage
function Scenario:AdvanceStage()
    if self.currentStageIndex >= #self.stages then
        return nil
    end

    self.currentStageIndex = self.currentStageIndex + 1
    self.currentStage = self.stages[self.currentStageIndex]
    self.stageStartedAt = os.time()

    return self.currentStage
end

--- Check if this scenario has reached a dispatch-triggering stage.
---@return boolean
function Scenario:IsDispatchTriggered()
    if self.dispatchTriggered then
        return true
    end

    for _, triggerStage in ipairs(self._dispatchTriggerStages) do
        if self.currentStage == triggerStage then
            self.dispatchTriggered = true
            return true
        end
    end

    return false
end

--- Check if the scenario has timed out.
---@return boolean
function Scenario:HasTimedOut()
    local elapsed = os.time() - self.createdAt
    return elapsed >= self._scenarioTimeout
end

--- Complete the scenario with a given status.
---@param status string One of Scenario.Statuses
function Scenario:Complete(status)
    self.status = status
    self.completedAt = os.time()
end

--- Get a summary of the scenario state.
---@return table
function Scenario:GetSummary()
    return {
        id = self.id,
        type = self.type,
        displayName = self.displayName,
        organizationId = self.organizationId,
        regionId = self.regionId,
        currentStage = self.currentStage,
        stageIndex = self.currentStageIndex,
        stageCount = #self.stages,
        stageProgress = self:GetStageProgress(),
        status = self.status,
        layer = self.layer,
        heatGenerated = self.heatGenerated,
        violenceGenerated = self.violenceGenerated,
        evidenceGenerated = self.evidenceGenerated,
        dispatchTriggered = self.dispatchTriggered,
        createdAt = self.createdAt,
        completedAt = self.completedAt,
    }
end

_G.DCEScenario = Scenario