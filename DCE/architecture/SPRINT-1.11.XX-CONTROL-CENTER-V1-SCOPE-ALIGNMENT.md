# Control Center V1 Scope Alignment

## Purpose

The DCE Control Center is the administrative presentation layer for the DCE ecosystem. It observes and invokes existing server contracts; it does not own configuration, world state, integrations, runtime state, persistence, or authorization.

The current V1 retains the bounded NUI window and the existing `/dce`, `/dceclose`, ESC, session, focus, browser, lifecycle, EventBus, Registry, and Scheduler foundations.

## V1 Responsibilities

### Operations

The navigation exposes Home, World, Territories, Organizations, Scenarios, Dispatch, Evidence, Economy, and Intelligence through the existing plugin model. Home is an operational summary, not a developer console. Existing pages report unavailable data when their backend contract does not return data.

World currently provides read access to locations and territories through the `LocationManager` service. The NUI requests data through the client bridge, the server validates ACE access, and the server reads the registered service. The NUI is never authoritative.

### Administration

Configuration, Integrations, Runtime, and Diagnostics are first-class navigation destinations. In V1 they report their actual unavailable state where the required server contracts are absent. These pages are extension points, not fabricated dashboards.

## Authority and Data Flow

Administrative requests follow this boundary:

`NUI -> client NUI callback -> server event -> Control Center permission check -> DCE service or adapter -> client response -> NUI`

The server owns authorization and authoritative data. The current data bridge returns `ok`, `unavailable`, or `error`; the UI must not display success for an unavailable or failed response.

## Configuration and Hot Configuration

No V1 runtime configuration read/validate/apply/persist contract is currently registered for the Control Center. The Control Center therefore does not expose edit, Save, Apply, or restart claims for configuration. A future implementation must use the existing configuration owner and persistence owner, validate and authorize on the server, apply the smallest runtime change, notify affected services, persist when required, and confirm the actual result to the NUI.

Required states are: `saved`, `unsaved`, `validating`, `applying`, `applied`, `validation failed`, `apply failed`, and `unavailable`.

## World Authoring

`dce-world` owns locations and territories through `LocationManager`, including in-memory create/update/delete methods and provider support for vanilla, walk-in MLO, instanced, and hybrid locations. The current Control Center integration is read-only because persistence, administrative mutation routing, atomic application, and player synchronization are not yet provided by a complete Control Center contract.

V1 must not add a second world store, MLO system, territory registry, or persistence layer. Future authoring must delegate to `LocationManager` and its providers and must define validation, duplicate detection, persistence, runtime application, cleanup, and synchronization before exposing mutation controls.

Organizations currently have an adapter shape but its list/get/create/update/delete methods are stubs. Organization authoring remains unavailable until the owning organization service and persistence contract are available.

## Integrations and Adapters

Adapters remain translators owned by the Control Center integration boundary. The current adapter files do not provide a registry-backed discovery contract or uniformly real status, health, capability, configuration, and action data. V1 does not fabricate adapter inventory or reconnect/configuration actions.

## Runtime and Diagnostics

Session lifecycle and focus management are implemented and remain owned by their existing services. Detailed service, plugin, scheduler, EventBus, runtime health, error history, and diagnostics views are unavailable until corresponding read contracts exist. Home may summarize only data that is actually supplied.

## Authorization

The existing `ControlCenterService.HasPermission` ACE check is the server gate for Control Center data requests. Client input is treated as untrusted. No duplicate permission system is introduced. Future mutation endpoints must repeat authorization and validate the complete request on the server.

## Persistence

The current location manager stores runtime state in memory and clears it during shutdown. The Control Center does not claim persistence for locations or territories. Persistent configuration and world authoring require the existing persistence owner; a new storage system is out of scope.

## Current Implementation Status

| Area | V1 status |
| --- | --- |
| Bounded application and lifecycle | Implemented; preserve existing contracts |
| Operations navigation and plugin lifecycle | Implemented/partial; existing plugins remain contract-driven |
| World/location read surface | Implemented through server-authorized `LocationManager` reads |
| Territory read surface | Implemented through server-authorized `LocationManager` reads |
| Organization read/CRUD | Unavailable; adapter methods are stubs |
| Configuration read/edit/hot apply | Unavailable; no runtime Control Center contract |
| World mutation and persistence | Unavailable from Control Center; no complete mutation/persistence boundary |
| MLO and walkable interior authoring | Unavailable from Control Center; provider model exists but authoring contract does not |
| Adapter discovery and actions | Unavailable; no registry-backed Control Center contract |
| Runtime detail and diagnostics | Unavailable; only lifecycle/session foundations are present |

## V1 Boundaries

This scope does not implement AI, autonomous behavior, V2 architecture, a duplicate SDK, EventBus, Registry, Scheduler, lifecycle, configuration, adapter, world, or persistence system, or speculative frontend infrastructure.

## Required Follow-up Contracts

Before enabling mutation controls, define the owning service API and tests for: server validation, ACE authorization, duplicate/reference checks, atomic prepare/apply/persist behavior, runtime refresh, failure rollback or safe revert, client synchronization, and restart persistence. Each capability should then be added as a plugin or plugin-backed view using the existing manifest and lifecycle model.

## Test Requirements

The existing DCE test suite should cover:

- `/dce`, NUI load, boot, session start, close, ESC, `/dceclose`, reopen, and repeated open/close without leaked focus or handlers.
- Every navigation destination, including truthful unavailable states and selected-state behavior.
- World and territory reads with authorized, denied, empty, unavailable, and malformed service responses.
- Future configuration tests for validate, authorization, apply, persistence, runtime refresh, cancellation, and failure without restarting FiveM.
- Future world authoring tests for validation, live application, synchronization, cleanup, and persistence without restarting FiveM.

The current read integration can be syntax-checked with `node --check` for the NUI JavaScript. Runtime validation requires a FiveM server with `dce-core`, `dce-world`, and ACE permissions loaded.
