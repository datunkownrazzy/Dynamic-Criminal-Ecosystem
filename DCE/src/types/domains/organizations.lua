-- DCE Organizations Domain Type Declarations
-- This file contains ONLY type declarations for the Organizations domain.
-- No runtime logic, no business logic.

--- @class IOrganization
--- Organization Model: Represents a criminal organization with identity, state, and behavior.
---@field id string Unique organization identifier
---@field displayName string Human-readable name
---@field personality table Personality weights {violence, drugTrade, extortion, smuggling, recruitment, territorial, planning}
---@field runtime table Runtime state {money, members, vehicles, safehouses, territories, heat, influence, morale, intelligence, state}
---@field leadership table Leadership hierarchy {boss, underboss, lieutenants, crewLeaders, veterans, soldiers, prospects}

--- @class IOrganizationService
--- Organization Service: Owns organization identity, runtime state, leadership, and state exposure.
--- Includes perception pressure methods for world-to-org communication.
---@field Initialize fun(self:IOrganizationService):nil
---@field GetState fun(self:IOrganizationService, orgId:string):table|nil
---@field GetIdentity fun(self:IOrganizationService, orgId:string):table|nil
---@field GetLeadership fun(self:IOrganizationService, orgId:string):table|nil
---@field GetAllOrgIds fun(self:IOrganizationService):string[]
---@field GetOrgState fun(self:IOrganizationService, orgId:string):string|nil
---@field SetOrganizationState fun(self:IOrganizationService, orgId:string, newState:string):boolean
---@field AddHeat fun(self:IOrganizationService, orgId:string, amount:number):nil
---@field AddMoney fun(self:IOrganizationService, orgId:string, amount:number):nil
---@field GetAllOrgStates fun(self:IOrganizationService):table[]
---@field SetPerceptionPressure fun(self:IOrganizationService, orgId:string, visible:number, covert:number, source:string):nil
---@field ApplyPerceptionPressure fun(self:IOrganizationService, orgId:string, visible:number, covert:number, source:string):nil
---@field DecayPerceptionPressure fun(self:IOrganizationService, orgId:string, deltaTime:number):nil
---@field GetPerceptionPressure fun(self:IOrganizationService, orgId:string):table|nil
---@field EvaluateTransitions fun(self:IOrganizationService):table[]
---@field GetOrgInstance fun(self:IOrganizationService, orgId:string):table|nil Internal method for AI Director access

--- @class IActivity
--- Activity Model: Represents an organizational activity type with scoring rules.
---@field id string Activity identifier
---@field displayName string Human-readable name
---@field enabled boolean Whether activity is available
---@field weight number Base likelihood weight
---@field requiredState string State required for availability
---@field IsAvailable fun(self:IActivity, state:string):boolean
---@field MeetsRequirements fun(self:IActivity, orgState:table):boolean
---@field GetRequirements fun(self:IActivity):table
---@field GetReward fun(self:IActivity):table

--- @class IAIDirectorService
--- AI Director Service: Evaluates world state and organization state, scores activities.
---@field Initialize fun(self:IAIDirectorService):nil
---@field Tick fun(self:IAIDirectorService):table|nil
---@field EvaluateOrganization fun(self:IAIDirectorService, orgId:string):table|nil
---@field GetActiveDecision fun(self:IAIDirectorService, orgId:string):table|nil
---@field ClearDecision fun(self:IAIDirectorService, orgId:string):nil
---@field Shutdown fun(self:IAIDirectorService):nil

--- @class IScoring
--- Scoring System: Computes activity scores based on world and org state.
---@field Compute fun(self:IScoring, activityDef:IActivity, orgIdentity:table, orgState:table, regionState:table, timeState:table, weather:string):number
---@field SelectWeighted fun(self:IScoring, candidates:table[]):table|nil

--- @class OrganizationStates
--- Organization state machine enum values.
OrganizationStates = {
    Dormant = "Dormant",
    Growing = "Growing",
    Stable = "Stable",
    AggressiveExpansion = "Aggressive Expansion",
    Conflict = "Conflict",
    UnderInvestigation = "Under Investigation",
    Suppressed = "Suppressed",
    Recovering = "Recovering",
}