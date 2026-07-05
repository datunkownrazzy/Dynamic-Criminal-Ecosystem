-- DCE Evidence Event Payload Type Declarations
-- This file contains ONLY type declarations for evidence domain event payloads.
-- All events from Event_Catalog_v1.md are defined here.
-- No runtime logic, no business logic.

--- @class EvidenceCollectedPayload
--- Payload for evidence:item:recovered
---@field id string Evidence identifier
---@field type string Evidence type (physical, dna, fingerprint, etc.)
---@field description string Evidence description
---@field source string Source of evidence
---@field organizationId string|nil Originating organization
---@field scenarioId string|nil Originating scenario
---@field regionId string|nil Region where collected
---@field confidence number Confidence level 0-100
---@field createdAt number Unix timestamp

--- @class EvidenceDestroyedPayload
--- Payload for evidence:item:destroyed
---@field id string Evidence identifier
---@field reason string Destruction reason (decay|deliberate)
---@field destroyedAt number Unix timestamp

--- @class EvidenceTransferredPayload
--- Payload for evidence:item:transferred
---@field evidenceId string Evidence identifier
---@field from string Previous holder
---@field to string New holder
---@field reason string Transfer reason
---@field timestamp number Unix timestamp

--- @class EvidenceCreatedPayload
--- Payload for evidence:item:created
---@field id string Evidence identifier
---@field type string Evidence type (physical, dna, fingerprint, etc.)
---@field description string Evidence description
---@field source string Source of evidence
---@field organizationId string|nil Originating organization
---@field scenarioId string|nil Originating scenario
---@field regionId string|nil Region where collected
---@field confidence number Confidence level 0-100
---@field createdAt number Unix timestamp

--- @class EvidenceVerifiedPayload
--- Payload for evidence:item:verified
---@field id string Evidence identifier
---@field verifiedAt number Unix timestamp
