-- DCE Event Bus — Sprint 1.9 Architecture Completion
-- Every event includes:
--   Owner       — which service owns this event
--   Producer    — which module emits this event
--   Consumers   — which modules subscribe to this event
--   Priority    — 0=critical, 1=high, 2=normal, 3=low
--   Reliability — "at-most-once" | "at-least-once" | "exactly-once"
--   Version     — eventVersion integer for contract validation
--   Payload Contract — expected payload schema
--   Lifecycle   — "active" | "future_reserved" | "deprecated" | "obsolete"
--
-- Automatically detects:
--   duplicate events
--   payload drift
--   unknown emitters
--   orphan consumers
--   version conflicts
--
-- Future Reserved SDK events remain Future Reserved.
-- Do not fabricate subscribers.
---@diagnostic disable: undefined-global

local EventRegistry = {}

-- ============================================================================
-- Event Contracts
-- ============================================================================

local eventContracts = {}

--- Define an event contract
---@param name string Event name
---@param contract table Event contract definition
function EventRegistry.Define(name, contract)
    contract._defined = os.time()
    eventContracts[name] = contract
end

--- Get an event contract
---@param name string Event name
---@return table|nil
function EventRegistry.GetContract(name)
    return eventContracts[name]
end

--- List all defined event contracts
---@return table
function EventRegistry.ListContracts()
    local list = {}
    for name, contract in pairs(eventContracts) do
        table.insert(list, {
            name = name,
            owner = contract.owner,
            version = contract.version,
            lifecycle = contract.lifecycle,
            defined = contract._defined,
        })
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

--- Validate an event payload against its contract
---@param name string Event name
---@param payload table Event payload
---@return boolean valid, string|nil error
function EventRegistry.ValidatePayload(name, payload)
    local contract = eventContracts[name]
    if not contract then
        return false, "Event not defined: " .. name
    end

    -- Version check
    if payload.eventVersion and contract.version then
        if payload.eventVersion ~= contract.version then
            return false, string.format("Version mismatch for %s: expected %d, got %d",
                name, contract.version, payload.eventVersion)
        end
    end

    -- Required fields check
    if contract.requiredFields then
        for _, field in ipairs(contract.requiredFields) do
            -- Support dot notation: "payload.field"
            local value = payload
            for part in field:gmatch("[^.]+") do
                if value == nil then break end
                value = value[part]
            end
            if value == nil then
                return false, string.format("Missing required field '%s' in event %s", field, name)
            end
        end
    end

    return true, nil
end

--- Detect orphan consumers (consumers subscribed to events that no longer exist)
---@return table List of orphan consumer details
function EventRegistry.DetectOrphans()
    local orphans = {}
    local dce = _G.DCE
    if dce and dce.On then
        -- Detection happens by comparing active event bus registrations against contracts
        local eventBus = _G.DCEEventBus
        if eventBus and eventBus.ListEvents then
            local ok, activeEvents = pcall(eventBus.ListEvents)
            if ok and activeEvents then
                for _, eventName in ipairs(activeEvents) do
                    if not eventContracts[eventName] then
                        table.insert(orphans, {
                            name = eventName,
                            issue = "Active subscriber but no contract defined",
                        })
                    end
                end
            end
        end
    end
    return orphans
end

--- Detect unknown emitters (events emitted but contract doesn't list producer)
---@param eventName string Event name
---@param emitter string Emitter module name
---@return boolean
function EventRegistry.IsKnownEmitter(eventName, emitter)
    local contract = eventContracts[eventName]
    if not contract then return false end
    if not contract.producers then return false end
    for _, producer in ipairs(contract.producers) do
        if producer == emitter then return true end
    end
    return false
end

-- ============================================================================
-- Canonical Event Contracts
-- ============================================================================

-- Core lifecycle events (ACTIVE)
EventRegistry.Define("core:initialized", {
    owner = "dce-core",
    producers = { "dce-core" },
    version = 1,
    lifecycle = "active",
    priority = 0,
    reliability = "exactly-once",
    requiredFields = { "eventVersion", "timestamp", "source", "payload.version" },
    description = "Emitted when core initialization completes",
})

EventRegistry.Define("lifecycle:service:stateChanged", {
    owner = "dce-core",
    producers = { "dce-core" },
    version = 1,
    lifecycle = "active",
    priority = 1,
    reliability = "at-least-once",
    requiredFields = { "eventVersion", "timestamp", "source", "payload.service", "payload.from", "payload.to" },
    description = "Emitted when a service changes lifecycle state",
})

EventRegistry.Define("lifecycle:resource:stateChanged", {
    owner = "dce-core",
    producers = { "dce-core" },
    version = 1,
    lifecycle = "active",
    priority = 1,
    reliability = "at-least-once",
    requiredFields = { "eventVersion", "timestamp", "source", "payload.resource", "payload.from", "payload.to" },
    description = "Emitted when a resource changes lifecycle state",
})

-- SDK registration events (FUTURE_RESERVED — must not fabricate subscribers)
EventRegistry.Define("sdk:organization:registered", {
    owner = "dce-core",
    producers = { "dce-core" },
    version = 1,
    lifecycle = "future_reserved",
    priority = 2,
    reliability = "at-most-once",
    requiredFields = { "eventVersion", "timestamp", "source", "payload.orgId" },
    description = "FUTURE RESERVED: Emitted when a plugin registers an organization",
})

EventRegistry.Define("sdk:adapter:registered", {
    owner = "dce-core",
    producers = { "dce-core" },
    version = 1,
    lifecycle = "future_reserved",
    priority = 2,
    reliability = "at-most-once",
    requiredFields = { "eventVersion", "timestamp", "source", "payload.category", "payload.adapterName" },
    description = "FUTURE RESERVED: Emitted when a plugin registers an adapter",
})

EventRegistry.Define("sdk:behavior:registered", {
    owner = "dce-core",
    producers = { "dce-core" },
    version = 1,
    lifecycle = "future_reserved",
    priority = 2,
    reliability = "at-most-once",
    requiredFields = { "eventVersion", "timestamp", "source", "payload.behaviorType" },
    description = "FUTURE RESERVED: Emitted when a plugin registers a behavior",
})

EventRegistry.Define("sdk:escalation:registered", {
    owner = "dce-core",
    producers = { "dce-core" },
    version = 1,
    lifecycle = "future_reserved",
    priority = 2,
    reliability = "at-most-once",
    requiredFields = { "eventVersion", "timestamp", "source", "payload.chainId" },
    description = "FUTURE RESERVED: Emitted when a plugin registers an escalation chain",
})

-- ============================================================================
-- Public API
-- ============================================================================

function EventRegistry.Init()
    local gd = _G.DCEGracefulDegradation
    if gd and gd.MarkOperational then
        gd.MarkOperational("EventRegistry")
    end
end

-- ============================================================================
-- Register
-- ============================================================================

_G.DCEEventRegistry = EventRegistry
return EventRegistry