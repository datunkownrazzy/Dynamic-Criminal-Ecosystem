# DCE Dispatch

**Status:** Accepted
**Version:** 1.1
**Owner:** Datunkownrazzy
**Dependencies:** Integration Manager, Event Escalation, Simulation Layers

---

## Purpose

The Dispatch Service (`dce-dispatch`) is the communications hub between the DCE simulation and law enforcement. Its primary role is to ingest incident data (from `dce-events`) and bridge it to external police CAD/MDT systems via the `IntegrationManager`. By using an adapter-based architecture, Dispatch remains agnostic of the specific CAD or MDT tool in use.

---

## Integration: Adapter-Based Reporting

Dispatch does not hardcode support for specific dispatch resources. Instead, it relies on the `IntegrationManager` to detect and load a compatible `DispatchAdapter`.

* **Adaptive Translation:** When an `Escalation` stage promotes to Layer 3, the Dispatch service generates an event. The active `DispatchAdapter` translates this into the format required by the server's specific CAD/MDT (e.g., Sonoran, ERS, or PS-Dispatch).
* **Information Sanitization:** Following the principle of *"Uncertainty is a feature,"* the Dispatch service filters incident data. It forwards only the "witnessed" information (location, suspect description) to the CAD/MDT, preventing the AI from handing perfect coordinates to police players unless the incident is formally "called in" by an NPC or a player witness.
* **Real-time Updates:** As the `EventEscalation` progresses through its lifecycle stages, the Dispatch service pushes status updates (e.g., "Suspect vehicle sighted heading East") to the CAD/MDT via the Adapter, mimicking a live dispatcher's feed.

---

## Call Lifecycle Management

| Incident Stage | CAD/MDT Dispatch Status |
|---|---|
| **Layer 0/1** | `None` (Silent background simulation) |
| **Layer 2 (Witnessed)** | `Suspicious Activity` (Low-priority log, no blip) |
| **Layer 3 (Incident)** | `Active Incident` (High-priority blip/notification sent) |

---

## Read-Model API

Other internal systems query Dispatch to determine if a crime is "official" and to coordinate evidence linking.

```lua
local Dispatch = DCE:GetService("Dispatch")

-- Verify if an incident is officially recorded in the police system
local isReported = Dispatch.IsIncidentReported(incidentId)

-- Retrieve details about the current call for investigation purposes
local callDetails = Dispatch.GetCallDetails(callId)
Emitted Events
dispatch:call:created — { callId, incidentId, reportType, initialVector }

dispatch:call:updated — { callId, updateText, newVector }

dispatch:call:resolved — { callId, disposition }

What This Document Does Not Cover
The physical movement of AI units to the dispatch location → docs/08_AI/AIDirector.md

The forensic evidence capture → docs/11_Evidence/Evidence.md

The management of case files → docs/12_Investigations/Investigations.md