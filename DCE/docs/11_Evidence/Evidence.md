# DCE Evidence

**Status:** Accepted
**Version:** 1.1
**Owner:** Datunkownrazzy
**Dependencies:** Integration Manager, World Engine, Event Escalation

---

## Purpose

The Evidence Service (`dce-evidence`) manages the lifecycle of forensic material. It acts as the internal system of record while using the `IntegrationManager` to mirror data to external police CAD/MDT/Forensics systems. It ensures that criminal actions have lasting, "investigatable" consequences regardless of which police tools the server uses.

## The Evidence Model

Evidence is a discrete entity tied to an `incidentId`. The schema is optimized for serialization, allowing the `IntegrationManager` to translate DCE's internal model into any external system's format.

| Type | Definition |
|---|---|
| `Physical` | Casings, blood, prints, DNA. |
| `Digital` | Surveillance footage, phone metadata, hacked logs. |
| `Witness` | Civilian statements or victim reports. |

## Integration: Adapter-Based Forensics

Evidence tracking does not rely on hardcoded CAD/MDT support. Instead:

1. **Discovery:** On startup, `IntegrationManager` detects if a dedicated Forensics/Evidence resource is present (e.g., `ers_evidence`, `ps-mdt` forensics module).
2. **Adapter Mapping:** 
   * **If a compatible resource is found:** The Evidence Service triggers the external system’s exports/events via the detected Adapter.
   * **If no resource is found:** The Evidence Service activates `DCE Native Evidence`, providing a lightweight, built-in system for forensic management.
3. **Synchronization:** Any change in evidence `integrity` or `association` triggers a sync call to the active Adapter, keeping external logs updated in real-time.

## API Surface

```lua
local Evidence = DCE:GetService("Evidence")

-- The Service automatically routes this to the active Adapter
Evidence.CollectEvidence(officerId, evidenceId)

-- Used by Investigations to pull data from whichever system is active
Evidence.GetEvidenceByIncident(incidentId)

Emitted Events
evidence:collected — { evidenceId, officerId, adapterUsed }

evidence:decayed — { evidenceId }

evidence:associated — { evidenceId, agentId }

What This Document Does Not Cover
The internal dispatch calls → docs/10_Dispatch/Dispatch.md

Casework management → docs/12_Investigations/Investigations.md