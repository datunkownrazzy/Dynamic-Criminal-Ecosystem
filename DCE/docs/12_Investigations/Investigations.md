---

# DCE Investigations

**Status:** Accepted
**Version:** 1.1
**Owner:** Datunkownrazzy
**Dependencies:** Evidence, Integration Manager, Organizations

---

## Purpose

The Investigations Service is the casework engine of DCE. It transforms raw evidence (from `dce-evidence`) into structured Case Files. By utilizing the `IntegrationManager`, it functions as a "Case Headless Service"—it provides the logic and state, while the actual visualization and management occur within the server's preferred CAD/MDT system.

## Integration: CAD/MDT Casework Feed

The Investigations Service maintains a 1:1 mirror between its internal `CaseFile` objects and the external police tool:

* **Auto-Mirroring:** When `Investigations.AttachEvidenceToCase()` is called, the service commands the `IntegrationManager` to update the external Case File mirror.
* **Tiered Exposure:** As a case moves up in `intelligenceTier`, the Investigations Service triggers the `MDTAdapter` to "unlock" higher-level data (Org hierarchies, known safehouses) within the CAD/MDT UI.
* **Generic Fallback:** If no dedicated Case Management resource is detected, the Investigation Service logs state changes to the server console/database, ensuring detectives have at least a baseline record of their work.

## Integration Wizard (Admin View)

Administrators can use the Integration Wizard to map their specific CAD's "Add Evidence to Case" or "Create Case File" exports to DCE's internal Investigation events. This allows for deep integration with custom-built CAD/MDT tools without waiting for official DCE patches.

## API Surface

```lua
local Investigations = DCE:GetService("Investigations")

-- Links evidence, auto-syncs with discovered CAD/MDT via Adapter
Investigations.AttachEvidenceToCase(caseId, evidenceId)

-- Updates case status in DCE and the mirrored CAD/MDT
Investigations.UpdateCaseStatus(caseId, status)
Emitted Events
investigation:case:created — { caseId, orgId, cadSyncId }

investigation:tier:promoted — { caseId, newTier }

investigation:case:closed — { caseId, outcome }

What This Document Does Not Cover
The forensic tracking logic → docs/11_Evidence/Evidence.md

The initial dispatch reporting → docs/10_Dispatch/Dispatch.md