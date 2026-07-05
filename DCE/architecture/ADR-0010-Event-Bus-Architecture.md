# ADR-0003: Event Bus Architecture

**Status:** Accepted
**Date:** 2026-07-04
**Author:** Architecture
**Dependencies:** DCE-0002 (Event Bus), EventContracts.md, DataOwnership.md

---

## Problem

`DCE-0002-Event-Bus.md` establishes the basic publish/subscribe mechanism (`DCE:Emit`, `DCE:On`) and `EventContracts.md` adds the payload envelope. Neither document answers several questions that matter once dozens of modules and plugins are all emitting and consuming events concurrently: are events delivered synchronously or asynchronously, what happens if a handler is slow or fails, can a missed event be replayed, does ordering matter, what happens if the same event fires twice, and how do event shapes change over time without breaking existing subscribers. This ADR answers all of them, formalizing and extending DCE-0002/EventContracts rather than replacing them.

## Decision

### Synchronous vs. Asynchronous Delivery

DCE events are **synchronous by default, non-blocking by convention.** `DCE:Emit` calls every registered handler in registration order, in the same tick, before returning — this matches DCE-0002's existing behavior and keeps event flow traceable (a developer reading `dce.debug event <id>` sees a linear chain, not a scattered async mess).

However, per DCE-0002's performance guidance, handlers **must not perform slow work synchronously.** A handler that needs to do expensive work (DB writes, HTTP calls to a CAD adapter, complex computation) must hand that work off to a scheduled task (`Scheduler.md`) or an async callback and return immediately. The Event Bus itself does not become asynchronous — the discipline of "handlers return fast" is what keeps synchronous delivery viable at scale. A handler that blocks the tick is a bug, not a case for making the whole bus async.

### Delivery Guarantees

DCE provides **at-most-once, in-process delivery.** There is no persistent event queue, no guaranteed redelivery, and no cross-restart durability of in-flight events. If a resource is stopped/crashed at the moment an event fires, subscribers in that resource simply don't receive it — this is an accepted limitation, consistent with `Persistence.md`'s accepted crash-recovery gap. Any state that must survive regardless of event delivery belongs in a Service's persisted state (`Persistence.md`), not solely in event-driven side effects.

### Ordering

**Ordering is guaranteed only within a single `DCE:Emit` call** — handlers for that event fire in registration order, deterministically. **Ordering across different event types is not guaranteed** relative to each other unless one causes the other (i.e., if handling event A causes an emit of event B, B is naturally delivered after A completes, since delivery is synchronous). Modules must not assume two independently-emitted event types arrive in a particular relative order unless a causal chain enforces it.

### Idempotency

Because delivery is at-most-once and in-process, duplicate delivery of the same logical event by the bus itself should not happen. However, **event handlers must still be written defensively as if they could be called twice** — a plugin subscribing to a Service's event and also independently polling the same Service's state could otherwise double-count an effect. This is a handler-authoring discipline, not a bus guarantee; call it out in `Coding_Standards.md`/`AGENTS.md` review checklists going forward.

### Replay

**No general replay mechanism exists in v1.0.** A resource that starts up after an event fired has genuinely missed it. Two patterns exist for cases where this matters:

1. **State over event, for anything a late-starting module needs to know "as of now."** If a module needs to know an Organization's current heat, it calls `Organizations.GetState(orgId)` (Service Registry) rather than trying to reconstruct history from missed events — this is the same "state over event" principle DCE-0001/Lifecycle documents already establish for service resolution.
2. **`service:registered:<name>` catch-up, for the one case DCE-0001 already handles** — a module reactively resolving a dependency the moment it becomes available, rather than needing to have "heard" every event since boot.

A durable, replayable event log (for audit/World Chronicle purposes) is explicitly a v1.5+ concern — flagged for a future ADR, not built now.

### Event Versioning

Per `EventContracts.md`'s envelope (`eventVersion` field), a breaking change to an event's payload shape requires a version bump, and the emitting module should, where feasible, continue emitting the previous version alongside the new one for a deprecation window (length TBD per event, documented at the point of the breaking change) rather than cutting over instantly. This mirrors the SDK/Service backwards-compatibility rule in `AGENTS.md` #14, applied specifically to events, since plugins are expected to subscribe to events far more often than they call Services directly.

### Error Isolation

Confirmed from DCE-0002: a handler that throws is caught and logged (`Logger.md`, `error` level, naming the event and the failing handler's source module) and does not prevent other handlers for the same event from running. This is non-negotiable — one broken plugin subscriber must never be able to stop Dispatch or Evidence from reacting to the same event.

## Consequences

- Synchronous delivery keeps the system easy to reason about and debug, at the cost of requiring real discipline from every handler author to avoid blocking work — this discipline is now an explicit, ADR-level requirement, not just a suggestion buried in DCE-0002.
- No replay/durability means any module that cares about "what happened while I was down" must persist its own state rather than relying on the event stream as a source of truth — consistent with `DataOwnership.md`'s single-owner model (the owning Service's persisted state is authoritative, events are a notification mechanism, not a system of record).
- Versioning discipline adds overhead to changing any existing event, in exchange for plugins not silently breaking on every DCE update.

## Related

- `specifications/DCE-0002-Event-Bus.md`
- `docs/02_Arcitecture/EventContracts.md`
- `docs/13_Persistence/Persistence.md`
- `docs/01_Project/PROJECT_PRINCIPLES.md` (#14 backwards compatibility, restated in `AGENTS.md`)
