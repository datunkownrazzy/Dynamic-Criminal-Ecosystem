# DCE Service Contracts

**Status:** Draft
**Version:** 0.1
**Owner:** Datunkownrazzy
**Applies To:** All modules that register Services through the Service Registry

---

## Purpose

This document defines the contract for how DCE modules expose and consume Services. It is the architectural reference for module boundaries, dependency resolution, and public API shape.

The Service Registry is the only approved boundary for cross-module interaction. This document turns that rule into a practical contract.

---

## Core Rules

1. A module may only expose its public API through a registered Service.
2. A module may only consume another module's behavior through the Service Registry or the Event Bus.
3. Every Service function must be documented at the point of definition.
4. Services must tolerate missing dependencies without crashing.
5. Service behavior must be stable enough to support plugin adapters and future replacements.

---

## Service Registration Contract

Each module that offers runtime functionality must register a Service under a stable name.

Recommended naming pattern:

- `world` for world state and simulation primitives
- `ai` for AI Director logic
- `dispatch` for Dispatch operations
- `evidence` for evidence services
- `territories` for territory state
- `economy` for economic simulation

The exact registration name must be documented by the module and used consistently across code and documentation.

---

## Service Interface Expectations

Every Service should define:

- its purpose,
- its input shape,
- its return shape,
- its failure mode,
- and whether it is read-only, state-mutating, or event-driven.

A Service should prefer narrow, composable operations over large "god methods". If a module needs a broad operation, it should expose a small set of focused Services rather than one overloaded interface.

### Example shape

```lua
DCE:RegisterService("evidence", {
    CreateEvidence = function(...) end,
    UpdateEvidence = function(...) end,
    GetEvidence = function(...) end,
})
```

The implementation is free to vary, but the documented contract must remain stable unless a breaking change is explicitly accepted.

---

## Dependency Resolution Contract

Modules must resolve dependencies lazily or reactively. A dependency may be absent at startup, disabled by configuration, or not yet registered.

Required behavior:

- a missing Service must not crash the caller,
- the caller must handle a nil result gracefully,
- and the module should re-evaluate when the dependency becomes available if that is relevant.

This contract protects the framework from brittle startup ordering and supports plugin/resource independence.

---

## Read vs Write Access

Services must be explicit about whether they allow mutation.

- A read-only Service may expose state inspection and derived information.
- A write-capable Service may mutate state owned by that module.
- A Service that wants another module to change state must request that change through the owning Service or an Event Bus request pattern, not by writing into another module's internal tables.

This is the primary enforcement point for Data Ownership and module isolation.

---

## Lifecycle Contract

A Service must be usable under the standard lifecycle defined in the State Machine contract:

- it may be registered during startup,
- it must be available once it reaches **Ready**,
- and it must be unregistered during shutdown.

A service that is not ready must not be treated as operational by other modules.

---

## Compatibility Rules

A Service contract is part of the public surface of DCE. Changes must be handled deliberately:

- additive changes are generally safe,
- changing argument order or semantics is breaking,
- and removing a Service function is a breaking change and should be treated as such.

If a module needs to evolve an interface, it should prefer versioning, adapter logic, or a new Service rather than silently changing behavior.
