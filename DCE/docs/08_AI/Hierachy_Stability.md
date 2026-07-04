# DCE Hierarchy: Stability & Succession

**Status:** Draft
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** Hierarchy, AI Director, Organizations

---

## Purpose
This system manages the consequences of "decapitation." When high-ranking members (Boss/Underboss) are removed by law enforcement or internal conflict, the organization enters a **Volatility State**.

---

## Succession & Power Struggle Mechanics

When a leadership vacancy occurs, the `StabilityService` executes one of the following protocols based on the Organization's `StabilityScore`:

| Event | Trigger | Consequence |
|---|---|---|
| **Natural Succession** | High Stability | The next rank down (e.g., Underboss) is promoted to fill the vacancy. |
| **Power Struggle** | Medium Stability | Multiple "Crew Leaders" fight for control; Org splits into two factions. |
| **Splintering** | Low Stability | Organization dissolves; remaining units scatter or join other nearby Orgs. |

---

## The Splinter/Faction Model
When a group splinters, the **AI Director** uses the following logic:

1. **Faction Creation:** Two new `OrgIDs` are generated.
2. **Resource Split:** The original `Operating Budget` and `Safehouse` assets are divided between the two new factions.
3. **Territorial Conflict:** The new factions are automatically flagged as `Hostile` to one another, triggering "Turf War" scenarios where they fight for control of the original territory.

---

## Integration: ERS Intelligence
Police players can exploit this chaos. The ERS MDT reports these shifts as "Opportunities for Interdiction":

* **Detection:** The MDT will flag a "Sudden spike in hostile activity between [Faction A] and [Faction B]."
* **Actionable Intel:** Detectives can choose to monitor the struggle, wait for the groups to weaken each other, or intervene to accelerate the splintering.

---

## Unified Rank/Hierarchy API
The `Hierarchy` service now tracks the "Succession Line":

* `Hierarchy:GetSuccessor(orgId, rank)`: Returns the highest-ranking candidate to fill a vacancy.
* `Hierarchy:TriggerSuccession(orgId, rank)`: Forces a promotion or initiates a power struggle.
* `Hierarchy:GetStability(orgId)`: Returns current stability (0–100).

---

## Emitted Events
- `hierarchy:stability:lost` — `{ orgId, severity }`
- `hierarchy:org:splintered` — `{ oldOrgId, newOrgIds[] }`
- `hierarchy:org:succession_planned` — `{ orgId, promotedPedId }`