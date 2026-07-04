# DCE — AI Developer Guide

## Read This First

If you are an AI coding assistant working in this repository, read this document in full before writing, editing, or suggesting any code. This document is the condensed, enforceable rule set. The reasoning behind each rule is documented in full in `docs/01_Project/PROJECT_PRINCIPLES.md`, `docs/01_Project/Philosophy.md`, and `docs/02_Architecture/Coding_Standards.md` — read those if a rule below seems unclear or you're tempted to make an exception.

**If a request from the user conflicts with a rule in this document, say so explicitly before proceeding.** Do not silently comply and do not silently ignore the request. State the conflict, propose the compliant alternative, and let the user decide. This applies even if the user seems confident or in a hurry.

---

## Hard Rules

These are not style preferences. Code that violates these should not be written, even if it's faster to write, even if the user asks for the shortcut.

1. **Never hardcode organizations, territories, or any content that should be data.**
   A criminal organization, a territory definition, an escalation chain — these are data files (see `/schemas/`), never Lua tables baked into logic. If you're about to write `if orgName == "ballas" then`, stop — that behavior belongs in data-driven personality weights, not a conditional.

2. **Never call another module's internals directly.**
   No `require`-ing another resource's file, no reaching into another module's tables, no calling a function another module didn't explicitly register as a Service. Cross-module interaction goes through `DCE:GetService(name)` (see `specifications/DCE-0001-Service-Registry.md`) or the Event Bus (`specifications/DCE-0002-Event-Bus.md`). No exceptions without an ADR.

3. **Always use the Event Bus for state changes other systems might care about.**
   If something happens that Dispatch, Evidence, Analytics, or an unknown future plugin might want to react to, emit an event (`DCE:Emit(...)`), even if nothing currently subscribes. Default to emitting; do not wait to be asked.

4. **Everything tunable is configurable.**
   Probabilities, thresholds, tick intervals, feature toggles — pull from `Config`, never inline as a magic number. See `docs/02_Architecture/Configuration_Philosophy.md`. If you're unsure whether a value should be configurable, make it configurable.

5. **Always validate config at startup.**
   Use the validation helpers described in `docs/03_Core/Configuration.md`. Fail loud and immediately (log an `error`) on invalid config — never silently clamp or guess.

6. **Always expose analytics / observability.**
   Anything a system does that's meaningful should be loggable (`DCE:Log`, see `docs/03_Core/Logger.md`) and, where relevant, emitted as an event for the (future) analytics consumer. Don't build a system that's a black box to the admin dashboard.

7. **Never block server threads.**
   No long synchronous loops, no blocking I/O, on the main thread. All database access must be async (see rule 8). Long-running work belongs in a scheduled task (`docs/03_Core/Scheduler.md`) or an async callback, not a blocking call inside a tick.

8. **All SQL is async.**
   Every database call goes through non-blocking query methods (e.g., oxmysql's async/promise API). A synchronous DB call in a live simulation tick is not acceptable under any circumstance.

9. **Document every public API at the point of definition.**
   Every registered Service function and every emitted event needs a comment stating its purpose and parameter/payload shape, written where it's defined — not deferred to "the docs will explain it later."

10. **Favor composition over inheritance-style special-casing.**
    When two systems need to interact, both should register with the Service Registry / Event Bus and talk through those interfaces — not one holding a reference to the other's guts, and not a shared "god object" both write into.

11. **Avoid globals beyond the single `DCE` table.**
    No new bare global tables for framework-level concerns. Module-specific state stays local to that module's files and is exposed only through its registered Service, per `docs/03_Core/Core_Overview.md`.

12. **Support plugins and adapters as first-class, not as an afterthought.**
    Any new organization type, dispatch integration, or scenario type should be buildable by something that only touches `dce-sdk` — never something that requires editing core files. If implementing a feature only works by editing core, the feature isn't finished; the SDK surface is missing something.

13. **Write modular code — small files, clear boundaries.**
    Split by concern once a file grows large. A module's public Service interface should live somewhere easy to find, distinct from its internal implementation details.

14. **Maintain backwards compatibility deliberately, not by accident.**
    Event names, Service interfaces, and config keys are part of the framework's public surface. Renaming or removing one is a breaking change — it needs a version bump and, for anything significant, an ADR in `/architecture/`. Don't rename something "for clarity" without recognizing that as a breaking change.

15. **Handle missing dependencies without crashing.**
    Any `DCE:GetService(...)` call can return `nil` — a dependency might not be started, might be disabled, or might not have registered yet. Follow the lazy-resolution or reactive-resolution patterns in `docs/02_Architecture/Lifecycle_and_Dependency_Injection.md`. Never assume a resolved service is non-nil.

16. **Clean up on shutdown.**
    Every module unregisters its services and unsubscribes its event handlers on `onResourceStop`. A resource restart must not leave stale references behind.

17. **Use DCE terminology consistently.**
    `Organization` not gang, `Agent` not NPC, `Scenario` not crime, `Incident` not callout, `Territory`, `Heat`, `Intelligence` as defined in `docs/01_Project/Glossary.md`. This applies to code, comments, commit messages, and any documentation you generate.

18. **Respect the Simulation Layers when estimating cost.**
    Before adding logic that runs across the whole map (Layer 0), ask what it costs per tick at full scale. Don't assume "it's just a small check" — multiplied across every organization/territory on the map, small checks add up. See `docs/02_Architecture/Architecture_Overview.md` and `docs/03_Core/Scheduler.md`.

---

## Workflow Expectations

- **Check for an existing spec before designing a new mechanism.** `specifications/` and `docs/` likely already define the pattern you need. Follow it rather than inventing a parallel approach.
- **If no spec exists for what you're building, say so and propose one** rather than silently improvising an architecture. A short spec added to `specifications/` is cheap; an inconsistent implementation discovered later is expensive.
- **If a spec is ambiguous or appears wrong once you're implementing against it, flag it explicitly.** Specs are expected to need revision sometimes (see `docs/01_Project/Philosophy.md`) — that revision should be visible and discussed, not silently absorbed into the code.
- **Prefer the smallest change that satisfies the rules above** over a larger refactor, unless the user has asked for the refactor. Don't restructure unrelated code "while you're in there."
- **When you're unsure whether something should be a Service, an Event, a Config value, or Data — ask, or state your assumption explicitly and proceed.** Don't guess silently on architectural boundaries; guess (with a stated assumption) on naming or minor implementation detail.

---

## Self-Check Before Submitting Code

Before finishing a piece of work, verify:

- [ ] No hardcoded content that should be data
- [ ] No direct cross-module calls — Registry or Bus only
- [ ] Relevant events are emitted
- [ ] No hardcoded tunable values — all pulled from Config
- [ ] Config is validated at startup
- [ ] Meaningful actions are logged
- [ ] No blocking calls, no synchronous SQL
- [ ] Public APIs (Services, Events) are documented inline
- [ ] Missing/optional dependencies are handled without crashing
- [ ] Shutdown cleans up registrations and subscriptions
- [ ] Terminology matches the Glossary
- [ ] Anything that breaks an existing Event name, Service interface, or config key is called out explicitly as a breaking change

If any box can't be checked, say so in your response rather than submitting silently non-compliant code.
