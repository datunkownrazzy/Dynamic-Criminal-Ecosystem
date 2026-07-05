-- DCE SDK Event Payload Type Declarations
-- This file contains ONLY type declarations for SDK/plugin registration event payloads.
-- All events from Event_Catalog_v1.md are defined here.
-- No runtime logic, no business logic.

--- @class PluginRegisteredPayload
--- Payload for sdk:plugin:registered
---@field pluginName string Plugin identifier
---@field version string Plugin version
---@field author string Plugin author
---@field registeredAt number Unix timestamp

--- @class PluginRejectedPayload
--- Payload for sdk:plugin:rejected
---@field pluginName string Plugin identifier
---@field reason string Rejection reason
---@field validationError string|nil Validation error details

--- @class OrganizationRegisteredPayload
--- Payload for sdk:organization:registered
---@field id string Organization identifier
---@field displayName string Organization display name
---@field source string "plugin" Source is always plugin for SDK events
---@field registeredAt number Unix timestamp

--- @class AdapterRegisteredPayload
--- Payload for sdk:adapter:registered
---@field type string Adapter type (dispatch|evidence|mdt|analytics|scenario)
---@field name string Adapter identifier
---@field priority number Adapter priority
---@field registeredAt number Unix timestamp

--- @class BehaviorRegisteredPayload
--- Payload for sdk:behavior:registered
---@field behaviorId string Behavior identifier
---@field behaviorType string Behavior type
---@field registeredAt number Unix timestamp

--- @class EscalationRegisteredPayload
--- Payload for sdk:escalation:registered
---@field scenarioId string Scenario that escalation applies to
---@field chainName string Escalation chain name
---@field registeredAt number Unix timestamp

--- @class CoreInitializedPayload
--- Payload for core:initialized
---@field version string DCE version
---@field resourcesLoaded string[] List of loaded resource names
---@field initializedAt number Unix timestamp

--- @class ServiceRegisteredPayload
--- Payload for service:registered:<name>
---@field serviceName string Service name
---@field registeredAt number Unix timestamp