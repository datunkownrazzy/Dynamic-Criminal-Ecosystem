# DCE Plugin SDK

**Status:** Draft — pending review
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** DCE-0001 (Service Registry), DCE-0002 (Event Bus), DCE-0003 (Plugin Manifest), ServiceContracts, EventContracts, DataOwnership, Coding_Standards, AGENTS.md
**Drop into:** `docs/15_SDK/Plugin_SDK.md`

---

## Purpose

`DCE-0003-Plugin-Manifest.md` specifies how a plugin *declares itself* (name, dependencies, version compatibility). It does not specify what a plugin author can actually *do* — which exports exist, what data a new Organization or Adapter needs to provide, or what a minimal working plugin looks like end to end. This document is that missing piece, and it's what `PROJECT_PRINCIPLES.md` #5 ("Plugins are first-class citizens") and `AGENTS.md` rule #12 actually require existing before the "plugin path" can be considered real rather than aspirational.

---

## What a Plugin Can Extend (v1.0 Scope)

Per the `Provides` categories already defined in `DCE-0003-Plugin-Manifest.md`, the SDK exposes registration points for:

1. **New Organization archetypes** — personality weights, starting resources, leadership template (data, per `Organizations.md`)
2. **New Dispatch Adapters** — CAD/MDT integrations (per `IntergrationManager.md`, `Dispatch.md`)
3. **New Evidence/Inventory Adapters** — per `Evidence.md`, `Inventory_Integration.md`
4. **New Behaviors/Scenario content** — new entries in the AI Director's scoring table and new Escalation stage chains (per `AIDirector.md`, `Escalation.md`)

A plugin should never need to do anything not covered by one of these four registration points for v1.0. If it does, that's a gap in the SDK surface, not a reason to reach into core internals (`AGENTS.md` rule #2).

---

## The Golden Rule

**A plugin only ever calls `DCE:GetService(name)`, `DCE:On(eventName, fn)`, `DCE:Emit(eventName, payload)`, and the specific `Register*` functions listed below.** It never `require()`s a core file, never reads another resource's Lua tables, and never assumes internal field names not documented on a Service's public interface. This is `ServiceContracts.md`'s "Service Registry is the only approved boundary" rule, restated specifically for plugin authors who may not have read every architecture doc.

---

## SDK Export Surface

```lua
-- Organizations
exports.dce:RegisterOrganization(orgDataTable)
-- orgDataTable follows the schema in Organizations.md / /schemas/organizations/

-- Dispatch adapters
exports.dce:RegisterDispatchAdapter({
    Name = "MyDispatch",
    Priority = 70,
    CreateCall = function(data) end,
    UpdateCall = function(id, data) end,
    CloseCall = function(id) end,
})

-- Evidence/Inventory adapters
exports.dce:RegisterEvidenceAdapter({
    Name = "MyInventory",
    RegisterCasing = function(data) end,
    RegisterDNA = function(data) end,
    RegisterFingerprint = function(data) end,
})

-- MDT adapters
exports.dce:RegisterMDTAdapter({
    Name = "MyMDT",
    PushIntelTier = function(orgId, tier) end,
    SyncCaseFile = function(caseData) end,
})

-- Behaviors / Scenario content
exports.dce:RegisterBehavior(behaviorDataTable)
exports.dce:RegisterEscalationChain(escalationSchemaTable)

-- Generic plugin registration (ties the above to a manifest, per DCE-0003)
exports.dce:RegisterPlugin(Plugin) -- Plugin table as defined in DCE-0003
```

Every `Register*` function is itself sugar over the Service Registry / Event Bus underneath — `RegisterDispatchAdapter`, for instance, is really registering with the `IntegrationManager`'s adapter registry (per `IntergrationManager.md`). Plugin authors don't need to know this; it's noted here so implementers keep the SDK a thin, honest wrapper rather than a separate parallel system.

---

## Minimal Plugin Example

A complete, valid plugin needs three things: a manifest, at least one registration call, and cleanup on stop.

```lua
-- manifest (per DCE-0003)
Plugin = {
    Name = "Simple Cartel Pack",
    Id = "dce-plugin-simple-cartel",
    Version = "0.1.0",
    Requires = { "dce-core", "dce-ai" },
    Provides = { "Organization" },
    DCE = { Min = "1.0.0" },
}

-- registration
CreateThread(function()
    exports.dce:RegisterOrganization({
        id = "simple_cartel",
        displayName = "Simple Cartel",
        personality = {
            violence = 45, drugTrade = 90, extortion = 20,
            smuggling = 95, recruitment = 30, territorial = 40, planning = 85,
        },
        startingResources = { money = 50000, members = 15, vehicles = {} },
    })
end)

-- cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- unregister anything this plugin registered, if the SDK requires explicit teardown
end)
```

This example deliberately mirrors the phase structure from `Coding_Standards.md` (Declare → Register → ... → Activate) even though it's a plugin, not core — the same discipline applies regardless of which side of the SDK boundary the code lives on.

---

## Validation and Failure Modes

Per `DCE-0003-Plugin-Manifest.md`, registration attempts from a plugin that fails manifest validation (missing dependency, version mismatch) must not partially succeed. The SDK's `Register*` functions should check plugin validity before accepting the registration, and log a clear `error` (per `Logger.md`) naming the plugin and the reason, rather than silently ignoring a bad registration.

If two plugins attempt to register an Organization with the same `id`, or an Adapter under the same category without an explicit priority/override, this follows the same conflict-handling rule as `DCE-0001-Service-Registry.md` — reject the duplicate, log a warning, never silently let "last one wins."

---

## What Plugins Cannot Do (v1.0)

Stated explicitly so plugin authors don't attempt it and file confused bug reports:

- Cannot override core Simulation Layer promotion/demotion logic (`Simulation_Layers.md`) — a plugin can add new Scenario content that gets promoted through the existing layers, but cannot introduce a fifth layer or change promotion thresholds globally.
- Cannot directly write to another Service's persisted state (`Persistence.md`) — a plugin's own data (e.g., a new Organization's custom fields) persists through its own registration with the Persistence Coordinator, not by piggybacking on an existing Service's save data.
- Cannot bypass the Admin UI's permission model (`Admin_UI.md`) to expose new admin commands without going through the same `Config.Admin.PermissionCheck` gate everything else uses.

---

## Versioning and Compatibility

Per `DCE-0003`'s `DCE.Min`/`DCE.Max` fields and `EventContracts.md`'s versioning rules: the SDK's exported function *signatures* are part of DCE's public API surface. Changing an existing `Register*` function's argument shape is a breaking change requiring a version bump and, for anything significant, an ADR — same standard as Service interfaces and event payloads elsewhere in the framework (`AGENTS.md` rule #14).

---

## Emitted Events

- `sdk:plugin:registered` — `{ pluginId, provides }`
- `sdk:plugin:rejected` — `{ pluginId, reason }`
- `sdk:organization:registered` — `{ orgId, sourcePluginId }`
- `sdk:adapter:registered` — `{ category, adapterName, sourcePluginId }`

These let the Admin UI's Integration Health Panel (`Admin_UI.md`) and the developer console show exactly what plugins contributed what, which matters once a server is running more than one or two plugins at once.

---

## What This Document Does Not Cover

- The Marketplace concept from the original design conversations (discovery, distribution, ratings) — that's a v1.5+/community-infrastructure concern, not part of the SDK contract itself.
- The visual drag-and-drop Scenario Composer — explicitly deferred past v1.0 per `Goals.md`; `RegisterEscalationChain` above is the code-level equivalent a plugin author uses until/unless that GUI exists.
