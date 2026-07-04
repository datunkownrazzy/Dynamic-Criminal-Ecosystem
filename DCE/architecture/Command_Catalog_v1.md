# DCE Command Catalog (v1)

**Status:** Accepted — Frozen for v1.0
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** ADR-0005 (Domain Boundaries), ADR-0006 (Plugin Architecture), Event_Catalog_v1.md

---

## Purpose

Per `ADR-0005`, a **Command** is a request sent *to* the domain that owns a piece of state, asking it to change that state. A Command is intent; the corresponding **Event** (see `Event_Catalog_v1.md`) is the domain reporting, after the fact, that the change actually happened. Keeping these catalogs separate is what makes the "no domain owns another's data" rule enforceable rather than aspirational — a Command is the *only* legitimate way to ask another domain to change, and it always routes through that domain's own Service, never bypasses it.

**Freezing rules:** same as `Event_Catalog_v1.md` — additions are routine, renames/removals are breaking changes per `ADR-0003`.

---

## Command Shape

Every Command is issued through the owning domain's Service (internal callers) or through the SDK's `IssueCommand` proxy (plugins, per `ADR-0006`):

```lua
-- Internal module (has direct Service access per DCE-0001)
local Territories = DCE:GetService("Territories")
Territories.HandleCommand("ClaimTerritory", { organizationId = "families", territoryId = "davis" })

-- Plugin (capability-scoped, per ADR-0006)
exports.dce:IssueCommand("ClaimTerritory", { organizationId = "my_plugin_org", territoryId = "davis" })
```

A Command can be **accepted** (state changes, corresponding Event fires) or **rejected** (validation failure, insufficient resources, invalid state transition per `State_Machines.md`). Rejection is not an error/exception in the Lua sense — it's a normal return value (`success = false, reason = "..."`) that the caller is expected to handle, consistent with the Service error-handling guidance in `Coding_Standards.md`.

---

## Command Catalog

| Command | Owning domain | Triggers on success |
|---|---|---|
| `ClaimTerritory` | Territories | `territory:ownership:claimed` |
| `AttackTerritory` | Territories (validates) → Organizations/AI Director (executes the conflict) | `territory:ownership:contested`, potentially `territory:ownership:lost` for the loser |
| `RecruitMember` | Organizations | `organization:member:joined` |
| `PurchaseWeapons` | Economy (validates/deducts funds) → Procurement (fulfills) | `economy:funds:transferred`, plus a Procurement-domain event (not yet cataloged — flag for catalog addition once `Procurement.md`'s events are finalized) |
| `CreateScenario` | AI Director (per `Escalation.md`, pending resolution with `Scenarios_engine.md`) | `organization:activity:started` |
| `OpenInvestigation` | Investigations | `investigation:case:opened` |
| `CollectEvidence` | Evidence | `evidence:item:recovered` |
| `IssueDispatchCall` | Dispatch | `dispatch:call:created` |
| `SpawnOrganization` | Organizations | `organization:lifecycle:created` |
| `TransferFunds` | Economy | `economy:funds:transferred` |
| `StartDrugShipment` | Economy | `economy:shipment:started` |

---

## Validation Responsibility

Per `ADR-0005`, the **owning domain**, and only the owning domain, validates a Command against its own state and its own state machine (`State_Machines.md`). A Command that would move an Organization or Territory into an invalid state transition (e.g., `ClaimTerritory` on a Territory already at `Fortified`/whatever the resolved lifecycle calls a heavily-defended state) is rejected by Territories itself — the caller (another module, or a plugin) never pre-validates on the owning domain's behalf, since that would require reaching into state it doesn't own, which is exactly what `ADR-0005` prohibits.

## Commands Are Not Events With a Different Name

A Command and its resulting Event are not the same object renamed — a Command can fail; an Event, by definition, only ever describes something that already happened. Code should never "emit a Command" or "subscribe to a Command" — Commands are called (request/response, per `DCE-0002`'s guidance on when to use direct Service calls vs. the Event Bus), Events are emitted/subscribed (fire-and-forget notification). Conflating the two defeats the purpose of having both.

## Plugin Access to Commands

Per `ADR-0006`, a plugin may only issue Commands its declared Capabilities entitle it to. The mapping between `DCE-0003` Capability tags and permitted Commands (e.g., does `Provides: "Organization"` grant `RecruitMember` and `SpawnOrganization` but not `TransferFunds`?) needs to be made explicit in `Plugin_SDK.md` as a follow-up — flagged here since this catalog is the first place the full Command list exists in one place to check against.

## What's Deliberately Not Yet Cataloged

Commands for World Chronicle, cross-server actions, and anything tied to the deferred systems in `Goals.md` are out of scope for this freeze, same reasoning as `Event_Catalog_v1.md`.
