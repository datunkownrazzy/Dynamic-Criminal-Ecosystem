# DCE Evidence Naming Protocol

**Status:** Draft
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** Hierarchy, Scenario Engine, ERS Framework

---

## 1. Dynamic Item Naming (The "Data Container")
Since the ERS framework only displays item names, we will generate names that embed the "code" or "address" directly into the item. 

* **Naming Syntax:** `[Item Type] - [Data Payload]`
* **Examples:**
    * `Shipping Manifest - Sector 4, Warehouse B`
    * `Burner Phone - Contact: "The Lieutenant"`
    * `Operational Plan - 1045 Boulevard Del Perro`
    * `Master Ledger - Org: GROVE_STREET_FAMILIES`

## 2. Evidence-to-Hierarchy Linkage
Each item name provides the "next step" in the investigation trail, allowing detectives to bridge the gap between ranks.

| Found on Rank | Evidence Name | Leads To... |
| :--- | :--- | :--- |
| **Prospect** | `Burner Phone - Dialed: 555-0102` | Tracks to a **Soldier**. |
| **Soldier** | `Shipping Manifest - Warehouse A` | Tracks to a **Crew Leader**. |
| **Crew Leader** | `Operational Plan - 4420 Davis Ave` | Tracks to a **Lieutenant**. |
| **Lieutenant** | `Task List - Safehouse Delta` | Tracks to the **Boss**. |

## 3. Implementation Logic (Procedural Generation)
When a scenario completes, the system generates the item name dynamically:

```lua
-- Generate an item name that ERS will display in the search menu
local function GenerateEvidenceName(rank, task)
    local address = MapConfig.GetAddress(task.location)
    
    if rank == "Soldier" then
        return "Shipping Manifest - " .. address
    elseif rank == "Lieutenant" then
        return "Operational Plan - " .. address
    end
end

-- Spawn the item into the AI's inventory
local itemName = GenerateEvidenceName(rank, task)
Inventory.AddItem(pedId, itemName, 1)

4. ERS Detective Workflow
Patrol/Narcotics: Officers stop a Soldier and search them. They see Shipping Manifest - Warehouse A.

Investigation/Detectives: Narcotics Division logs the Warehouse A location.

Surveillance: Detectives stake out Warehouse A to catch the Crew Leader or Lieutenant making a drop.

Resolution: The evidence trail forces interaction between the divisions, turning a simple stop into an organizational takedown.