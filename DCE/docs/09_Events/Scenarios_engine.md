# DCE Scenario Engine

**Status:** Draft
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** Procurement, Hierarchy, World Engine

---

## The Dynamic Feedback Loop
A scenario is defined as a `Task` assigned by a `Lieutenant` to `Soldiers`. When the task completes, the outcome is fed back into the `OrgRegistry`, creating a ripple effect.

### 1. The Scenario Lifecycle
* **Assignment:** The `Lieutenant` creates a job based on the `Boss`'s procurement goals (e.g., "We need weapons").
* **Execution:** `Soldiers` move to a location, perform the action (e.g., drive a truck, hold a point).
* **Completion (The "Impact"):**
    * **Success:** `WealthIndex` increases; `Procurement` stock updates; `Hierarchy` stability grows.
    * **Failure/Interdiction:** `WealthIndex` decreases (lost assets); `Hierarchy` stability drops; `Heat` index increases.

---

## Scenario Impact Matrix (The Ripple Effect)

When police intervene in a scenario, the `ScenarioEngine` calculates the impact based on the Org’s current state:

| Scenario Type | Success Impact | Interdiction Impact (Police) |
|---|---|---|
| **Procurement Run** | Stock levels +10% | Org loses stock; `Heat` +20%; local Safehouse location revealed. |
| **Territory Defense** | Stability +5% | Org loses territory; `Hierarchy` rank demotion for participating members. |
| **Laundering Op** | `Operating Budget` +15% | Financial evidence generated for MDT; potential account freeze. |
| **Power Struggle** | New assets secured | Org splits; massive `Heat` spike; police witness active violence. |

---

## Dynamic Escalation (The "Heat" System)
The `ScenarioEngine` monitors the **Org Heat Index**.
* **Low Heat:** Org performs low-tier collection tasks (Prospects).
* **Medium Heat:** Org shifts to defensive posture; Lieutenants pull Soldiers from the field to guard the Safehouse.
* **High Heat:** The `Boss` orders a "Lockdown." All scenarios stop, procurement is paused, and the Org focuses entirely on bunker-mentality defense.

---

## Integration: ERS Police Gameplay
Police players are not just "stopping crimes"; they are **interfering with an economic engine.**

* **The "Evidence Trail":** Every scenario generates a small "artifact" (e.g., a dropped phone, a discarded ledger, or a intercepted radio call).
* **The "Bottleneck":** If police consistently target "Drug Drops," the Org's `WealthIndex` will plummet, forcing them to either become more desperate (increasing crime) or eventually splinter/collapse due to lack of funds.

---

## Read-Model API
```lua
local Scenario = DCE:GetService("ScenarioEngine")

-- Trigger a scenario based on Org current procurement needs
Scenario.AssignTask(orgId, "ProcurementRun", { target = "WeaponCrate" })

-- Hook for ERS Framework to report scenario interference
Scenario.OnInterfered(orgId, function(policeUnitId, impactSeverity)
    -- Calculate how much "Heat" and "Budget Loss" this causes the Org
    local damage = impactSeverity * 0.5
    OrgRegistry.UpdateWealth(orgId, -damage)
end)