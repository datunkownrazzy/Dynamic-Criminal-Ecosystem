-- DCE Chain of Custody Model
-- Tracks every transfer of an evidence item.

local Custody = {}
Custody.__index = Custody

local custodyCounter = 0

--- Create a new custody record.
---@param evidenceId string
---@param from string Previous holder
---@param to string New holder
---@param reason string Reason for transfer
---@return table Custody record
function Custody.New(evidenceId, from, to, reason)
    custodyCounter = custodyCounter + 1
    local self = setmetatable({}, Custody)

    self.id = "custody-" .. custodyCounter
    self.evidenceId = evidenceId
    self.from = from
    self.to = to
    self.reason = reason or "Transfer"
    self.timestamp = os.time()

    return self
end

--- Get a summary of this custody record.
---@return table
function Custody:GetSummary()
    return {
        id = self.id,
        evidenceId = self.evidenceId,
        from = self.from,
        to = self.to,
        reason = self.reason,
        timestamp = self.timestamp,
    }
end

return Custody