# DCE Integration Manager

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** DCE Philosophy, Configuration Philosophy

---

## Purpose

The `IntegrationManager` is the brain for DCE's external connectivity. It removes the need for hardcoded dependencies, allowing DCE to auto-discover compatible server resources (CADs, MDTs, Dispatch, Evidence) and bridge them through modular **Adapters**. It follows the principle that DCE should be "installation-agnostic."

## Discovery & Loading Logic

On server startup, the Manager performs a three-stage bootstrap:

1. **Scan:** Queries `GetNumResources()` to identify installed systems.
2. **Prioritize:** Loads the highest-priority adapter for each category (Dispatch, MDT, Evidence). If a system is not found, it initializes the internal "Native Fallback" (e.g., DCE Native Evidence).
3. **Verify:** Tests exported functions of detected resources to ensure they are active.

```lua
-- Conceptual Discovery Logic
for i = 0, GetNumResources() - 1 do
    local resourceName = GetResourceByFindIndex(i)
    if IntegrationManager.Registry[resourceName] then
        IntegrationManager.LoadAdapter(resourceName)
    end
end

Adapter Architecture
Every integration, whether it is an ers_dispatch.lua or a sonoran_cad.lua, must expose a standardized API. The core DCE systems (Events, Investigations) never interact with the CAD directly; they talk only to the Adapter.

Dispatch Adapter: CreateCall(data), UpdateCall(id, data), CloseCall(id).

Evidence Adapter: RegisterCasing(), RegisterDNA(), RegisterFingerprint().

MDT Adapter: PushIntelTier(orgId, tier), SyncCaseFile(caseData).

Universal Integration Wizard
For systems not natively supported, DCE provides a GUI-based wizard. This allows server owners to map foreign resource exports/events to the DCE Adapter API without writing a single line of Lua.

Mapping: The Wizard captures ExportName, EventName, or EndpointURL.

Persistence: The mapping is saved as user/custom_adapters.json and loaded as a high-priority profile on subsequent restarts.

Integration Health Panel
A server-side UI dashboard provides real-time status of all connections:

Active Adapters: Green status for detected/verified systems.

Fallback Systems: Yellow status for native DCE systems running in the absence of external resources.

Diagnostic Alerts: Red status for misconfigured or failing external integrations.

Emitted Events
integration:adapter:loaded — { category, resourceName, priority }

integration:adapter:failed — { category, reason }

integration:wizard:ready — { systemDetected } (Triggers admin setup UI).

What This Document Does Not Cover
The internal simulation tick rates → docs/04_Simulation/World_Engine.md

The definition of specific data payloads (e.g., how a 'Drug Sale' event is structured) → docs/09_Events/Escalation.md