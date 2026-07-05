-- DCE Organization Event Payload Type Declarations
-- This file contains ONLY type declarations for organization domain event payloads.
-- All events from Event_Catalog_v1.md are defined here.
-- No runtime logic, no business logic.

--- @class OrganizationLifecyclePayload
--- Payload for organization:lifecycle:created, organization:lifecycle:destroyed, etc.
---@field id string Organization identifier
---@field displayName string Organization display name
---@field source string "plugin"|"data" Source of creation

--- @class OrganizationSplitPayload
--- Payload for organization:lifecycle:split
---@field id string Original organization ID
---@field newOrgId string New organization ID created by split
---@field reason string Split reason

--- @class OrganizationMergedPayload
--- Payload for organization:lifecycle:merged
---@field id string Organization being merged
---@field mergedIntoId string Organization absorbing the merge
---@field reason string Merge reason

--- @class MemberJoinedPayload
--- Payload for organization:member:joined
---@field organizationId string Organization ID
---@field memberId string|number Member identifier
---@field role string Member role

--- @class MemberLeftPayload
--- Payload for organization:member:left
---@field organizationId string Organization ID
---@field memberId string|number Member identifier
---@field reason string Departure reason (desertion|death|arrest)

--- @class LeadershipChangedPayload
--- Payload for organization:leadership:changed
---@field organizationId string Organization ID
---@field oldValue string|nil Previous leader ID
---@field newValue string New leader ID

--- @class OrganizationStateChangedPayload
--- Payload for organization:state:changed
---@field organizationId string Organization ID
---@field fromState string Previous state
---@field toState string New state

--- @class PerceptionPressureUpdatedPayload
--- Payload for organization:perception:pressure_updated
---@field organizationId string Organization ID
---@field regionId string Region where pressure applied
---@field visiblePressure number Current visible pressure 0-100
---@field covertPressure number Current covert pressure 0-100
---@field perceptionPressure number Combined pressure value
---@field reason string Reason for pressure update

--- @class OrganizationActivityStartedPayload
--- Payload for organization:activity:started
---@field organizationId string Organization ID
---@field activity string Activity type ID
---@field location string Region where activity occurs
---@field layer number Simulation layer (1 for ambient)
---@field score number AI decision score

--- @class PerceptionPressureSpikedPayload
--- Payload for organization:perception:pressure_spiked
---@field organizationId string Organization ID
---@field regionId string Region where spike occurred
---@field visiblePressure number Current visible pressure 0-100
---@field covertPressure number Current covert pressure 0-100
---@field perceptionPressure number Combined pressure value at spike threshold
---@field reason string Reason for pressure spike