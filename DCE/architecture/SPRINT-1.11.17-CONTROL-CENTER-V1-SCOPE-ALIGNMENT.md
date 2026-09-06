# Sprint 1.11.17 - Control Center V1 Scope Alignment

**Status:** Architecture and current-state audit complete. No new administrative mutation capability implemented.  
**Scope:** Align the V1 Control Center with its intended role as DCE's administrative interface without creating unowned server behavior, fake data, or speculative V2 infrastructure.

## 1. Decision

The Control Center is DCE's administrative presentation and interaction layer. It is not a simulation owner, configuration owner, world owner, adapter owner, or persistence owner.

It must consume the administrative contracts of the systems that own those responsibilities:

| Area | Authoritative owner | Control Center responsibility |
|---|---|---|
| Operations | Domain services | Present supported operational state and routes. |
| Configuration | A future owned configuration-runtime service or the owning subsystem | Request authorized reads, validation, apply, and confirmation. |
| World and locations | `World` and `LocationManager` | Present supported state and request supported edits. |
| Territories | Unowned; must be decided before implementation | No mutation UI or transport until ownership is defined. |
| Organizations | Organization service when its administrative contract exists | Present and request supported actions only. |
| Integrations | Adapter registry and adapters | Discover and render actual adapter metadata and capabilities. |
| Runtime | Core runtime services | Present actual service, scheduler, EventBus, plugin, and session state. |
| Diagnostics | Owning logger/runtime services | Present actual warnings, errors, and diagnostics. |
| Persistence | Existing persistence owner, once established | Never persist frontend-only state as authoritative data. |

The NUI remains non-authoritative. All future administrative writes must use this flow:

```
Control Center request
  -> server authorization
  -> server validation
  -> owning service apply
  -> persistence when supported
  -> affected runtime refresh or synchronization
  -> authoritative result to Control Center
```

No UI success state may be shown before the final authoritative result is received.

## 2. Current Control Center Responsibilities

The existing V1 Control Center already provides a bounded in-game application shell, Home, operational navigation, truthful unavailable states, Close, ESC, `/dceclose`, sessions, browser activation, and focus release. It remains intentionally bounded and centered; no fullscreen regression is permitted.

Its current primary destinations are Home, World, Organizations, Scenarios, Dispatch, Evidence, Economy, and Intelligence. This is an operational navigation model, not a complete administrative capability model. The existing visible pages must not claim that unavailable subsystem data or actions are available.

The intended final navigation model is:

| Category | Intended areas | Current V1 status |
|---|---|---|
| Operations | Home, World, Territories, Organizations, Scenarios, Dispatch, Evidence, Economy, Intelligence | Home and operational routes exist; data is mostly unavailable by design. Territories has no implementation. |
| Administration | Configuration, Integrations, Runtime, Diagnostics | No server-backed contract and no primary UI surface yet. |
| Contextual authoring | Locations, MLOs, walkable interiors, interaction/scenario locations, territory and organization editing | Location runtime API is partial; all other authoring contracts are absent or unowned. |

The category model is an architectural destination, not authorization to add empty pages, fake controls, or frontend-only state. A category becomes visible when it can honestly provide at least one server-backed read, a deliberate unavailable state tied to a registered capability, or a documented integration boundary.

## 3. Verified Current Implementation

### Control Center Lifecycle

- `/dce` requests opening through the existing Control Center service and server session manager.
- NUI boot is lazy: `bootstrap.js` loads first; the application manager and UI/plugins load after session boot.
- Focus is acquired only after `dce-cc:application:booted`; `FocusManager` remains the sole owner of `SetNuiFocus`.
- Header Close and ESC use existing NUI callbacks that converge on `dce-cc:session:close`; `/dceclose` uses the existing server close request.
- Session end sends application shutdown, unloads UI state, and releases focus. Resource stop has an emergency focus release.
- The desktop surface is centered, bounded, responsive, and contains the status bar, notifications, and modal overlay.

Relevant sources: [fxmanifest.lua](../src/dce-controlcenter/fxmanifest.lua), [controlcenter.lua](../src/dce-controlcenter/server/services/controlcenter.lua), [session-manager.lua](../src/dce-controlcenter/server/session-manager.lua), [session-manager-client.lua](../src/dce-controlcenter/session/session-manager-client.lua), [focus-manager.lua](../src/dce-controlcenter/session/focus-manager.lua), [application-manager.js](../src/dce-controlcenter/html/js/application/application-manager.js), [desktop.js](../src/dce-controlcenter/html/js/ui/desktop.js), and [style.css](../src/dce-controlcenter/html/css/style.css).

### Existing V1 Domain Capabilities

