# DCE Organizational Hierarchy

**Status:** Accepted  
**Version:** 2.0  
**Owner:** Datunkownrazzy  
**Dependencies:** AI Director, Organizations, Procurement

## 1. Overview & Rank Structure
The Hierarchy service defines the command structure of AI Organizations. It maps AI units to specific roles, ensuring that criminal activities are assigned based on a unit's rank, authority, and tactical capability.

| Rank | Responsibility | Operational Logic |
| :--- | :--- | :--- |
| **Boss** | Global Strategy / Budgeting | Remains at Safehouse; controls `Procurement` & `Operating Budget`. |
| **Underboss** | Operational Oversight | Manages multi-region coordination; assigns tasks to Lieutenants. |
| **Lieutenant** | Scenario Dispatch | Coordinates specific high-tier tasks (e.g., Heists, Large Drug Runs). |
| **Crew Leader** | Unit Tactics | Leads a small team (2-3 Soldiers) during live scenarios. |
| **Veteran** | Specialized Defense | Guards high-value shipments; provides support in firefights. |
| **Soldier** | Field Execution | Executes standard patrol and low-tier collection tasks. |
| **Prospect** | Low-Risk Grunt | Performs surveillance; provides lookouts for senior members. |

## 2. AI Dispatch & Resource Logic
The `AIDirector` leverages the hierarchy to optimize organizational flow and resource distribution:

* **Strategic Delegation:** The **Boss** and **Underboss** define long-term goals (e.g., "Expand territory"), while **Lieutenants** decompose these into actionable, site-specific jobs.
* **Resource Allocation:** Higher-tier ranks (**Veteran+**) are authorized to utilize specialized equipment purchased via the `Procurement` service, while **Prospects** are strictly restricted to basic gear.
* **Stability Dependency:** Organizational functionality is tied to the hierarchy. Removing high-ranking members (Boss, Underboss) has a significantly larger impact on AI operations than removing entry-level units.

## 3. ERS Investigations & Intelligence
The hierarchy serves as a primary driver for law enforcement intelligence gathering through the ERS MDT:

* **Organizational Decapitation:** If a **Boss** is killed or arrested, the organization enters a "Disarray" state. Procurement halts, and activity drops significantly until a successor is promoted.
* **Evidence Tiers:** When searching an AI unit, the intelligence returned correlates to their rank:
    * **Prospect/Soldier:** Identifies the Organization; provides no operational secrets.
    * **Lieutenant/Crew Leader:** Provides location markers for ongoing tasks or nearby caches.
    * **Underboss/Boss:** Reveals `WealthIndex`, safehouse locations, and upcoming `Procurement` shipments (e.g., "Master Ledger").

## 4. API & Implementation

### Read-Model API
```lua
local Hierarchy = DCE:GetService("Hierarchy")

-- Check the rank of an AI unit
local rank = Hierarchy.GetUnitRank(pedId)

-- Retrieve the organization's current active leader
local bossId = Hierarchy.GetBoss(orgId)

-- Verify rank authority for dispatching
if Hierarchy.GetUnitRank(pedId) == "Lieutenant" then
    -- Allow unit to dispatch scenarios to subordinates
end

-- Handle unit death/arrest
Hierarchy.OnUnitRemoved(pedId, function(orgId, rank)
    if rank == "Boss" then
        AI.TriggerEvent("org:disarray", orgId)
    end
end)


Emitted Events
hierarchy:rank:updated — { pedId, newRank }

hierarchy:unit:promoted — { orgId, pedId, newRank }

hierarchy:org:decapitated — { orgId, reason }

hierarchy:org:stability_check — { orgId, remainingHighRanks }