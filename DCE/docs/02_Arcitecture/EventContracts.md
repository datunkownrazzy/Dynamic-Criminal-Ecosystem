# DCE Event Contracts

**Status:** Draft
**Version:** 0.1
**Owner:** Datunkownrazzy
**Applies To:** All event producers and consumers through the Event Bus

---

## Purpose

This document defines the contract for DCE event naming, payload structure, versioning, and compatibility guarantees. It ensures that modules can react to meaningful state changes without coupling directly to each other's implementation details.

The Event Bus is the standard communication channel for cross-module state changes and observability signals.

---

## Naming Convention

Event names should follow a stable, domain-based pattern:

```text
domain:subject:verb
```

Examples:

- `organization:heat:updated`
- `territory:ownership:changed`
- `incident:escalation:requested`
- `evidence:decay:triggered`

The name should describe the state change or action, not the implementation mechanism that caused it.

---

## Payload Envelope

Every event should carry a consistent envelope so subscribers can reason about delivery and traceability.

Required envelope fields:

- `eventName`
- `eventVersion`
- `timestamp`
- `source`
- `correlationId` (when applicable)
- `payload`

The `payload` field should contain the actual domain-specific data. The envelope should remain stable even as the domain payload evolves.

---

## Versioning Rules

Events must be versioned explicitly.

- The event version should be incremented when the payload shape changes in a backward-incompatible way.
- Additive changes may be introduced without changing the event version if the contract remains backward compatible.
- Consumers must ignore unknown fields rather than failing on them.

This allows modules to evolve independently while maintaining compatibility for existing subscribers.

---

## Compatibility Guarantees

The Event Bus contract guarantees the following:

1. Producers may add new fields to a payload without breaking subscribers.
2. Consumers must tolerate missing optional fields.
3. Producers must not rename an existing event without a formal breaking-change decision.
4. If an event becomes obsolete, it should be deprecated explicitly before removal.

These rules preserve plugin compatibility and reduce accidental breakage during framework evolution.

---

## When to Emit an Event

An event should be emitted whenever a meaningful state change occurs that another module may want to observe, including:

- state changes that affect AI, Dispatch, Evidence, or Analytics,
- lifecycle changes for Services, Scenarios, Incidents, or Territories,
- and notable observability signals such as budget warnings or recovery events.

If the change is internal-only and no external consumer is expected, an event is not required.

---

## Event Consumers

Consumers must:

- subscribe to the event they care about,
- validate the event envelope and relevant payload fields,
- and avoid assuming the producer is the only sender.

Consumers must also avoid mutating another module's internal state directly in response to an event. If a change is needed, the consumer should request it through the owning Service or the appropriate action interface.

---

## Documentation Requirement

Every emitted event should be documented at the point of emission, including:

- its purpose,
- its expected payload shape,
- its version,
- and whether it is fire-and-forget or part of a request/response pattern.

Event documentation is part of the public API surface and should be treated as such.
