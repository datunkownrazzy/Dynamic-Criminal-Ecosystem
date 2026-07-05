-- DCE World Event Payload Type Declarations
-- This file contains ONLY type declarations for world/simulation domain event payloads.
-- All events from Event_Catalog_v1.md are defined here.
-- No runtime logic, no business logic.

--- @class WorldTickStartedPayload
--- Payload for world:tick:started
---@field tickId string Unique tick identifier
---@field timestamp number Unix timestamp
---@field priority string Tick priority level

--- @class WorldTickCompletedPayload
--- Payload for world:tick:completed
---@field tickId string Unique tick identifier
---@field timestamp number Unix timestamp
---@field durationMs number Tick duration in milliseconds
---@field regionsProcessed number Count of regions processed

--- @class RegionStateChangedPayload
--- Payload for world:region:state_changed
---@field id string Region identifier
---@field changes table Changed fields and their values

--- @class RegionLayerChangedPayload
--- Payload for world:region:layer_changed
---@field regionId string Region identifier
---@field fromLayer number Previous layer (0 or 1)
---@field toLayer number New layer (0 or 1)
---@field reason string Reason for change

--- @class WorldTimeChangedPayload
--- Payload for world:time:changed
---@field hour number Current hour
---@field minute number Current minute
---@field day number Current day
---@field isNight boolean Is it night time