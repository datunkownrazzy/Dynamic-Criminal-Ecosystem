-- DCE Dispatch Domain Type Declarations
-- This file contains ONLY type declarations for the Dispatch domain.
-- No runtime logic, no business logic.

--- @class IDispatchCall
--- Dispatch Call Model: Represents a single dispatch call.
---@field id string Unique call identifier
---@field incidentId string Parent incident ID
---@field description string Call description
---@field regionId string Region where incident occurred
---@field priority string Priority level (low|medium|high|critical)
---@field organizationId string|nil Originating organization
---@field scenarioId string|nil Originating scenario
---@field status string Current status (pending|active|resolved|cancelled)
---@field createdAt number Unix timestamp
---@field updatedAt number Unix timestamp
---@field resolvedAt number|nil Unix timestamp
---@field disposition string|nil Resolution disposition
---@field updates table[] Call updates
---@field Activate fun(self:IDispatchCall):nil
---@field Resolve fun(self:IDispatchCall, disposition:string):nil
---@field Cancel fun(self:IDispatchCall):nil
---@field AddUpdate fun(self:IDispatchCall, updateText:string):nil
---@field GetSummary fun(self:IDispatchCall):DispatchCallSummary
---@field HasTimedOut fun(self:IDispatchCall):boolean

--- @class DispatchCallStatuses
--- Dispatch call status enum values.
DispatchCallStatuses = {
    Pending = "pending",
    Active = "active",
    Resolved = "resolved",
    Cancelled = "cancelled",
}

--- @class IDispatchService
--- Dispatch Service: Manages dispatch call lifecycle.
---@field Initialize fun(self:IDispatchService):nil
---@field SetAdapter fun(self:IDispatchService, adapter:IDispatchAdapter|nil):nil
---@field GetAdapter fun(self:IDispatchService):IDispatchAdapter|nil
---@field CreateCall fun(self:IDispatchService, data:table):DispatchCallSummary|nil
---@field GetCallDetails fun(self:IDispatchService, callId:string):DispatchCallSummary|nil
---@field GetActiveCalls fun(self:IDispatchService):DispatchCallSummary[]
---@field ActivateCall fun(self:IDispatchService, callId:string):boolean
---@field UpdateCall fun(self:IDispatchService, callId:string, updateText:string):boolean
---@field ResolveCall fun(self:IDispatchService, callId:string, disposition:string):boolean
---@field IsIncidentReported fun(self:IDispatchService, incidentId:string):boolean
---@field GetAllCalls fun(self:IDispatchService):DispatchCallSummary[]
---@field Cleanup fun(self:IDispatchService):nil
---@field Shutdown fun(self:IDispatchService):nil