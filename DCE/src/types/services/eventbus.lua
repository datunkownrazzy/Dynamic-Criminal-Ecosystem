-- DCE EventBus Service Type Declarations
-- This file contains ONLY type declarations for the EventBus service.
-- No runtime logic, no business logic.

--- @class DCEEventBus
--- Event Bus: Pub/sub mechanism for all cross-module communication.
--- All events follow the envelope format: { eventName, eventVersion, timestamp, source, correlationId?, payload }
--- All methods are COLON-defined (self is the first parameter).
---@field Emit fun(self:DCEEventBus, eventName:string, payload:any):nil Emit an event
---@field On fun(self:DCEEventBus, eventName:string, handlerFn:function):number|nil Register an event handler
---@field Once fun(self:DCEEventBus, eventName:string, handlerFn:function):number|nil Register one-time handler
---@field Off fun(self:DCEEventBus, eventName:string, handlerId:number):boolean Unsubscribe from an event
---@field Sticky fun(self:DCEEventBus, eventName:string):nil Mark an event as sticky
---@field EmitSticky fun(self:DCEEventBus, eventName:string, payload:any):nil Emit a sticky event
---@field GetListenerCount fun(self:DCEEventBus, eventName:string):number Get listener count for event
---@field ListEvents fun(self:DCEEventBus):string[] List all event names
---@field ListStickyEvents fun(self:DCEEventBus):string[] List all sticky event names
---@field Clear fun(self:DCEEventBus):nil Clear all handlers

--- @class IEventBusMetrics
--- Event bus metrics for instrumentation.
---@field totalDispatches number Total events dispatched
---@field totalErrors number Total handler errors
---@field totalSkipped number Total events skipped (no subscribers or rate limited)
---@field events table[] Per-event metrics with avg/max dispatch times

--- @class IEventMetrics
--- Per-event dispatch metrics.
---@field name string Event name
---@field avgDispatchMs number Average dispatch time in milliseconds
---@field maxDispatchMs number Maximum dispatch time in milliseconds
---@field totalDispatches number Total dispatches for this event

--- @class IEventHandler
--- Event handler registration.
---@field id number Handler identifier
---@field eventName string Event name
---@field callback function Handler function

---@type DCEEventBus|nil
DCEEventBus = nil
