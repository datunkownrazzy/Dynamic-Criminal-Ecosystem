# ADR-0030: Server-Authoritative Hot Configuration Contract

**Status:** Accepted  
**Date:** 2026-09-06  
**Owner:** Architecture  
**Dependencies:** DCE-0001, DCE-0002, ADR-0027, ADR-0029

## Context

The Control Center has an established V1 NUI shell and read-only data request path. The World `LocationManager` can mutate its in-memory location and territory cache, but it has no validation, revision tracking, persistence, or public transaction boundary. Core `ConfigManager` is read-only. No public SDK method implements the documented `UpdateConfig` operation.

The Control Center must not mutate these owners directly or report success before a server-side operation has been applied. The V1 location target is now certified through the existing LocationManager transaction path; territory editing remains unavailable until an area-geometry contract is implemented.

## Decision

`ConfigurationService` is the sole owner of generic configuration transactions. It is a Core service exposed through the canonical SDK and must be resolved through `DCE:GetService()` by resource-local server adapters.

It owns only transaction orchestration. Domain services remain owners of their data and runtime behavior:

- `LocationManager` owns locations and territories.
- `Organizations` owns organization records.
- Each integration or plugin owns its own provider-specific configuration.

The service accepts a target, operation, patch, and expected revision. It performs, in order:

1. server-side authorization through a supplied policy;
2. capability discovery from the domain owner;
3. schema validation and normalization from the domain owner;
4. stale-revision validation;
5. persistence through a registered storage provider, when the capability requires persistence;
6. runtime apply through the domain owner;
7. compensating rollback when runtime apply fails after persistence;
8. an authoritative result and a normalized `configuration:changed` event only on success.

No NUI client may select a service function, bypass authorization, or write storage directly. The Control Center remains a presentation client and communicates through its existing NUI callback and session lifecycle.

## Result Contract

Every operation returns a result with `code`, `message`, `target`, `revision`, `runtimeApplied`, `persisted`, and `restartRequired`.

Valid `code` values are `SUCCESS`, `VALIDATION_ERROR`, `PERMISSION_DENIED`, `NOT_FOUND`, `UNAVAILABLE`, `UNSUPPORTED`, `STALE_REVISION`, `PERSISTENCE_ERROR`, `RUNTIME_APPLY_ERROR`, `TIMEOUT`, and `PROVIDER_ERROR`.

Capabilities must state whether an action is `available`, `unavailable`, `unsupported`, or `restartRequired`. `restartRequired` is reserved for an implemented and certified domain contract whose owner explicitly determines that a particular setting cannot be hot-applied safely. A missing, incomplete, or uncertified domain contract is always `unavailable`, never implicitly restart-only. Optional providers that are absent report `notInstalled`; their absence is not a DCE error.

## Persistence and Atomicity

Storage is provider-owned and optional by target. A target that has no storage provider must be reported as `UNAVAILABLE`; it cannot claim persistence. A runtime-only capability must explicitly report `persisted = false`.

Before a target is advertised as editable, its domain owner must provide `GetSnapshot`, `ValidateChange`, `ApplyChange`, and `GetRevision`. Persisted targets must additionally provide `Serialize` and `Restore`. Runtime apply failures must restore persisted state when possible and must not emit a success event.

## Consequences

- V1 cannot expose editable runtime configuration, organizations, territories, scenarios, integrations, or provider settings until the relevant domain contract and storage provider exist. Locations are editable through the certified LocationManager target.
- The existing Control Center shell, FocusManager, BrowserManager, sessions, EventBus, plugin manager, and adapters are reused.
- A later implementation requires SDK/public API and service-lifecycle changes; this ADR must be accepted before those changes begin.
