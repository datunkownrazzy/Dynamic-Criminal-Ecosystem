# DCE-0005: Hot Configuration

**Status:** Accepted  
**Version:** 1.0  
**Owner:** Core  
**Dependencies:** DCE-0001, DCE-0002, ADR-0030

## Purpose

Define a single server-authoritative configuration transaction contract for DCE V1. This specification does not create V2 capabilities or require that all domains be editable.

## Ownership

`ConfigurationService` owns authorization, transaction sequencing, and results. A domain owner owns data validation, normalization, runtime application, serialization, restoration, and revision generation. An adapter only translates the domain contract for a consumer such as Control Center.

## Domain Target Contract

An editable target registers these server-only methods:

```lua
GetSnapshot(targetId) -> snapshot | nil
GetRevision(targetId) -> string | number | nil
GetCapabilities(targetId) -> capabilities
ValidateChange(targetId, operation, patch, current) -> ok, normalizedPatch | error
ApplyChange(targetId, operation, normalizedPatch) -> ok, snapshot | error
```

A persistable target also registers:

```lua
Serialize(targetId) -> record | error
Restore(targetId, record) -> ok | error
```

`operation` is one of `create`, `update`, or `delete`. Move is an update of validated coordinates or bounds. Revert is a client action that discards its unsubmitted patch and never requires a server transaction.

## Transaction Request

The server accepts:

```lua
{
  target = "world.location",
  targetId = "optional-id",
  operation = "create|update|delete",
  expectedRevision = "optional-revision",
  patch = {}
}
```

The source player is derived from the FiveM network event and is never supplied by NUI. The server validates permissions, target availability, capabilities, request shape, revision, and patch before persistence or runtime mutation.

## Transaction Result

```lua
{
  code = "SUCCESS|VALIDATION_ERROR|PERMISSION_DENIED|NOT_FOUND|UNAVAILABLE|UNSUPPORTED|STALE_REVISION|PERSISTENCE_ERROR|RUNTIME_APPLY_ERROR|TIMEOUT|PROVIDER_ERROR",
  message = "human-readable safe reason",
  target = "world.location",
  targetId = "id",
  revision = "authoritative revision",
  runtimeApplied = false,
  persisted = false,
  restartRequired = false,
  snapshot = {}
}
```

Only `SUCCESS` allows the Control Center to show Applied. `persisted` distinguishes a durable save from a runtime-only operation.

## Synchronization

After a successful transaction, the domain owner emits `configuration:changed` through the existing EventBus with an event envelope and the authoritative snapshot or target reference. The Control Center adapter forwards normalized, authorized updates only to active sessions that are permitted to observe the target. No polling loop is required.

## V1 Availability

Current V1 domain capabilities are:

| Target | Current state | Reason |
|---|---|---|
| `world.location` | Available | LocationManager provides validation, revision tracking, durable persistence, runtime apply, and authoritative events. |
| `world.territory` | Unavailable | An implementation exists but has not completed V1 hot-edit certification. |
| `organization` | Unavailable | Control Center has no adapter contract to the organization owner or persistence. |
| `runtime.configuration` | Unavailable | ConfigManager is read-only and no `UpdateConfig` runtime implementation exists. |
| `dispatch`, `evidence`, `scenario`, `economy`, `intelligence`, `integration` | Unavailable | No V1 editable domain contracts have been verified. |

The Control Center may display these states but must not expose apply controls until the associated target contract is implemented and certified. `restartRequired` is valid only when an implemented and certified domain contract explicitly declares that a setting cannot be hot-applied safely; it must never be inferred from a missing V1 contract.
