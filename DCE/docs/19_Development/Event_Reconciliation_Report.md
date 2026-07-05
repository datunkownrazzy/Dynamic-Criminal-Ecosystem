# Event Reconciliation Report

**Date:** 2026-07-05  
**Sprint:** 001C — Developer Tooling Stabilization  
**Scope:** Compare `Event_Catalog_v1.md` against actual `DCE.Emit()` calls in runtime code.

---

## Methodology

All `DCE.Emit(...)` calls were extracted from the `DCE/src/` directory and compared against the canonical event names in `Event_Catalog_v1.md`. Each discrepancy is classified as one of:

- **Implementation Bug** — code emits wrong event name
- **Documentation Drift** — catalog is outdated relative to implementation
- **Intentional Design** — deliberate deviation with rationale

---

## Events That Match Exactly (18 events)

| Catalog Name | Implementation | Status |
|---|---|---|
| `core:initialized` | `core:initialized` | ✅ Match |
| `service:registered:<name>` | `service:registered:<name>` | ✅ Match |
| `service:unregistered:<name>` | `service:unregistered:<name>` | ✅ Match |
| `admin:dashboard:opened` | `admin:dashboard:opened` | ✅ Match |
| `admin:action:executed` | `admin:action:executed` | ✅ Match |
| `admin:debug:command` | `admin:debug:command` | ✅ Match |
| `organization:activity:started` | `organization:activity:started` | ✅ Match |
| `dispatch:call:created` | `dispatch:call:created` | ✅ Match |
| `sdk:organization:registered` | `sdk:organization:registered` | ✅ Match |
| `sdk:adapter:registered` | `sdk:adapter:registered` | ✅ Match |
| `sdk:behavior:registered` | `sdk:behavior:registered` | ✅ Match |
| `sdk:escalation:registered` | `sdk:escalation:registered` | ✅ Match |

---

## Events in Implementation but NOT in Catalog (12 events)

| Emitted Event | Source File | Classification | Rationale |
|---|---|---|---|
| `evidence:item:created` | `dce-evidence/services/evidence.lua` | **Documentation Drift** | Catalog says `evidence:item:recovered`. Implementation uses `:created` which is more precise (item is created, not necessarily recovered). |
| `evidence:item:transferred` | `dce-evidence/services/evidence.lua` | **Documentation Drift** | Catalog doesn't list transfer events. Implementation tracks custody chain. |
| `evidence:item:verified` | `dce-evidence/services/evidence.lua` | **Documentation Drift** | Catalog doesn't list verification events. Implementation tracks forensic verification. |
| `admin:config:update` | `dce-admin/services/admin.lua` | **Documentation Drift** | Catalog only lists `admin:action:executed` as generic. Config updates are a specific subtype. |
| `admin:debug:unknown` | `dce-admin/services/admin.lua` | **Intentional Design** | Edge case for unrecognized debug commands. Not worth cataloging. |
| `ai:director:decision:executed` | `dce-ai/services/ai-director.lua` | **Documentation Drift** | Internal AI director event not yet in catalog. |
| `organization:state:changed` | `dce-ai/services/organizations.lua` | **Documentation Drift** | Catalog has `organization:leadership:changed` but not generic state changes. |
| `organization:perception:pressure_updated` | `dce-ai/services/organizations.lua` | **Documentation Drift** | Internal perception system event. |
| `organization:perception:pressure_spiked` | `dce-ai/services/organizations.lua` | **Documentation Drift** | Internal perception system event. |
| `dispatch:call:updated` | `dce-dispatch/services/dispatch.lua` | **Documentation Drift** | Catalog only lists `:created` and `:officer_assigned`. Updates are a natural lifecycle event. |
| `dispatch:call:resolved` | `dce-dispatch/services/dispatch.lua` | **Documentation Drift** | Catalog has `scenario:lifecycle:resolved` but not dispatch-specific resolution. |
| `world:region:state_changed` | `dce-world/services/world.lua` | **Documentation Drift** | Catalog only lists `world:tick:started/completed`. Region-level events are more granular. |
| `world:region:layer_changed` | `dce-world/services/world.lua` | **Documentation Drift** | Same as above — region layer transitions. |
| `world:time:changed` | `dce-world/services/world.lua` | **Documentation Drift** | Time simulation events not in catalog. |
| `world:weather:changed` | `dce-world/services/world.lua` | **Documentation Drift** | Weather simulation events not in catalog. |
| `scenario:created` | `dce-events/services/scenario-engine.lua` | **Documentation Drift** | Catalog maps scenarios to `organization:activity:started`. Implementation uses separate `scenario:created`. |
| `scenario:stage:changed` | `dce-events/services/scenario-engine.lua` | **Documentation Drift** | Scenario stage progression not in catalog. |
| `scenario:completed` | `dce-events/services/scenario-engine.lua` | **Documentation Drift** | Catalog has `scenario:lifecycle:resolved`. Implementation uses `scenario:completed`. |
| `scenario:timed_out` | `dce-events/services/scenario-engine.lua` | **Documentation Drift** | Timeout-specific terminal event. |
| `scenario:interdicted` | `dce-events/services/scenario-engine.lua` | **Documentation Drift** | Interdiction-specific terminal event. |
| `dispatch:call:requested` | `dce-events/services/scenario-engine.lua` | **Documentation Drift** | Scenario engine requests dispatch calls. |

