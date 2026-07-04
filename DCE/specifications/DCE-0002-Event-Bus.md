# DCE-0002: Event Bus

**Status:** Accepted
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** DCE-0001 (Service Registry, for how the bus itself is accessed)


---

## Purpose

The Event Bus is the single internal publish/subscribe mechanism all DCE modules use to communicate state changes. It exists so that any number of interested systems — including plugins that core doesn't know about — can react to something happening, without the system that caused it needing to know who's listening.

This is the mechanism that makes the loop in `Vision.md` and `Architecture_Overview.md` actually work as independent, decoupled stages.

---

## Problem

If `dce-ai` needs to notify Dispatch, Evidence, Civilian AI, and Analytics every time an organization starts a drug deal, direct calls to each one create four hard dependencies — and a fifth system (a plugin) added later can't hook in without editing `dce-ai`.

## Design

### Publishing

```lua
DCE:Emit("organization:activity:started", {
    eventName = "organization:activity:started",
    eventVersion = 1,
    timestamp = os.time(),
    source = "dce-ai",
    correlationId = "org-001",
    payload = {
        organizationId = "families",
        activity = "drug_sale",
        location = coords,
        layer = 1,
    },
})
```

The event name follows a `domain:subject:verb` convention (see Naming Conventions below). Every event carries a stable envelope with `eventName`, `eventVersion`, `timestamp`, `source`, `correlationId` (when applicable), and `payload`; the payload itself remains a plain table and its shape should be documented per event name in the relevant system's specification.

### Subscribing

```lua
DCE:On("organization:activity:started", function(payload)
    -- react
end)
```

Handlers are called in registration order. A handler that errors is caught and logged; it must not prevent other handlers from running. One broken plugin subscriber should never be able to take down the simulation.

### Unsubscribing

```lua
local handlerId = DCE:On("organization:activity:started", fn)
DCE:Off("organization:activity:started", handlerId)
```

Resources must unsubscribe their handlers on stop (`AddEventHandler("onResourceStop", ...)`), to avoid stale handlers firing against a torn-down module.

### One-time Subscriptions

```lua
DCE:Once("service:registered:Dispatch", function()
    -- run exactly once, first time this fires
end)
```

Useful for lazy service resolution patterns described in `DCE-0001`.

---

## Naming Conventions

`domain:subject:verb`, all lowercase, colon-delimited.

Examples:
- `organization:activity:started`
- `organization:activity:escalated`
- `territory:ownership:changed`
- `evidence:item:recovered`
- `dispatch:call:created`
- `dispatch:call:updated`
- `service:registered:<name>` / `service:unregistered:<name>` (reserved, emitted by the Registry itself)

Event names are part of the framework's public surface — renaming one is a breaking change and should go through an ADR, since plugins may depend on it.

---

## Payload Discipline

- Events are emitted as envelope-wrapped tables. The envelope contains metadata and a `payload` field for domain data.
- Payloads are plain tables. No functions, no metatables with side effects, no passing live references to internal mutable state that a handler could accidentally corrupt — pass copies of anything a handler shouldn't be able to mutate.
- Every event's payload shape must be documented where it's emitted. "Just log it and see what's in there" is not an acceptable way for a plugin author to learn an event's shape.
- Prefer flat, small payloads. If a handler needs more detail than what's published, it should look it up through the relevant Service (`DCE-0001`), not receive an ever-growing payload "just in case."

---

## What Goes Through the Bus vs. What Doesn't

**Use the Event Bus for:**
- Anything another system might want to react to (state changes, lifecycle events, notable simulation moments).
- Anything a plugin should be able to observe without special-casing.

**Use direct Service calls (`DCE-0001`) for:**
- Asking a question and needing an answer back synchronously (e.g., "what's this organization's current heat?"). The Event Bus is fire-and-forget, not request/response.
- Commanding another system to do something specific right now (e.g., "create this dispatch call"), where you need to know it was accepted.

If you find yourself emitting an event and then immediately checking service state hoping the handler already ran, you wanted a Service call, not an event.

---

## Performance Considerations

- The bus must not become a bottleneck for Layer 0 statistical simulation, which may be updating many organizations per tick. High-frequency internal bookkeeping (e.g., incrementing a per-tick counter) should not go through the Event Bus — reserve it for meaningful, relatively infrequent occurrences.
- Handlers must be fast. If a handler needs to do expensive work (DB writes, complex computation), it should queue that work rather than doing it synchronously inside the bus dispatch call, so one slow subscriber can't stall every publisher.

---

## API Surface

```lua
DCE:Emit(eventName, payload)

DCE:On(eventName, handlerFn) -> handlerId

DCE:Once(eventName, handlerFn) -> handlerId

DCE:Off(eventName, handlerId)
```

---

## Consequences

- Debugging a chain of effects requires tracing through subscribers rather than reading a linear call stack — the developer console's planned `dce.debug event <id>` tooling (see `Architecture_Overview.md`) exists specifically to make this traceable at runtime.
- Because event names are stringly-typed, a typo in either the emit or the subscribe silently does nothing. A startup-time registry of "known event names" (populated as specs are written) is worth considering later as a lint/validation aid — flagged here as a future improvement, not a v1.0 requirement.
