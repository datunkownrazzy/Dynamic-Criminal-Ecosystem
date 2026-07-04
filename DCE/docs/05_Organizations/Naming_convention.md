# DCE Organization Naming & Origin

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** Organizations, World Engine

---

## Purpose
This document defines the naming convention for AI criminal organizations. Every organization must be identified by a combination of its **Cultural Identity** (e.g., Ballas) and its **Territory of Origin** (e.g., Grove Street, Vespucci).

---

## Naming Protocol
Organizations are registered in the `OrgRegistry` using a standard string format: `[Identity]_[Location]`.

* **Syntax:** `ORG_NAME = {Identity}_{Location}`
* **Examples:**
    * `GROVE_STREET_FAMILIES`
    * `VESPUCCI_CRIPS`
    * `SANDY_SHORES_LOST_MC`
    * `EL_BURRO_VAGOS`

---

## Territory of Origin (Anchor Points)
The "Location" part of the name is mapped directly to the `WorldEngine` coordinates where the organization's **"Primary Safehouse"** is located.

1. **Geographic Anchoring:** When an Org is spawned, it is assigned a `HomeRegion`. 
2. **Inheritance:** If a group splinters (due to a power struggle), the naming convention persists for the factions (e.g., `VESPUCCI_CRIPS_WEST` and `VESPUCCI_CRIPS_EAST`), allowing police to immediately identify who they are dealing with based on where the splinter occurred.

---

## Integration: ERS MDT Display
The ERS MDT and Police scanners will automatically parse these names:

* **Dispatch Calls:** "Units be advised, we have reports of shots fired involving the `VESPUCCI_CRIPS` near the Vespucci boardwalk."
* **Investigation Files:** All evidence found in a safehouse is automatically tagged with the Org's full name.

---

## Read-Model API
```lua
local OrgRegistry = DCE:GetService("OrgRegistry")

-- Retrieve a human-readable name for police reports
local name = OrgRegistry.GetDisplayName(orgId) -- Returns "Vespucci Crips"