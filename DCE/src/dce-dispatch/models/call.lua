-- DCE Dispatch Call Model
-- Represents a single dispatch call.

local Call = {}
Call.__index = Call

local callCounter = 0

Call.Statuses = {
    Pending = "pending",
    Active = "active",
    Resolved = "resolved",
    Cancelled = "cancelled",
}

--- Create a new Dispatch Call.
---@param data table { incidentId, description, regionId, priority?, organizationId?, scenarioId? }
---@return table Call instance
function Call.New(data)
    callCounter = callCounter + 1
    local self = setmetatable({}, Call)

    self.id = "call-" .. callCounter
    self.incidentId = data.incidentId
    self.description = data.description or "Unspecified incident"
    self.regionId = data.regionId
    self.priority = data.priority or Config.Dispatch.DefaultPriority
    self.organizationId = data.organizationId
    self.scenarioId = data.scenarioId
    self.status = Call.Statuses.Pending
    self.createdAt = os.time()
    self.updatedAt = os.time()
    self.resolvedAt = nil
    self.disposition = nil
    self.updates = {}  -- array of update strings

    return self
end

--- Activate the call.
function Call:Activate()
    self.status = Call.Statuses.Active
    self.updatedAt = os.time()
end

--- Resolve the call with a disposition.
---@param disposition string How the call was resolved
function Call:Resolve(disposition)
    self.status = Call.Statuses.Resolved
    self.disposition = disposition
    self.resolvedAt = os.time()
    self.updatedAt = os.time()
end

--- Cancel the call.
function Call:Cancel()
    self.status = Call.Statuses.Cancelled
    self.updatedAt = os.time()
end

--- Add an update to the call.
---@param updateText string
function Call:AddUpdate(updateText)
    table.insert(self.updates, {
        text = updateText,
        timestamp = os.time(),
    })
    self.updatedAt = os.time()
end

--- Get a summary of the call.
---@return table
function Call:GetSummary()
    return {
        id = self.id,
        incidentId = self.incidentId,
        description = self.description,
        regionId = self.regionId,
        priority = self.priority,
        organizationId = self.organizationId,
        scenarioId = self.scenarioId,
        status = self.status,
        createdAt = self.createdAt,
        updatedAt = self.updatedAt,
        resolvedAt = self.resolvedAt,
        disposition = self.disposition,
        updateCount = #self.updates,
    }
end

--- Check if the call has timed out.
---@return boolean
function Call:HasTimedOut()
    if self.status ~= "pending" and self.status ~= "active" then
        return false
    end
    local elapsed = os.time() - self.createdAt
    return elapsed >= Config.Dispatch.CallTimeout
end

return Call