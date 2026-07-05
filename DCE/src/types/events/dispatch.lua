-- DCE Dispatch Event Payload Type Declarations
-- This file contains ONLY type declarations for dispatch domain event payloads.
-- All events from Event_Catalog_v1.md are defined here.
-- No runtime logic, no business logic.

--- @class DispatchCallCreatedPayload
--- Payload for dispatch:call:created
---@field id string Call identifier
---@field incidentId string Parent incident ID
---@field description string Call description
---@field regionId string Region where incident occurred
---@field priority string Priority level (low|medium|high|critical)
---@field organizationId string|nil Originating organization
---@field scenarioId string|nil Originating scenario
---@field createdAt number Unix timestamp

--- @class OfficerAssignedPayload
--- Payload for dispatch:call:officer_assigned
---@field callId string Dispatch call ID
---@field officerId number|nil Assigned officer server ID
---@field unit string|nil Unit identifier (unit name, badge number, etc.)

--- @class DispatchCallRequestedPayload
--- Payload for dispatch:call:requested (internal from scenario escalation)
---@field scenarioId string Source scenario ID
---@field organizationId string Originating organization
---@field regionId string Region where incident occurred
---@field description string Call description
---@field priority string Priority level (default: medium)