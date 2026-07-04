# DCE-0001: Service Registry

**Status:** Accepted
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** None


---

## Purpose

The Service Registry is how modules in DCE find each other without hardcoding dependencies. Any module that wants to provide functionality to the rest of the system registers a Service; any module that wants to use that functionality looks it up by name rather than requiring the providing module directly.

This exists to satisfy Principle #4 (`PROJECT_PRINCIPLES.md`): no service depends on another's internals.

---

## Problem

Without a registry, modules end up calling each other directly:

```lua
-- BAD: dce-ai reaching directly into dce-dispatch
exports['dce-dispatch']:CreateCall(data)
```

This works until:
- `dce-dispatch` is disabled or not installed on a given server.
- A plugin wants to intercept or replace dispatch behavior.
- Two competing dispatch implementations need to coexist during a migration.

Direct calls also make it unclear, from reading `dce-ai`, what its actual dependencies are.

---

## Design

### Registration

A module registers a service once, at startup:

```lua
DCE:RegisterService("Dispatch", DispatchServiceTable)
```

`DispatchServiceTable` is a plain Lua table exposing the service's public interface (functions and, where appropriate, read-only accessors). Anything not exposed on this table is private to the module.

### Resolution

Any other module resolves the service by name when it needs it:

```lua
local Dispatch = DCE:GetService("Dispatch")
Dispatch.CreateCall(data)
```

Consumers never know or care which resource actually provides "Dispatch" — it could be DCE's native fallback or a plugin-provided replacement.

### Optional Services

Because every feature must be independently disableable (Principle #3), `GetService` can return `nil` if the requested service isn't registered (e.g., `dce-investigations` is disabled). Callers that treat a service as optional must handle `nil` gracefully:

```lua
local Investigations = DCE:GetService("Investigations")
if Investigations then
    Investigations.OpenCase(evidenceId)
end
```

A small number of services (Dispatch, Evidence, World) are expected to always be present because DCE ships a native fallback implementation if no third-party integration is installed — see `DCE-0004` (Integration Adapters, future spec) for how that fallback registration works.

### Replacing a Service

A plugin may register a service under a name that already has a provider, if it explicitly declares intent to override:

```lua
DCE:RegisterService("Dispatch", MyCustomDispatch, { override = true })
```

Without `override = true`, a duplicate registration is rejected and logged as a warning — silent overwrites are a common source of hard-to-diagnose bugs and are not allowed.

### Startup Ordering

Because resources can start in a nondeterministic order relative to each other, `GetService` calls made during another resource's startup are not guaranteed to succeed yet. Modules should either:
- Resolve services lazily (on first use, not at file load time), or
- Subscribe to a `"service:registered:<name>"` Event Bus notification (see `DCE-0002`) if they need to react the moment a dependency becomes available.

Resolving `nil` at load time and never re-checking is the most common mistake here — don't cache a `nil` result from `GetService` as if it were permanent.

---

## API Surface

```lua
DCE:RegisterService(name, serviceTable, options)
-- options.override (boolean, default false)

DCE:GetService(name) -> serviceTable | nil

DCE:HasService(name) -> boolean

DCE:UnregisterService(name)
-- Used on resource stop/restart; also fires "service:unregistered:<name>"
```

---

## What the Registry Is Not

- It is not a dependency injection container that auto-wires constructor arguments. It's a lookup table with guardrails.
- It does not manage service lifecycle (start/stop ordering) beyond registration/unregistration — see the (future) Lifecycle spec for that.
- It does not replace the Event Bus. The Registry is for "give me a thing I can call." The Event Bus (`DCE-0002`) is for "tell me when something happens." Using the Registry to poll for state changes instead of subscribing to an event is a design smell.

---

## Consequences

- Every service must have a clearly documented public interface — there's no way to "accidentally" expose internals through the registry the way a shared require() might.
- Debugging requires checking `DCE:HasService(name)`/registry contents as a first step when something is unexpectedly `nil` — this should be a documented step in the troubleshooting guide.
- Because resolution is by string name, typos fail silently as `nil` rather than as a load-time error. Consider a `DCE:GetServiceOrThrow(name)` variant for cases where the dependency is truly mandatory and failing loudly is preferable (e.g., core startup sequencing) — left as an open question for the SDK spec.
