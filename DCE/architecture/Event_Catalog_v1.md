# DCE Event Catalog (v1)

**Status:** Accepted — Frozen for v1.0
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** DCE-0002, EventContracts.md, ADR-0003, ADR-0005

---

## Purpose

This is the canonical, frozen list of domain events for v1.0. Per the request to "freeze the first canonical event catalog," every event here follows `EventContracts.md`'s envelope and `DCE-0002`'s `domain:subject:verb` naming convention. Domain-specific specs (`Organizations.md`, `Territories.md`, etc.) should reference this catalog rather than each independently inventing event names — this catalog is the reconciliation point.

**Freezing rules:** Adding a new event to this list is a normal documentation update. Renaming or removing an existing event is a breaking change per `ADR-0003`'s versioning rules and needs an explicit note in `CHANGELOG.MD` (currently empty — see prior review) at minimum, an ADR if the change is significant.

---

## Naming Note

The list below uses the canonical `domain:subject:verb` format used in code. Events follow the envelope format: `{ eventName, eventVersion, timestamp, source, correlationId?, payload }`.

## Core Domain

| Event Name | Emitted When | Payload |
|---|---|---|
| `core:initialized` | DCE Core has completed initialization | `{ version }` |
| `service:registered:<name>` | A service has been registered with the Service Registry | `{ serviceName }` |
| `service:unregistered:<name>` | A service has been unregistered (resource stop) | `{ serviceName }` |

## Admin Domain

| Event Name | Emitted When | Payload |
|---|---|---|
| `admin:dashboard:opened` | Admin opens the DCE admin dashboard | `{ adminId }` |
| `admin:action:executed` | An admin action is executed (audit trail) | `{ adminId, action, target, metadata }` |
| `admin:debug:command` | A debug command is received from admin | `{ adminId, command, args }` |
| `admin:config:update` | Configuration value is updated via admin panel | `{ adminId, resource, key, value }` |
| `admin:debug:mode:changed` | Debug mode is changed (production/development/profiler/etc.) | `{ mode, previousMode }` |
| `admin:performance:alert` | Performance alert is generated for admin dashboard | `{ serviceId, actualMs, budgetMs }` |

## Organization Domain

| Event Name | Emitted When | Payload |
|---|---|---|
| `organization:activity:started` | An organization begins an activity/scenario | `{ organizationId, activity, location, layer }` |
| `organization:activity:escalated` | An organization activity escalates to higher layer | `{ organizationId, activity, escalationReason }` |
| `organization:state:changed` | Organization state transitions (any state change) | `{ organizationId, newState, previousState }` |
| `organization:leadership:changed` | Leadership structure changes | `{ organizationId, newLeader, oldLeader }` |
| `organization:lifecycle:created` | A new Organization is spawned (data-loaded or plugin-registered) | `{ orgId, displayName, archetype }` |
| `organization:lifecycle:destroyed` | An Organization is fully eliminated (terminal state) | `{ orgId, destructionReason }` |

## Territory Domain

| Event Name | Emitted When | Payload |
|---|---|---|
| `territory:ownership:claimed` | A Territory gains its first/new owning Organization | `{ territoryId, organizationId, claimMethod }` |
| `territory:ownership:lost` | A controlling Organization loses a Territory | `{ territoryId, organizationId, lossReason }` |
| `territory:ownership:contested` | Two or more Organizations have competing influence | `{ territoryId, contestingOrganizations }` |

## Economy Domain

| Event Name | Emitted When | Payload |
|---|---|---|
| `economy:shipment:started` | A supply-chain shipment begins | `{ shipmentId, organizationId, goods, destination }` |
| `economy:shipment:intercepted` | Law enforcement or a rival disrupts a shipment | `{ shipmentId, interceptedBy, location }` |
| `economy:shipment:completed` | A shipment successfully arrives (with shipmentType field) | `{ shipmentId, organizationId, goods }` |
| `economy:funds:laundered` | Illicit funds convert to clean funds | `{ organizationId, amount, cleanAmount }` |
| `economy:funds:transferred` | Any funds movement between Economy and another domain | `{ from, to, amount, reason }` |
| `economy:business:purchased` | An Organization acquires a front/legitimate business | `{ organizationId, businessId, price }` |
| `economy:business:raided` | Law enforcement raids a business | `{ businessId, organizationId, raidResult }` |

## Dispatch Domain

| Event Name | Emitted When | Payload |
|---|---|---|
| `dispatch:call:created` | A dispatch call is created | `{ callId, incidentId, description, priority, regionId }` |
| `dispatch:call:updated` | Dispatch call information is updated | `{ callId, updateText, updatedBy }` |
| `dispatch:call:resolved` | Dispatch call is resolved/closed | `{ callId, disposition, resolvedBy }` |
| `dispatch:call:requested` | Scenario engine requests a dispatch call | `{ scenarioId, description, priority, regionId, organizationId }` |
| `dispatch:call:officer_assigned` | A unit is assigned to a call via the active adapter | `{ callId, officerId, unitName }` |

## Evidence Domain

| Event Name | Emitted When | Payload |
|---|---|---|
| `evidence:item:created` | Evidence record is created in registry | `{ evidenceId, type, description, source, organizationId?, scenarioId? }` |
| `evidence:item:transferred` | Chain of custody transfer occurs | `{ evidenceId, from, to, reason, timestamp }` |
| `evidence:item:verified` | Evidence is verified forensically | `{ evidenceId, verifiedBy, confidence }` |
| `evidence:item:destroyed` | Evidence is deliberately destroyed or naturally decays | `{ evidenceId, destructionReason, destroyedAt }` |
| `evidence:item:recovered` | Evidence is physically recovered (game world) | `{ evidenceId, recoveredBy, location }` |

## Scenario / Escalation Domain

