# ADR-0006: Plugin Architecture

**Status:** Accepted
**Date:** 2026-07-04
**Author:** Architecture
**Dependencies:** DCE-0003 (Plugin Manifest), Plugin_SDK.md, ADR-0005 (Domain Boundaries)

---

## Problem

`DCE-0003-Plugin-Manifest.md` specifies plugin declaration/validation. `Plugin_SDK.md` specifies the concrete export surface. Neither document commits, at ADR authority, to the underlying model of *why* a plugin is restricted the way it is — specifically, the guarantee that **a third-party plugin never has direct access to internal Services.** This ADR formalizes that guarantee as the plugin architecture's foundational model.

## Decision

### The Plugin Pipeline

Every plugin interaction with DCE flows through exactly this pipeline, in this order — no stage can be skipped:

```
Plugin
    │
    ▼
Capabilities        (what categories of extension this plugin is asking to use — Organization, Dispatch Adapter, etc., per DCE-0003's Provides tags)
    │
    ▼
Events              (what it subscribes to — read-only awareness of the world)
    │
    ▼
Commands            (what it can request — intent to change state, per the Command Catalog)
    │
    ▼
Queries             (what it can ask — read-only requests for current state)
    │
    ▼
Registration        (DCE-0003 manifest validation — dependency presence, Id uniqueness)
    │
    ▼
Dependency Validation
    │
    ▼
Version Compatibility (DCE.Min/DCE.Max, per DCE-0003)
```

### Capabilities, Not Services

A plugin never receives a raw reference to an internal Service table. It declares **Capabilities** (the `Provides`/`Requires` categories already defined in `DCE-0003`), and the SDK (`Plugin_SDK.md`) exposes only the narrow, capability-scoped functions appropriate to those categories (`RegisterOrganization`, `RegisterDispatchAdapter`, etc.). This is the mechanism, not just a policy statement — `exports.dce:RegisterX(...)` functions are the *only* surface a plugin resource can call; there is no `exports.dce:GetInternalService(name)` equivalent exposed to plugin-scoped code at all. Internal Services (`DCE:GetService`) are a **core-and-first-party-module-only** mechanism; the plugin SDK is a deliberately smaller, stable subset sitting in front of it.

This is a stronger guarantee than "plugins are asked nicely to only use the SDK" (which is what `Plugin_SDK.md`'s "Golden Rule" reads as on its own) — this ADR commits to the SDK being the *only reachable surface*, enforced by what's actually exported, not merely documented as a convention.

### Events (Read) vs. Commands (Write) for Plugins

Consistent with `ADR-0005`'s Command/Event split: a plugin **may subscribe to any public Event** (per the Event Catalog) freely — this is pure observation and carries no risk to domain boundaries. A plugin **may only issue Commands that its declared Capabilities entitle it to** — e.g., a plugin providing a new Organization archetype can issue commands relevant to that organization's lifecycle, but a Dispatch Adapter plugin has no legitimate reason to issue a `TransferFunds` command, and the SDK should not expose that capability to it.

```lua
-- Available to any plugin, no capability needed:
DCE:On("territory:ownership:changed", fn)

-- Only available if the plugin declared "Organization" capability in its manifest:
exports.dce:IssueCommand("RecruitMember", { organizationId = "my_plugin_org", count = 3 })
```

### Queries

Plugins may issue read-only **Queries** through the same capability-scoped SDK surface (e.g., `exports.dce:QueryOrganizationState(orgId)`), which internally calls the appropriate Service's `GetState`-style method on the plugin's behalf. This gives plugins the read access they need without ever handing them the Service reference directly — the SDK function is a proxy, not a passthrough.

### Registration, Dependency Validation, Version Compatibility

These three stages are exactly what `DCE-0003-Plugin-Manifest.md` already specifies (manifest fields, validation order, rejection behavior) — this ADR does not change that mechanism, it places it as the final three stages of the pipeline above, after Capabilities/Events/Commands/Queries have been declared, so the full picture of "what happens when a plugin loads" is visible in one place.

### Why This Matters More Than It Might Seem

Without this ADR's stricter framing, "use the SDK" is a request for good behavior that a plugin author could still bypass (e.g., by finding a way to call `DCE:GetService` directly, since it's technically a global). This ADR commits the framework to actually restricting that surface for plugin-scoped code — meaning first-party modules (`dce-ai`, `dce-dispatch`, etc.) get full `DCE:GetService` access as before, but code loaded as a declared Plugin (per its manifest) does not, even though it's still just a FiveM resource with the same technical capabilities under the hood. This is enforced by convention plus tooling (the Plugin Manager can, at minimum, log a loud warning if a Plugin-manifested resource is observed calling `DCE:GetService` directly) rather than a hard sandbox, since Lua/FiveM doesn't give us a true sandbox boundary between resources — but the intent and the primary supported path are unambiguous.

## Consequences

- Plugin authors have a smaller, more stable surface to code against than internal module authors do — which is the point. The SDK surface changes far less often than internal Service interfaces, insulating plugins from internal refactors.
- Some legitimate plugin use cases may find the Capability/Command surface too narrow at first (e.g., a sufficiently novel plugin idea might need a Command that doesn't exist yet). The correct response is to extend the Command Catalog and SDK, not to grant broader access — consistent with `ADR-0005`'s closing point that a plugin wanting deeper access is a signal to extend the catalog, not to breach the boundary.
- This raises the bar for what "the SDK supports plugins" means — `Plugin_SDK.md` and `DCE-0003` should both be read as implementing this ADR's model, and any future SDK addition should be checked against whether it accidentally exposes internal Service access rather than a scoped Capability/Command/Query.

## Related

- `specifications/DCE-0003-Plugin-Manifest.md`
- `docs/15_SDK/Plugin_SDK.md`
- `architecture/ADR-0005-Domain-Boundaries.md`
- `docs/16_Catalogs/Command_Catalog_v1.md`
