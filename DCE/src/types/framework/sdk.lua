-- DCE Plugin SDK Type Declarations
-- This file contains ONLY type declarations for the DCE plugin SDK API.
-- The SDK API is used by plugin authors to extend DCE functionality.
-- This interface is separate from the framework core.
-- No runtime logic, no business logic.

---@class DCEPluginSDK
--- DCE Plugin SDK - Registration functions for plugin authors.
--- The canonical SDK (Sprint 1.11.7+) registers ALL domain objects (organizations,
--- adapters, behaviors, escalation chains) via DCE:RegisterService(name, serviceTable)
--- per consumer ownership. The obsolete RegisterOrganization/RegisterDispatchAdapter/
--- RegisterEvidenceAdapter/RegisterMDTAdapter/RegisterBehavior/RegisterEscalationChain
--- methods were REMOVED. The canonical plugin registration surface is RegisterPlugin.
--- All SDK methods are COLON-defined (self is the first parameter).
---@field RegisterPlugin fun(self:DCEPluginSDK, manifest:table):boolean Register a plugin manifest
---@field ListPlugins fun(self:DCEPluginSDK):string[] List registered plugin names
---@type DCEPluginSDK
DCEPluginSDK = nil