| Event Name | Emitted When | Payload |
|---|---|---|
| `scenario:created` | A new scenario is created | `{ scenarioId, organizationId, archetype, startTime }` |
| `scenario:stage:changed` | Scenario progresses through stages | `{ scenarioId, oldStage, newStage }` |
| `scenario:completed` | A Scenario reaches success outcome | `{ scenarioId, outcome, duration }` |
| `scenario:timed_out` | A Scenario times out without completion | `{ scenarioId, timeoutReason }` |
| `scenario:interdicted` | A Scenario is interdicted/stopped | `{ scenarioId, interdictedBy, interdictionType }` |

## Investigation Domain

| Event Name | Emitted When | Payload |
|---|---|---|
| `investigation:case:opened` | A new case file is created | `{ caseId, leadEvidence, priority }` |
| `investigation:case:closed` | A case reaches a terminal status | `{ caseId, closingReason, outcome }` |
| `investigation:outcome:arrest` | An arrest results from a case or live Incident | `{ caseId, arrestMadeBy, suspectInfo }` |
| `investigation:outcome:raid` | A raid is carried out against a location tied to a case | `{ caseId, raidLocation, raidOutcome }` |
| `investigation:informant:activated` | An informant begins providing intelligence | `{ informantId, organizationId, tier }` |

## World / Simulation Domain

| Event Name | Emitted When | Payload |
|---|---|---|
| `world:region:state_changed` | Region state changes | `{ regionId, newState, previousState }` |
| `world:region:layer_changed` | Region simulation layer changes | `{ regionId, oldLayer, newLayer }` |
| `world:time:changed` | Game world time changes | `{ hour, minute, day, weather }` |
| `world:weather:changed` | Weather changes | `{ oldWeather, newWeather, transitionTime }` |
| `world:tick:started` | The Simulation Scheduler begins a new server tick | `{ tickNumber, tier }` |
| `world:tick:completed` | All priority tiers finish for that tick | `{ tickNumber, totalDurationMs }` |

## Location Domain

| Event Name | Emitted When | Payload |
|---|---|---|
| `location:registered` | A location is registered with the Location Manager | `{ locationId, provider, type }` |
| `location:resolved` | A location is resolved for use | `{ locationId, resolvedCoords, routingBucket? }` |
| `location:provider:registered` | A location provider is registered | `{ providerName, services }` |
| `location:organization:locations` | Locations are requested for an organization | `{ orgId, locations[] }` |

## AI Director Domain

| Event Name | Emitted When | Payload |
|---|---|---|
| `ai:decision:executed` | AI Director makes a decision for an organization | `{ organizationId, decision, score, factors }` |
| `ai:director:decision:executed` | AI Director completes a decision cycle | `{ organizationId, selectedAction, score }` |

## Perception/Pressure Domain (Internal)

| Event Name | Emitted When | Payload |
|---|---|---|
| `organization:perception:pressure_updated` | Organization pressure/perception updates | `{ organizationId, pressureScore, factors }` |
| `organization:perception:pressure_spiked` | Organization pressure spikes significantly | `{ organizationId, oldPressure, newPressure, spikeReason }` |

## SDK Domain

| Event Name | Emitted When | Payload |
|---|---|---|
| `sdk:plugin:registered` | A plugin has been successfully registered | `{ pluginId, provides, name, version }` |
| `sdk:plugin:rejected` | A plugin registration was rejected (validation failed) | `{ pluginId, reason }` |
| `sdk:organization:registered` | A plugin registers a new organization | `{ orgId, sourcePluginId, pluginName }` |
| `sdk:adapter:registered` | A plugin registers a dispatch/evidence/MDT adapter | `{ category, adapterName, sourcePluginId }` |
| `sdk:behavior:registered` | A plugin registers new behavior/scenario content | `{ behaviorType, sourcePluginId }` |
| `sdk:escalation:registered` | A plugin registers a new escalation chain | `{ chainId, sourcePluginId }` |

## EventBus Internal Events

| Event Name | Emitted When | Payload |
|---|---|---|
| `eventbus:handler:error` | An event handler throws an error | `{ eventName, handlerId, error, stackTrace? }` |

## Performance Domain (ADR-0015)

| Event Name | Emitted When | Payload |
|---|---|---|
| `performance:budget:exceeded` | A service exceeds its allocated CPU budget | `{ serviceId, actualMs, budgetMs }` |

---

## What's Deliberately Not Yet Cataloged

Per `Goals.md`'s deferred list, events for World Chronicle, cross-server sync, and federal/political-pressure systems are not part of this v1.0 freeze — they'll get their own catalog addition when those systems are actually built, not reserved in advance.

## Relationship to Commands

Every "past-tense" event in this catalog corresponds to a "present-tense" Command in `Command_Catalog_v1.md` that, when successfully processed by its owning domain, results in that event being emitted. See that document for the Command side of the pair.

## Implementation Notes

Some events have multiple related events (e.g., `scenario:completed`, `scenario:timed_out`, `scenario:interdicted` all represent terminal states). The EventBus implementation in `dce-core/core/eventbus.lua` supports:

- Standard `Emit`, `On`, `Once`, `Off` operations
- Priority-based handlers (`OnPriority`)
- Batching (`EmitBatch`)
- Debouncing (`EmitDebounced`)
- Coalescing (`EmitCoalesced`)
- Delayed execution (`EmitDelayed`)
- Metrics collection (`GetMetrics`, `GetStats`)
- Handler isolation via pcall

---

## Changelog

| Date | Change | Reason |
|------|--------|--------|
| 2026-07-07 | Added 21 implementation events not in original catalog | Align catalog with actual runtime events per Event_Reconciliation_Report.md |
| 2026-07-04 | Initial catalog freeze | v1.0 baseline |