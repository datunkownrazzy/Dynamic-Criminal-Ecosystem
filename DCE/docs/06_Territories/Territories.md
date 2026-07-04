# DCE Territories

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** Organizations, Regions, World Engine, Configuration Philosophy

---

## Purpose

This document defines the Territory Service — the mechanism that maps Organization power to geographic space. A Region (defined in `Regions.md`) is a container; a Territory is the *claim* an Organization asserts over that container. This service manages influence, ownership, and the lifecycle of control, distinct from the environmental simulation owned by the World Engine.

---

## Territory vs. Region

*   **Region:** A static spatial boundary with demographic data.
*   **Territory:** The runtime state of an Organization's influence over a specific Region. 

An Organization can have non-zero influence in a Region without "owning" the Territory. Ownership represents an Organization's primary logistical and tactical footprint in that area.

---

## The Influence Model

Influence is tracked as a persistent float per Organization per Region, updated by successful Scenario outcomes (e.g., a successful "Extortion" or "Turf Infiltration").

| Influence Bracket | State | AI Director Impact |
| :--- | :--- | :--- |
| **0 – 10** | Neutral | No behavioral changes. |
| **11 – 40** | Emerging | Organization may run "show of force" scenarios to increase profile. |
| **41 – 80** | Established | Org prioritizes defense; AI Director unlocks high-value logistics (labs/warehouses). |
| **81+** | Dominant | Reduced heat generation for routine activities; aggressive defense against rivals. |

---

## Territory Lifecycle

While the Region remains static, the Territory state transitions through a lifecycle. This is owned by `dce-territories` logic, reacting to events emitted by the World Engine and requests from the AI Director.
Neutral → Claimed → Established → Prosperous → Contested → Violent → Police Crackdown → Recovered

*   **Contested:** Multiple organizations have influence > 25. AI Director prioritizes conflict-based scenarios.
*   **Violent:** Sustained skirmishes detected. AI Director triggers temporary suppression of all economic scenarios.
*   **Police Crackdown:** High `heat` in Region. All Territory operations are forced into `Dormant` states.

---

## Read-Model API

Other systems query Territory state through the Service. Mutations happen only via events (e.g., `territory:incident:resolved`).

```lua
local Territories = DCE:GetService("Territories")

-- Query influence
local influence = Territories.GetInfluence(orgId, regionId)

-- Ownership check
local ownerId = Territories.GetOwner(regionId) 
Emitted Events
territory:influence:changed — { orgId, regionId, fromVal, toVal }

territory:status:changed — { regionId, fromState, toState }

territory:ownership:transferred — { regionId, fromOrgId, toOrgId }

What This Document Does Not Cover
The statistical simulation of the underlying Region → docs/04_Simulation/Regions.md

The forensic investigation of specific territorial violence → docs/11_Evidence/Evidence.md

The dispatch response logic for skirmishes → docs/10_Dispatch/Dispatch.md