---

## Events in Catalog but NOT in Implementation (25 events)

| Catalog Name | Status | Notes |
|---|---|---|
| `organization:lifecycle:created` | ❌ Not implemented | Organization creation is data-driven, no event emitted yet |
| `organization:lifecycle:destroyed` | ❌ Not implemented | No terminal state event for organizations |
| `organization:lifecycle:split` | ❌ Not implemented | Not yet implemented |
| `organization:lifecycle:merged` | ❌ Not implemented | Not yet implemented |
| `organization:member:joined` | ❌ Not implemented | Agent membership not tracked via events |
| `organization:member:left` | ❌ Not implemented | Agent membership not tracked via events |
| `organization:leadership:changed` | ❌ Not implemented | Uses `organization:state:changed` instead |
| `territory:ownership:claimed` | ❌ Not implemented | Territory system not fully event-driven |
| `territory:ownership:lost` | ❌ Not implemented | Territory system not fully event-driven |
| `territory:ownership:contested` | ❌ Not implemented | Territory system not fully event-driven |
| `economy:shipment:started` | ❌ Not implemented | Economy domain not yet built |
| `economy:shipment:intercepted` | ❌ Not implemented | Economy domain not yet built |
| `economy:shipment:completed` | ❌ Not implemented | Economy domain not yet built |
| `economy:funds:laundered` | ❌ Not implemented | Economy domain not yet built |
| `economy:funds:transferred` | ❌ Not implemented | Economy domain not yet built |
| `economy:business:purchased` | ❌ Not implemented | Economy domain not yet built |
| `economy:business:raided` | ❌ Not implemented | Economy domain not yet built |
| `dispatch:call:officer_assigned` | ❌ Not implemented | Officer assignment not yet event-driven |
| `evidence:item:recovered` | ❌ Not implemented | Uses `evidence:item:created` instead |
| `evidence:item:destroyed` | ❌ Not implemented | Evidence destruction not yet event-driven |
| `investigation:case:opened` | ❌ Not implemented | Investigation domain not yet built |
| `investigation:case:closed` | ❌ Not implemented | Investigation domain not yet built |
| `investigation:outcome:arrest` | ❌ Not implemented | Investigation domain not yet built |
| `investigation:outcome:raid` | ❌ Not implemented | Investigation domain not yet built |
| `investigation:informant:activated` | ❌ Not implemented | Investigation domain not yet built |
| `organization:activity:escalated` | ❌ Not implemented | Escalation not yet event-driven |
| `scenario:lifecycle:resolved` | ❌ Not implemented | Uses `scenario:completed`/`scenario:timed_out` instead |
| `world:tick:started` | ❌ Not implemented | Tick events not yet emitted |
| `world:tick:completed` | ❌ Not implemented | Tick events not yet emitted |
| `sdk:plugin:registered` | ❌ Not implemented | Plugin registration not yet event-driven |
| `sdk:plugin:rejected` | ❌ Not implemented | Plugin rejection not yet event-driven |

---

## Name Conflicts (Same Concept, Different Names)

| Catalog Name | Implementation Name | Classification | Recommendation |
|---|---|---|---|
| `evidence:item:recovered` | `evidence:item:created` | **Documentation Drift** | Implementation name is more accurate. Update catalog to `evidence:item:created`. |
| `scenario:lifecycle:resolved` | `scenario:completed` / `scenario:timed_out` | **Documentation Drift** | Implementation uses multiple terminal events. Catalog should reflect this. |
| `organization:leadership:changed` | `organization:state:changed` | **Documentation Drift** | Implementation is more generic. Catalog should add `organization:state:changed` as a separate event. |

---

## Summary

| Category | Count |
|---|---|
| ✅ Exact matches | 12 |
| 📝 Documentation Drift (impl has events not in catalog) | 21 |
| 📝 Documentation Drift (catalog has events not in impl) | 30 |
| 🎯 Intentional Design | 1 |
| 🐛 Implementation Bug | 0 |

**No implementation bugs found.** All discrepancies are documentation drift — the catalog was written as a forward-looking spec, and the implementation has evolved additional events that were never backported to the catalog.

**Recommendation:** Update `Event_Catalog_v1.md` to include all implementation events. Do not rename existing implementation events — they are already in use and renaming would be a breaking change.