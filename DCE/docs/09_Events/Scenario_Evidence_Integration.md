# DCE Scenario & Evidence Integration

**Status:** Draft
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** Hierarchy, Scenario Engine, Procurement

---

## 1. The Evidence-to-Hierarchy Chain
Evidence is no longer random; it is generated based on the rank of the AI performing the task and the type of scenario.

| Scenario Task | Rank Responsible | Evidence Artifacts Generated |
| :--- | :--- | :--- |
| **Lookout / Surveillance** | Prospect | Burner phone, scribbled notes, transit pass. |
| **Collection / Courier** | Soldier | Receipt of transaction, shipping manifest, burner phone. |
| **Defensive Hold** | Veteran / Crew Leader | Weapon cache, specialized ammo, "Duty" roster. |
| **High-Tier Ops** | Lieutenant | Operational plan, task list, payroll slip. |
| **Budget/Procurement** | Boss / Underboss | Master ledger, banking records, encrypted hard drive. |

---

## 2. Dynamic Evidence Generation Logic
When the `ScenarioEngine` completes an action, it triggers the `EvidenceService` to place specific objects based on the Org’s hierarchy:

* **Scenario Failure:** If police stop a Courier (Soldier), the evidence found (Manifest) points to the *Crew Leader* who assigned the job. 
* **The "Trail of Breadcrumbs":** 
    1. Police arrest a **Soldier** with a *Shipping Manifest*. 
    2. The manifest contains a code/address. 
    3. Police raid that location to find a **Crew Leader** with an *Operational Plan*. 
    4. The plan leads to the **Boss's Safehouse**.
    5. The Boss's Safehouse contains the *Master Ledger*.

---

## 3. Integration with ERS Gameplay
To make this feel "real" for investigators, the MDT utilizes the **Hierarchy Authority**:

* **Authority Chain:** Evidence items are tagged with a `ChainOfCustodyID`. If an officer finds a "Task List," the MDT will automatically link it to the `Lieutenant` who generated it.
* **MDT Intelligence Score:** The more evidence police collect, the higher their "Investigation Progress" score. High scores unlock "Warrant Authorization" for the Boss's Safehouse.

---

## 4. Implementation API
```lua
local Evidence = DCE:GetService("EvidenceService")

-- Generate evidence based on scenario and hierarchy rank
Scenario.OnSuccess(orgId, taskType, assignedPedId)
    local rank = Hierarchy.GetUnitRank(assignedPedId)
    local artifact = Evidence.Generate(rank, taskType)
    
    -- Evidence is spawned at the scenario location
    Evidence.Spawn(artifact, vector3(x, y, z))
end)

5. Emitted Events
evidence:artifact_found — { orgId, artifactType, linkedToRank }

evidence:investigation_progress — { orgId, currentTier, unlocks[] }