# DCE Organizations

**Status:** Accepted
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** World Engine, Regions, DCE-0001, DCE-0002, Configuration Philosophy, ADR-0001

---

## Purpose

This document defines what an Organization *is* — its identity, data shape, resources, personality, leadership structure, and state machine — as owned by `dce-ai`, specifically its `Organizations` Service (see `architecture/ADR-0001-Organizations-Same-Resource-As-AI-Director.md` for why Organizations and the AI Director share a resource rather than being split into two). It deliberately contains **no decision-making logic**. Nothing in this document decides what an Organization does next; that's the AI Director's job (`AI_Director.md`, next in this set). This document only defines what data exists to be decided over.

This split mirrors the World Engine / AI Director separation already established: World Engine owns environmental truth, Organizations own criminal-entity truth, AI Director reads both and decides.

---

## Organization Identity

Organizations are **data, not code** (per `Configuration_Philosophy.md`), defined in `/schemas/organizations/`:

```json
{
  "id": "families",
  "displayName": "Families",
  "personality": {
    "violence": 40,
    "drugTrade": 70,
    "extortion": 30,
    "smuggling": 20,
    "recruitment": 75,
    "territorial": 85,
    "planning": 50
  },
  "startingResources": {
    "money": 15000,
    "members": 20,
    "vehicles": ["declasse_voodoo", "declasse_premier"]
  }
}
```

Personality values are 0–100 weights used by the AI Director's scoring (documented in `AI_Director.md`) — this document only defines that they exist and what they mean conceptually, not how they're used in scoring math.

Adding a new Organization must never require a code change — only a new data file. This is the same rule as Regions (`Regions.md`) and is what makes the plugin path (`DCE-0003-Plugin-Manifest.md`, `Provides: "Organization"`) actually work.

---

## Runtime State

Maintained by the Organization Service, distinct from the static identity data above:

| Field | Meaning |
|---|---|
| `money` | Current liquid funds; exposed as a compatibility/read model field, but authoritative finance ownership remains with the Economy service |
| `members` | Current member count |
| `vehicles` | Currently owned/available vehicles |
| `safehouses` | List of Region-anchored safehouse locations |
| `territories` | Territories currently controlled (ownership record lives with the future `dce-territories` Territory lifecycle, referenced here for convenience) |
| `heat` | Current attention level (single scalar for v1.0, per `Goals.md`) |
| `influence` | Aggregate control/strength measure |
| `morale` | Internal cohesion (affects likelihood of desertion, splintering — see State Machine) |
| `intelligence` (police-held, not organization-held) | Tracked separately — see `Organization_Memory_and_Intelligence.md` (next doc in this set) |
| `state` | Current position in the Organization State Machine, below |

```lua
local Organizations = DCE:GetService("Organizations")
local org = Organizations.GetState("families")
-- org.money, org.members, org.heat, org.state, ...
```

Per the read-model pattern established in `World_Engine.md`, other systems query this through the Service — they never mutate it directly. Only the Organization Service itself (reacting to its own logic or to Events it subscribes to, such as `scenario:outcome:resolved`) changes organization-owned state. Financial ledger mutations remain the responsibility of the Economy service rather than the Organizations Service.

---

## Leadership Hierarchy

```
Boss
 │
 ├── Underboss
 │
 ├── Lieutenant
 │
 ├── Crew Leader
 │
 ├── Veteran
 │
 ├── Soldier
 │
 └── Prospect / Recruit
```

Each position is held by a specific Agent (per `Glossary.md` — a simulated NPC). Positions are data-referenced (`org.leadership.boss = agentId`), not hardcoded per-organization. Removing a leader (arrest, death) does not have hardcoded consequences in this document — see State Machine below for how that's handled generally, and note that specific succession/splintering *logic* belongs in the AI Director, not here. This document only defines that the hierarchy exists and is queryable.

```lua
Organizations.GetLeadership("families") -> { boss = agentId, underboss = agentId, lieutenants = {...}, ... }
```

---

## Organization State Machine

```
Dormant → Growing → Stable → Aggressive Expansion → Conflict → Under Investigation → Suppressed → Recovering → (back to Growing)
```

| State | Rough meaning |
|---|---|
| Dormant | Minimal activity, likely a new or nearly-destroyed organization |
| Growing | Actively recruiting, expanding territory/resources |
| Stable | Holding steady, defensive posture |
| Aggressive Expansion | Actively contesting rivals for territory |
| Conflict | Actively engaged in violence with a rival or police |
| Under Investigation | Police intelligence on this org is high; org should be behaving cautiously |
| Suppressed | Significantly weakened, laying low |
| Recovering | Rebuilding after suppression |

**This document defines the state enum and exposes it.** The *transition conditions* between states (what causes Stable → Conflict, for example) and *what behaviors each state unlocks or restricts* are AI Director concerns and are documented in `AI_Director.md`, not here — this is the same separation as Regions vs. Territory lifecycle. Keeping the enum here and the transition logic in the AI Director means a plugin could theoretically ship an alternative decision engine against the same state data without this document needing to change.

```lua
Organizations.GetState("families") -- returns full state table, .state field is current enum value
Organizations.SetOrganizationState(orgId, newState) -- called by dce-ai only, by convention; not access-restricted at the code level, but treated as owned by dce-ai per Principle #4
```

---

## Emitted Events

- `organization:resource:changed` — money/members/vehicles changed meaningfully (debounced per the guidance in `DCE-0002`/`World_Engine.md` — not every cent)
- `organization:state:changed` — `{ organizationId, fromState, toState }`
- `organization:leadership:changed` — `{ organizationId, position, previousAgentId, newAgentId }`
- `organization:territory:gained` / `organization:territory:lost`

These exist so Dispatch, Analytics, the World Chronicle (deferred, per `Goals.md`), and plugins can react without needing to poll Organization state directly.

---

## Persistence

All fields under Runtime State must survive a server restart (per `Goals.md` v1.0 requirement #5). Persistence schema itself belongs in a future Persistence spec; this document only establishes which fields are persistence-critical.

---

## What This Document Does Not Cover

- How the AI Director scores and selects activities → `AI_Director.md`
- How Scenarios/Incidents actually play out → `Event_Escalation.md`
- How police intelligence is tracked and decays → `Organization_Memory_and_Intelligence.md`
- Territory *ownership lifecycle* (Neutral → Claimed → ... → Recovered) → future `dce-territories` spec (only referenced here for the `territories` field)

---

## Open Question (flag for an ADR if resolved)

Solved architecture/ADR-0001