| Capability | Actual owner | Current runtime capability | Control Center status |
|---|---|---|---|
| World state inspection | `World` service | Read API for region state, time, weather, and region lists exists. | Current adapter/UI does not expose a working NUI contract. |
| Locations | `LocationManager` | In-memory create and update exist; runtime registration and resolution exist. | No Control Center transport; no persistence; delete absent. |
| Organizations | Organization domain | No verified administrative CRUD contract. | UI correctly represents data as unavailable. |
| Evidence | `EvidenceService` | In-memory creation and reads exist. | Adapter CRUD is stubbed; no Control Center contract. |
| Dispatch | `DispatchService` | Call creation exists. | No Control Center read/update/resolve contract. |
| Runtime primitives | Core EventBus and Scheduler | `EventBus.GetMetrics()` and `Scheduler.ListTasks()` exist. | No complete Control Center runtime read model. |
| Control Center sessions | `SessionManager` | Create, start, reuse, close, end, and list active sessions exist. | Used by the Control Center lifecycle. |

## 4. Configuration and Hot Configuration

### Current State

Configuration is loaded into resource configuration tables and used at startup. No runtime configuration mutation, validation, authorization, persistence, rollback, or affected-service refresh contract is implemented.

`IAdminService.UpdateConfig` in [admin.lua](../src/types/domains/admin.lua) is a type declaration only. It does not identify an implementation owner. The repository also has no DCE persistence layer for configuration changes.

Therefore, no setting can truthfully be shown as hot-editable, persisted, applied, restart-required, saved, or reverted through the Control Center today.

### Required Architecture Before Implementation

A new ADR is required before hot configuration work because ownership and failure behavior are unresolved. The ADR must define:

1. The service that owns runtime configuration mutation and its relationship to each subsystem's config.
2. The allowed setting registry, schema, type validation, defaults, and redaction of secrets.
3. Server-side ACE authorization per operation and per configurable subsystem.
4. Apply categories: hot apply, targeted refresh/reinitialize, runtime object recreation, and genuine restart requirement.
5. Atomicity, rollback/revert behavior, and error reporting.
6. Persistence owner, format/storage, load order, migrations, and failure semantics.
7. EventBus state-transition events for accepted/applied/failed changes.
8. NUI request/response contracts and confirmation payloads.
9. Audit logging ownership and retention.

Only after that ADR and an owning service exist may Configuration expose real read/edit/apply controls. The UI must then distinguish authoritative saved values from local unsaved edits and report `validating`, `applying`, `applied`, `validation failed`, `apply failed`, `persistence failed`, `unavailable`, and `restart required` based on server results.

## 5. World Authoring and Live Editing

### Locations

[Location Manager](../docs/06_Territories/Location_Manager.md) establishes `LocationManager` as the single source of truth for physical DCE locations. It supports location types including `walkin-mlo`, `instanced`, `hybrid`, `organization-facility`, `territory`, and `scenario-location`; this establishes the correct future extension point for location and interior-related authoring.

The implementation currently provides in-memory location creation and update. It does not provide delete, persistence, Control Center authorization, a NUI callback contract, player-position capture, or synchronization behavior. Location authoring is therefore **partially implemented in the domain, unavailable in the Control Center**.

V1 work that can proceed only after a narrow contract review is limited to completing `LocationManager.DeleteLocation` to match its existing interface, then exposing a server-authoritative location read/edit flow that uses the existing Location Manager. Persistent live editing must wait for a persistence decision.

### Territories

Territory management is not implementable in this sprint. Documentation describes territory behavior, but no service owns territory CRUD, validation, persistence, or relationship changes. The Control Center must not create a territory system or choose whether World or Organizations owns it.

An ADR must assign territory ownership and define territory identifiers, geometry/boundary validation, organization references, mutation and deletion semantics, runtime synchronization, persistence, and reconciliation of stale relationships before a Territory authoring surface is implemented.

### Organizations

Organization adapter CRUD is currently stubbed and does not delegate to an implemented administrative contract. The Control Center must continue to represent Organization data as unavailable. It must not recreate organization CRUD in the UI or adapter layer.

### MLOs and Walkable Interiors

The location model recognizes MLO/interior-oriented location types, but no dedicated MLO, entrance/exit, walkability, boundary, interaction-point, or persistent interior-definition service is implemented. These belong as typed location-provider capabilities under the Location Manager, not as an independent Control Center world model.

Before MLO or walkable-interior authoring, document the provider contract and runtime synchronization behavior. The Control Center's future role is to edit and invoke that owner, never to own the geometry or player routing state.

### Live World Change Contract

For every supported persistent world edit, the owning service must validate, prepare, persist, apply the smallest runtime change, reconcile related objects, synchronize affected clients only, and then return an authoritative result. The current source does not establish this contract; no live editing UI is permitted to claim it today.

## 6. Integrations, Runtime, and Diagnostics

### Integrations and Adapters

