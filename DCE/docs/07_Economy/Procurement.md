# DCE Procurement & Supply Chain (AI)

**Status:** Draft
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** Economy Service, AI Director, Escalation

---

## Purpose

The Procurement Service (`dce-procurement`) manages the conversion of an AI Organization's "Operating Budget" into physical assets and logistical capabilities. This ensures that an Org’s wealth is actively reinvested into its operations, preventing "money stacking" and creating visible footprints for law enforcement to investigate.

---

## The Procurement Lifecycle

Instead of static AI stats, procurement functions as a recurring "order" process:

1. **Demand Generation:** The `AIDirector` identifies a deficit (e.g., "Need more firepower for territorial defense").
2. **Budget Allocation:** `Economy` service verifies funds and allocates them to a `ProcurementOrder`.
3. **Logistics Delay:** The assets are not available instantly. They must be "shipped" to a Safehouse (a visible movement event).
4. **Integration/Consumption:** The AI Org gains the new capabilities, and the funds are consumed.

---

## Procurement Categories & ERS Intelligence

Every purchase generates an **Economic Footprint** that flows into the ERS MDT as an Intelligence Log:

| Category | Investment | Visible Impact | ERS Intelligence Alert |
|---|---|---|---|
| **Armament** | Heavy Weaponry | AI units spawn with superior tier gear. | "Large arms shipment detected at [Location]." |
| **Logistics** | New Vehicles | AI patrols use faster/armored vehicles. | "Ballas seen modifying vehicles at [Location]." |
| **Defense** | Security Details | Increased AI guard density at Safehouses. | "Increased surveillance observed at [Location]." |
| **Supply** | Drug Stocks | Unlocks higher-tier sale scenarios. | "Supply chain spike detected near [Location]." |

---

## Integration: Supply Chain Interdiction

Because procurement involves physical "shipping" of goods, law enforcement players can intervene in the AI's economic cycle:

* **Interdiction Events:** When an AI Org orders "Armament," the system creates an `Incident` (Layer 3) representing the transport of those goods.
* **Economic Starvation:** If players intercept and destroy the shipment, the `Economy` service deducts the funds, and the Org loses the "Investment," forcing the AI to revert to lower-tier gear and lower-tier scenarios for a cooldown period.

---

## Read-Model API

```lua
local Procurement = DCE:GetService("Procurement")

-- Check what an organization is currently purchasing
local activeOrder = Procurement.GetOrderDetails(orgId)

-- Trigger a manual procurement (AI use only)
Procurement.QueuePurchase(orgId, "Armament", priority)

Emitted Events
procurement:order:started — { orgId, category, eta }

procurement:shipment:spawned — { orgId, category, location } (Triggers ERS callout)

procurement:order:fulfilled — { orgId, category }

What This Document Does Not Cover
The physical spawning of weapon/vehicle props (Handled by WorldEngine)

The definition of AI threat tiers → docs/08_AI/AIDirector.md