# DCE State Machine Contract

**Status:** Draft
**Version:** 0.1
**Owner:** Datunkownrazzy
**Applies To:** Services, Scenarios, Incidents, Territories, Organizations, Evidence, and other long-lived simulation entities

---

## Purpose

This document standardizes the lifecycle model used across DCE. The goal is to make every service and long-lived entity behave predictably so that startup, shutdown, failures, and recovery can be reasoned about consistently.

A shared state model reduces ambiguity and prevents one subsystem from treating a resource as "ready" while another still considers it "starting" or "stopped".

---

## Core Model

All long-lived DCE modules and entities should follow the same state progression:

```text
Uninitialized -> Starting -> Ready -> Active -> Pausing -> Stopping -> Stopped
                     \-> Failed
```

### State Definitions

- **Uninitialized**: the module or entity exists only as a definition; no runtime resources are active.
- **Starting**: initialization work is underway; dependencies may still be resolving.
- **Ready**: the module or entity is initialized and can accept normal work.
- **Active**: the module or entity is currently participating in the simulation loop.
- **Pausing**: the entity is temporarily suspending activity, often due to budget pressure or a dependency pause.
- **Stopping**: shutdown has begun and cleanup work is underway.
- **Stopped**: the entity is no longer active and has completed cleanup.
- **Failed**: initialization or runtime work failed and the entity cannot continue without intervention.

---

## Service State Rules

Services registered through the Service Registry must expose a lifecycle state that can be inspected by other modules.

### Required transitions

- A service may transition from **Uninitialized** to **Starting** once its dependencies are resolved.
- A service may transition from **Starting** to **Ready** when initialization completes successfully.
- A service may transition to **Active** once it is safe to participate in the simulation loop.
- A service may transition to **Pausing** only if it can later resume without reinitializing.
- A service may transition to **Stopping** during resource shutdown.
- A service may transition to **Stopped** only after all cleanup is complete.
- A service may transition to **Failed** if initialization or runtime behavior becomes unrecoverable.

### Transition guarantees

- A state transition must be observable through logging and, where relevant, through an Event Bus event.
- A service must not expose a partially initialized interface as though it were fully ready.
- A service that cannot reach **Ready** must not begin simulation work.

---

## Entity State Rules

Long-lived entities such as Scenarios, Incidents, Territories, and Organization state containers should also use this lifecycle model.

### Example

- A newly created Scenario starts as **Uninitialized**.
- Once its dependencies and initial state are loaded, it moves to **Starting**.
- When it is ready to begin logic, it becomes **Ready**.
- Once it has active simulation or player-facing behavior, it becomes **Active**.
- If the surrounding world becomes temporarily unsuitable, it may enter **Pausing**.
- When complete or canceled, it enters **Stopping** and then **Stopped**.

---

## Event and API Expectations

A state change must be communicated in one of two ways:

1. through a documented Service method or property, or
2. through an Event Bus event for systems that need to react asynchronously.

State changes should not be inferred by reading a module's internal tables.

---

## Failure Handling

If a module or entity fails:

- it must enter **Failed**,
- it must emit enough data to diagnose the failure,
- and it must not leave partially registered services or dangling subscriptions behind.

Recovery from **Failed** is allowed only if the module explicitly supports recovery; otherwise the correct next state is **Stopped**.

---

## Shutdown Requirements

On shutdown, every module must:

1. transition to **Stopping**,
2. cancel any scheduled tasks,
3. unsubscribe event handlers,
4. unregister services if they were registered,
5. and finalize state in a way that allows clean resource restart.

A restart must not leave stale state in memory or in the Service Registry.
