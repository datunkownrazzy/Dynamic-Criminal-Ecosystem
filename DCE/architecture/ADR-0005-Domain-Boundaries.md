# ADR-0005: Domain Boundaries

**Status:** Accepted
**Date:** 2026-07-04
**Author:** Architecture
**Dependencies:** DataOwnership.md, DCE-0001, DCE-0002, ADR-0002

---

## Problem

`DataOwnership.md` already establishes the core rule ("each domain of state has exactly one authoritative owner") and ADR-0002 already applied it once, concretely, to Evidence. But the repo's own recent growth shows the rule isn't being consistently followed in practice: `Territories.md` claims joint ownership between `dce-ai` and `dce-territories`; `Scenarios_engine.md` has a `ScenarioEngine` component directly calling `OrgRegistry.UpdateWealth(orgId, -damage)`, mutating another domain's state directly; and Organization finances are simultaneously claimed by `Organizations.md`, `Economy.md`, and `DataOwnership.md` itself in three subtly different ways. This ADR exists to state the rule at ADR-level authority — not just documentation-level — with a canonical example, so it stops getting silently violated as new docs get written.

## Decision

**No domain owns another domain's data. Ever. Full stop.**

Cross-domain effects happen exclusively through the publish/consume pattern:

```
Economy
    │
    │ publishes
    ▼
MoneyTransferred
    │
    ├──▶ Organizations consumes it (updates its own money field, in its own state)
    │
    ├──▶ Investigations consumes it (flags a transaction pattern, in its own case data)
    │
    └──▶ Evidence consumes it (creates a financial-record evidence entry, in its own registry)
```

Economy never reaches into `Organizations`' state table to set a new balance. Economy computes that a transfer happened, emits `MoneyTransferred` (per `EventContracts.md`'s envelope, `ADR-0003`'s delivery rules), and **each consuming domain updates its own state in response, using its own logic.** This is not a stylistic preference — it's the only way `DataOwnership.md`'s single-owner rule can be true simultaneously for every domain touched by a single real-world event (a money transfer touches Economy, Organizations, potentially Investigations and Evidence — four domains, four owners, one event).

### The Concrete Rule for Code Review

If a line of code looks like this, it is a violation, no matter how convenient:

```lua
-- VIOLATION — Scenario code reaching directly into another domain's state
OrgRegistry.UpdateWealth(orgId, -damage)
```

It must instead look like this:

```lua
-- CORRECT — publish, let the owning domain react
DCE:Emit("scenario:damage:applied", { organizationId = orgId, amount = damage, source = "scenario_engine" })
-- Economy (or Organizations, whichever is confirmed the authoritative owner per the
-- pending finance-ownership ADR) subscribes to this and applies the change to ITS OWN state.
```

This directly retires the pattern found in `Scenarios_engine.md` and is the reason that document cannot be marked Accepted as currently written — see Related/Open Items below.

### Commands vs. Events, and Why This Matters for Boundaries

This ADR is also where the Command/Event split (see the companion `Command_Catalog_v1.md` and `Event_Catalog_v1.md`) becomes load-bearing: a **Command** (`ClaimTerritory`, `TransferFunds`) is a request sent *to* the owning domain, asking it to change its own state. An **Event** (`TerritoryClaimed`, `MoneyTransferred`) is that owning domain reporting, after the fact, that its state changed. A domain boundary violation is precisely what happens when another module skips the Command and mutates state directly instead of asking the owner to do it — the Command/Event split isn't just naming hygiene, it's the mechanism that makes this ADR enforceable in practice rather than just stated in prose.

### No Exceptions Without an ADR

Consistent with `PROJECT_PRINCIPLES.md`'s Exceptions clause: if a genuine case arises where direct cross-domain access seems necessary (e.g., for a performance reason similar to ADR-0001's reasoning), it must be argued and recorded as its own ADR — not quietly coded around this rule inside a Service or, worse, inside a plugin (which the SDK's Golden Rule in `Plugin_SDK.md` already forbids categorically, with no exception path at all for third parties).

## Consequences

- Every cross-domain effect now requires at least one Event emission and one subscription, where a direct function call would have been fewer lines of code. This overhead is accepted deliberately — it's what makes every domain's state independently verifiable, testable, and safe to persist/reload (`Persistence.md`) without needing to know about every other domain's internals.
- Existing docs that currently violate this (`Territories.md`'s joint ownership claim, `Scenarios_engine.md`'s direct mutation, the three-way finance ownership ambiguity) are now **out of compliance with an ADR**, not just informally inconsistent — this should raise their priority for correction above general cleanup, since ADRs are meant to be the highest-authority record short of the Vision/Principles documents themselves.
- Plugin authors get a clean mental model for free: if a plugin ever finds itself wanting to reach into another domain's state, that desire is itself the signal that a Command should exist and doesn't yet — the fix is to request the Command Catalog be extended, not to work around the boundary.

## Open Items This ADR Surfaces But Does Not Resolve

1. **Finance ownership** — `Organizations.md` vs `Economy.md` vs `DataOwnership.md`'s matrix still disagree on who owns money/wealth. This ADR makes clear that *whoever* it is, it must be exactly one of them, with the others as consumers of a `MoneyTransferred`-style event — but doesn't itself pick which one. Needs a dedicated ADR.
2. **Territory joint ownership** — `Territories.md` must be corrected to name a single owner (almost certainly `dce-territories`, with `dce-ai`/AI Director as a consumer of territory-change events rather than a co-owner) — a follow-up doc correction, not necessarily its own ADR, but should reference this one.
3. **`Scenarios_engine.md` vs `Escalation.md`** — the deeper conflict (two competing scenario execution models) is out of scope for this ADR, but the specific `OrgRegistry.UpdateWealth` violation inside `Scenarios_engine.md` is now formally non-compliant regardless of which model wins.

## Related

- `docs/02_Arcitecture/DataOwnership.md`
- `architecture/ADR-0002-Evidence-Registry-Ownership.md` (the first applied precedent for this rule)
- `architecture/ADR-0003-Event-Bus-Architecture.md`
- `docs/16_Catalogs/Event_Catalog_v1.md`, `docs/16_Catalogs/Command_Catalog_v1.md`
