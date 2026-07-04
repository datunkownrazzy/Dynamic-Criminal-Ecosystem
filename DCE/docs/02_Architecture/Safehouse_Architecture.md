# DCE Safehouse Architecture

**Status:** Accepted
**Version:** 1.5
**Owner:** Datunkownrazzy
**Dependencies:** World Engine, Organizations, Procurement

---

## Purpose
The Safehouse service provides tactical objectives while balancing performance and visual quality. This architecture supports both **Teleported Instances** (performance-optimized) and **Walkable Interiors** (high-fidelity), with granular control via the Admin/Config panel.

---

## Admin-Controlled Rendering
To prevent performance issues, server administrators can toggle the rendering method for "Open/Walkable" interiors globally via `config.lua` or the Admin Panel.

* **Toggle Mode:** 
  * `MODE_PERFORMANCE`: Forces all interiors to use Instanced/Teleported logic.
  * `MODE_IMMERSIVE`: Enables Walkable/Open interior support where available.
* **Logic:** When `MODE_IMMERSIVE` is disabled, the `World_Engine` automatically re-maps physical interiors to their nearest `Instance` equivalent.

---

## The Hybrid Configuration

DCE manages safehouses based on their performance profile:

1. **Instance-Based (Teleported):**
   - **Usage:** Standardized, low-tier assets (e.g., generic vanilla house shells).
   - **Performance Benefit:** Multiple locations share a single interior instance, minimizing streaming and RAM usage.
   - **Tactical Implementation:** Uses "Portal" logic; the system triggers a transition at the entrance coordinate.

2. **Physical (Walkable/Open):**
   - **Usage:** High-tier, unique safehouses (e.g., O’Neil Farmhouse, Sandy Shores Motel).
   - **Performance Benefit:** Requires no teleporting; utilizes the game's native pre-loaded interior assets.
   - **Tactical Implementation:** Real-time tactical breaching; police can observe perimeters and room-to-room movement without transition lag.

---

## Unified Container API
Regardless of rendering method (Physical vs. Instance), all services interact with safehouses via the **Container API**:

* `Safehouse.GetEntrance(id)`: Returns the world `vector3` for police to target.
* `Safehouse.Enter(player, id)`: Handles the logic (teleport vs. physical) based on the current Admin/Config setting.
* `Safehouse.SpawnEvidence(id, propType)`: Spawns assets (crates, files, cash) at specific nodes inside the assigned interior, ensuring consistent evidence discovery.

---

## Tactical Breach & Exit Logic
The `Exit` logic is standardized to maintain consistency for both AI and Players:

* **Exit API:** `Safehouse.GetExit(id)` and `Safehouse.ExecuteExit(player, id)`.
* **Instance Exit:** Performs a reverse-teleport from the internal `vector3` back to the exterior world.
* **Physical Exit:** Unlocks the physical door model, allowing natural movement.
* **MDT Integration:** Police HUD/MDT exposes these coordinates, allowing officers to establish tactical perimeters at either the door (Physical) or the portal (Instance).

---

## Emitted Events
- `safehouse:breached` — `{ orgId, location, renderingType }`
- `safehouse:door_toggled` — `{ orgId, state (locked/unlocked) }`
- `safehouse:prop_added` — `{ orgId, propModel, location }`