# DCE Project Principles

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy

These are the non-negotiables. Anything proposed for DCE core — a feature, a PR, a plugin request — gets checked against this list. If it violates one of these without a documented, deliberate exception (see below), it doesn't get merged into core.

---

### 1. Crime is simulated, not spawned.
Every activity an organization performs should trace back to a reason: its goals, its resources, the world state around it. If the only justification for an event is "a timer fired," it's not ready.

### 2. Everything is data-driven.
Organization personalities, escalation chances, territory values, dispatch call weighting — these belong in config/data, not hardcoded in logic. A server owner should be able to reshape how DCE behaves without editing core Lua.

### 3. Every feature is optional.
No subsystem should be load-bearing for the others in a way that breaks the server if disabled. A server owner who doesn't want an Investigations system should be able to turn it off and keep everything else working.

### 4. No service directly depends on another service's internals.
Communication happens through the Service Registry and the Event Bus, not through one module reaching into another's tables or calling its internal functions directly. If Dispatch needs something from Evidence, it asks through the registered interface — it doesn't know or care how Evidence is implemented.

### 5. Plugins are first-class citizens.
The plugin/SDK path is not an afterthought bolted on after core is "done." Anything a plugin needs to do — register an organization, register a dispatch adapter, register a new scenario type — should be possible through a documented export, not by editing core files.

### 6. Every system exposes analytics.
If a system does something meaningful (an organization completes an activity, a territory changes hands, an investigation closes), it should emit an event onto the bus that an analytics/logging consumer can pick up — even if nothing consumes it yet.

### 7. Performance before features.
DCE is designed to run at FiveM server scale. A feature that sounds compelling but requires simulating full NPC AI for every organization on the map at all times is not acceptable. Use the layered simulation model — statistical simulation everywhere, full fidelity only near players.

### 8. Server owners own the experience.
DCE should support a heavily roleplay-paced server and a fast-action server equally well, through configuration — escalation odds, event frequency, simulation aggressiveness — not through separate forks.

### 9. Immersion over spectacle.
Prefer a dispatcher receiving a vague, realistic 911 call over the system just announcing "Gang Shootout Detected." Systems should behave the way the real thing would — imperfect information, gradual escalation, plausible civilian reactions — rather than being clean and legible for legibility's sake.

---

## Terminology

Use framework language consistently across code, comments, and docs:

| Instead of | Use |
|---|---|
| Script | Service |
| Event | Simulation Event |
| Gang | Organization |
| NPC | Agent |
| Crime | Scenario |
| Callout | Incident |

This isn't cosmetic — consistent vocabulary keeps the codebase and documentation coherent as more contributors and plugin authors get involved.

---

## Exceptions

Principles can be violated deliberately, but never silently. Any exception must be recorded as an ADR (Architecture Decision Record) in `/architecture/`, stating:

- Which principle is being bent
- Why
- What was considered instead
- What the consequences are expected to be

If it's not worth writing down, it's not worth the exception.
