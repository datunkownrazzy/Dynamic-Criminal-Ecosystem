# DCE Scenario Engine

**Status:** Draft
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** Organizations, AI Director, Economy, Hierarchy, World Engine

---

## The Dynamic Feedback Loop
A scenario is defined as a lifecycle stage that the AI Director selects and the Scenario subsystem executes. This document should be read as a companion to Escalation.md: the Escalation lifecycle defines the stage progression (Planning → Travel → Preparation → Execution → Reaction → Escape → Investigation → Long-term Consequences), while this document describes how a scenario's outcome is translated into state changes and service requests.

### 1. The Scenario Lifecycle
* **Assignment:** The AI Director selects a scenario type and its initial parameters based on Organization state, current heat, and available budget.
* **Execution:** the scenario runs through the relevant Escalation stages and updates its own state as it progresses.
* **Completion (The "Impact"):**
    * **Success:** the Economy service adjusts budget/wealth-related state through its own Service interface; Procurement stock updates through Procurement; Hierarchy stability grows.
    * **Failure/Interdiction:** the Economy service records the loss through its owned financial state; Hierarchy stability drops; Heat increases through the organization-owned state path.

---

## Scenario Impact Matrix (The Ripple Effect)

When police intervene in a scenario, the `ScenarioEngine` calculates the impact based on the Org’s current state:

| Scenario Type | Success Impact | Interdiction Impact (Police) |
|---|---|---|
| **Procurement Run** | Stock levels +10% | Org loses stock; `Heat` +20%; local Safehouse location revealed. |
| **Territory Defense** | Stability +5% | Org loses territory; `Hierarchy` rank demotion for participating members. |
| **Laundering Op** | Budget/ledger update via Economy | Financial evidence generated for MDT; potential account freeze. |
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
local Economy = DCE:GetService("Economy")

-- Trigger a scenario based on the Organization's current procurement needs
Scenario.AssignTask(orgId, "ProcurementRun", { target = "WeaponCrate" })

-- Hook for ERS Framework to report scenario interference
Scenario.OnInterfered(orgId, function(policeUnitId, impactSeverity)
    -- Calculate how much Heat and budget impact this causes the Organization.
    -- The economy service owns the authoritative financial state mutation.
    local damage = impactSeverity * 0.5
    Economy.ApplyLoss(orgId, damage)
end)