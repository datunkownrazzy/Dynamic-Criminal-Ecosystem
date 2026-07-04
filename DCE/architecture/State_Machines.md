# DCE State Machines

**Status:** Accepted
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** Organizations.md, Territories.md, Investigations.md, StateMachine.md, ADR-0005, Event_Catalog_v1.md

---

## Purpose

This document consolidates the explicit state machines for every major domain in one place, so a contributor doesn't have to hunt through individual domain specs to see the full picture. It resolves a conflict surfaced during the last architecture review: a competing, linear/terminal state model was proposed for Organizations and Territories, but the project decision is to **keep both cyclic**, as originally defined in `Organizations.md` and `Territories.md`. This document records that decision explicitly so it isn't re-litigated by accident in a future doc pass.

`StateMachine.md` (Service/lifecycle states — Uninitialized/Starting/Ready/etc.) governs *code modules*. This document governs *simulation entities* (Organizations, Territories, Investigations). They're related patterns applied to different things and don't conflict with each other.

---

## Organization State Machine (Canonical — Cyclic)

```
Dormant → Growing → Stable → Aggressive Expansion → Conflict → Under Investigation → Suppressed → Recovering → (back to Growing)
```

**Decision:** This is the canonical model, per `Organizations.md`, confirmed and kept as-is. The alternative linear/terminal model proposed during the Phase 2 planning discussion (`Dormant → Growing → Established → Dominant → Fragmenting → Collapsed`) is **rejected** for v1.0.

### Why Cyclic, Explicitly

The project's stated reason: Organizations and Territories are meant to be able to **splinter and recover**, not simply terminate. A hard `Collapsed` end-state would mean once an Organization is sufficiently weakened, the simulation has nothing left to do with it — no comeback, no fragment absorbing into a rival, no long-term story the way `Vision.md` and the original design conversations describe ("Later: Ballas reclaim territory... A month later: Cartel moves in. Both gangs unite."). The cyclic model preserves that.

### How Splintering Fits the Cyclic Model

Splintering (`OrganizationSplit`, per `Event_Catalog_v1.md`) is **not** a terminal state — it's a transition that can fire from `Suppressed` or `Conflict` (per the internal-politics mechanic already described in earlier design docs: a dead/arrested leader can trigger fragmentation rather than automatic dissolution). When a split occurs:

1. The original Organization either continues (now weaker, likely re-entering `Suppressed` → `Recovering` → `Growing`) or is dissolved if nothing meaningful remains.
2. Each resulting fragment is spawned as a **new Organization** (`organization:lifecycle:created`, per `Event_Catalog_v1.md`), starting its own lifecycle at `Dormant` or `Growing` depending on how much it inherited (members, territory, resources) from the parent.

This means "collapse" isn't a state at all in the canonical model — it's simply what happens when an Organization has nothing left to fragment into and nothing left to recover with, at which point `organization:lifecycle:destroyed` fires and the Organization ceases to exist. Destruction is an *outcome* of the cycle failing to find a recovery/splinter path, not a state in the cycle itself.

### Transition Ownership

Per `ADR-0005`, Organizations owns this state machine exclusively. The AI Director reads Organization state to make decisions but does not itself set `org.state` — it issues Commands (`Command_Catalog_v1.md`) that Organizations validates against its own current state before transitioning.

---

## Territory State Machine (Canonical — Cyclic)

```
Neutral → Claimed → Established → Prosperous → Contested → Violent → Police Crackdown → Recovered → (back toward Claimed/Established, per below)
```

**Decision:** Confirmed canonical per `Territories.md`, kept as-is. The alternative model proposed during Phase 2 planning (`Neutral → Contested → Occupied → Fortified → UnderRaid → Abandoned`) is **rejected** for v1.0, for the same reason as Organizations — the project wants territories capable of being fought over indefinitely, not permanently written off at an `Abandoned` end-state.

### Recovery Path

`Recovered` does not mean `Neutral` — a Territory that's been through a Police Crackdown and recovers typically returns to whichever Organization still holds meaningful influence there, re-entering the cycle around `Claimed`/`Established` rather than resetting fully to `Neutral`. A Territory only returns fully to `Neutral` if no Organization retains enough influence to reclaim it immediately — this is a nuance worth Territories.md itself stating explicitly if it doesn't already (flag as a small addition to that doc, not a new conflict).

### Ownership Correction (per ADR-0005)

`Territories.md` currently states this lifecycle is jointly owned by `dce-ai` and `dce-territories`. Per `ADR-0005`'s single-owner rule, this needs correcting: **Territories owns this state machine exclusively.** The AI Director consumes `territory:ownership:*` events and issues Commands (`ClaimTerritory`, `AttackTerritory`) — it does not co-own the state. This document defers the actual doc correction to `Territories.md` itself but records the resolution here since it's directly relevant to keeping this state machine's ownership consistent with the cyclic model being confirmed.

---

## Investigation State Machine (Canonical — New, No Prior Conflict)

`Investigations.md` never defined an explicit enum (only a generic `status` string), so this is adopted as the first canonical definition, as proposed in the Phase 2 planning discussion, unmodified:

```
Created → Open → Evidence Collection → Suspect Identified → Warrant Issued → Raid → Closed
```

Unlike Organizations/Territories, this one is **intentionally linear/terminal** — a single investigation genuinely does conclude at `Closed`, and reopening a closed case is better modeled as a distinct new Investigation referencing the old one (via the Investigation Graph, per `Evidence.md`) than as a loop back into the same state machine. This asymmetry (cyclic for Organizations/Territories, terminal for Investigations) is deliberate and consistent with how each entity actually behaves in the fiction — an organization can rebuild, a specific case file doesn't "restart."

### Transition Notes

- `Evidence Collection` can loop on itself (more evidence can be attached at any point before `Suspect Identified`) without being a formal back-transition — this is intra-state activity, not a state change, and should be modeled as such (attaching evidence doesn't change `status`, per `Investigations.AttachEvidenceToCase`'s existing API).
- A case can move directly from `Open` to `Closed` (e.g., insufficient evidence, case abandoned) without passing through every intermediate state — this is a valid short-circuit, not an error, and `Investigations.UpdateCaseStatus` should permit it.
- Transition ownership: Investigations owns this exclusively, consistent with `ADR-0005`.

---

## Summary Table

| Domain | Model | Terminal state? | Owner |
|---|---|---|---|
| Organization | Cyclic | No — destruction is an outcome of the cycle failing, not a state | Organizations (within `dce-ai`) |
| Territory | Cyclic | No — full reset to Neutral only if no org can reclaim | Territories |
| Investigation | Linear | Yes — `Closed` is terminal per case; reopening = new case | Investigations |

---

## What This Document Does Not Cover

- The Evidence lifecycle (spawn → decay → gone) — already specified in `Evidence.md`, not repeated here since it isn't a simulation-entity state machine in the same sense (it's a decay timer, not a decision-driven cycle).
- Scenario/Incident staging (Planning → Travel → ... → Resolved) — that's `Escalation.md`'s domain, pending its reconciliation with `Scenarios_engine.md` noted in `ADR-0005`.
