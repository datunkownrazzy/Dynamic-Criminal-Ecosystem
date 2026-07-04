# DCE Philosophy

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy

---

Vision says *what* DCE is trying to be. Principles say *what's non-negotiable*. This document explains *how we think about problems* when neither of those gives a clean answer — the reasoning style behind the design, so future decisions stay consistent even when they're not explicitly covered yet.

---

## Simulate causes, not effects

The instinct when building a "gang script" is to work backward from the interesting moment — the shootout, the pursuit, the raid — and script the steps that produce it. DCE works forward instead: model the organization's state and goals, let the AI Director evaluate what's plausible given that state, and let the interesting moment emerge as a byproduct.

This is slower to design and harder to guarantee "cool moments" on demand. It's worth it because scripted effects repeat in ways players notice within weeks, while emergent causes don't.

## Uncertainty is a feature, not a bug

A real dispatcher doesn't know what's actually happening at a scene — they know what a panicked caller said. DCE should preserve that gap deliberately. Every time we're tempted to hand a system perfect information ("Gang Shootout Detected," coordinates, suspect count), we should ask whether a human witness would actually know that. If not, degrade the information before it reaches dispatch.

This also applies to the AI itself: organizations shouldn't have perfect knowledge of police activity, rival plans, or player identities. They should act on what they've actually observed or been told, and be wrong sometimes.

## Prefer systems over content

Every time it's tempting to hand-author a specific scenario end-to-end, ask whether it could instead be an instance of a general system. A hostage situation shouldn't be a special-cased script; it should be one possible escalation outcome of the general Event Escalation system, configured with its own stages. A new criminal organization shouldn't require new core code; it should be data plus behavior weights loaded through the plugin system.

Content built as one-offs doesn't compound. Content built as configuration of a general system compounds — a new escalation stage or organization archetype becomes available to everything else in the framework, not just the feature it was built for.

## Composition over inheritance-style special-casing

When two systems need to interact (say, Evidence and Investigations, or Dispatch and Evidence), the default should be: both register with the Event Bus and Service Registry, and interact through published interfaces. The default should not be: one system imports the other's internals, or a god-object holds references to everything. This is what principle #4 in `PROJECT_PRINCIPLES.md` is protecting, and it's worth restating here as a design instinct, not just a rule — it changes how you structure new code from the first line, not just how you review it afterward.

## Configuration is a UI, not an escape hatch

Config files aren't just where advanced users go to tweak numbers — they're the primary way server owners express what kind of server they're running. A drug-deal-heavy server and a mostly-quiet server should be reachable by changing config values (event weights, escalation probabilities, simulation aggressiveness), not by forking code. If achieving a particular server "feel" requires a code fork, that's a sign the relevant system isn't data-driven enough yet.

## Performance constraints shape design, not just implementation

The layered simulation model (Statistical → Ambient → Interactive → Major Incident) isn't an optimization applied after the fact — it's a design constraint from the start. When designing any new system, ask up front: what does this cost at Layer 0, running for every organization on the entire map, all the time? If the honest answer is "too much," the system needs a cheap statistical approximation before it gets a full-fidelity version, not instead of one.

## Write the spec before the code, but expect the spec to be wrong sometimes

Specifications (`/specifications/`) exist so implementation has a stable target and so multiple contributors (human or AI) build consistently. They are not sacred. If implementation reveals a spec was wrong, the spec gets updated and the change gets recorded — silently deviating from a spec without updating it is worse than not having one.

## Extensibility is earned by discipline, not by APIs alone

Exposing an export doesn't make something extensible if the underlying system is tightly coupled elsewhere. Real extensibility comes from consistently following the Service Registry / Event Bus pattern everywhere, so that the seams a plugin needs already exist throughout the codebase — not just at the one integration point someone remembered to expose.