Control Center adapters are currently mostly stubs. There is no verified registry discovery API that returns adapter names, versions, health, capabilities, configuration, or supported actions to the Control Center. A permanent hardcoded integration list would violate the plugin/adapter design.

An Integrations surface may be implemented only once the existing adapter registry or a documented extension exposes a truthful discovery/read contract. Adapter configuration must follow the future hot-configuration ADR.

### Runtime

The Core exposes partial observability primitives such as scheduler task listing and EventBus metrics. The administrative catalog and ADR-0027 describe a broader common service contract, but the current source does not implement those methods across the actual DCE domain services. ADR-0027 must be reconciled with the runtime before it is used as evidence of available functionality.

A Runtime surface should eventually distinguish Core, services, plugins, adapters, and sessions. It must use actual owner-provided status, health, metrics, and capabilities rather than synthetic health cards.

### Diagnostics

Diagnostics should present server-provided errors, warnings, validation failures, lifecycle problems, and available logs. Current frontend console error handling is not a diagnostics data source. No audit-log or diagnostic query contract is implemented, so a Diagnostics page cannot yet make authoritative claims.

## 7. Authorization, Persistence, and Failure Safety

The existing Control Center open permission check uses server-side FiveM ACE permissions. This is sufficient for access to the current Control Center shell but is not a substitute for per-operation authorization on future world, configuration, adapter, runtime, or diagnostic actions.

There is no DCE persistence system in the audited paths. Runtime-only in-memory mutation must never be labelled persisted. Persistent administrative operations require an owner, schema, migration/load behavior, and explicit error results before they are exposed.

Future administrative operations must follow:

```
authorize -> validate -> prepare -> apply -> persist when required -> synchronize -> confirm
```

On any failure, the server returns the failed stage and no success notification is shown. Where rollback is feasible, the owner defines it; the Control Center renders the actual outcome.

## 8. Current Status Matrix

| Intended area | Current status | V1 action now |
|---|---|---|
| Bounded Control Center shell and lifecycle | Implemented and live-tested | Preserve. |
| Operational navigation | Implemented with truthful no-data states | Preserve and extend only with real capabilities. |
| Configuration and hot configuration | Missing owner and runtime contract | ADR required; no UI mutation implementation. |
| World inspection | Domain reads partly exist; no CC transport | Document contract before adding UI. |
| Location authoring | Partial in-memory domain API | Complete only against existing Location Manager contract after persistence scope is decided. |
| Territory authoring | Unowned | ADR required. |
| Organization authoring | Adapter stubs; no contract | Do not implement in UI. |
| MLO/walkable interior authoring | Location types exist; ownership contract missing | Define provider contract first. |
| Integrations | No truthful discovery/read contract | Do not add static integration UI. |
| Runtime monitoring | Partial core primitives, no unified contract | Reconcile ADR-0027 before UI. |
| Diagnostics and audit | No service contract | Architecture required. |

## 9. Testing Requirements

The existing `dce-test-suite` remains the test architecture. No separate Control Center testing framework is required.

Current coverage is limited to source checks and broader DCE test-suite phases; no automated FiveM/CEF Control Center, hot-config, authoring, or persistence test exists.

Before any future capability is certified, add coverage to the existing suite for its owner and test in FiveM:

- Control Center open, close, ESC, `/dceclose`, focus release, reopen, and repeated-cycle behavior.
- Each navigation destination, selected state, error state, and unavailable state.
- Configuration read, authorization, validation, apply, persistence, affected-service refresh, failure, cancellation, and no-restart behavior.
- Location or world edits: authorization, validation, apply, persistence where intended, smallest runtime update, client synchronization, cleanup, and repeat operations.
- Adapter discovery, capabilities, configuration, errors, and unavailable states.
- Runtime and diagnostics payload correctness, redaction, and failure states.

## 10. V1 Boundaries and Extension Points

This scope alignment does not authorize V2 work, AI implementation, a Core rewrite, a second SDK, a second EventBus, a second registry, a second session/focus/browser system, a new frontend framework, a parallel persistence layer, or fabricated data.

The V1 extension points are existing service-registry access, the current Control Center lifecycle, the Location Manager/provider model, the existing adapter pattern, the existing EventBus, and the existing test suite. Each future administrative capability must first have exactly one service owner and a documented server-authoritative contract.

## 11. Recommendation

Preserve the current bounded V1 Control Center and its truthful operational pages. Do not add configuration, integration, runtime, diagnostic, territory, organization, MLO, or interior controls until their server-authoritative owner and contract exist.

The next architecture work is an ADR for runtime configuration and persistence, followed by an ADR assigning Territory ownership. Reconcile ADR-0027's claimed administrative interface completion with the actual service implementations before building Runtime or Diagnostics surfaces. After those decisions, implement the smallest owner-first capability and expose it in the Control Center only when server validation, authorization, application, and truthful result reporting are present.