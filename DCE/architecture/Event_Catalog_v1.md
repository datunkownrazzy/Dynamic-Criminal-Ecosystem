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

The list below is given in the plain "PascalCase subject+verb" form used in the original design conversation (e.g., `OrganizationCreated`) for readability. Per `DCE-0002`'s actual convention, each maps to a canonical `domain:subject:verb` event name used in code — both forms are given so the mapping is unambiguous.

## Organization Domain

| Plain name | Canonical event name | Emitted when |
|---|---|---|
| OrganizationCreated | `organization:lifecycle:created` | A new Organization is spawned (data-loaded or plugin-registered, per `Plugin_SDK.md`) |
| OrganizationDestroyed | `organization:lifecycle:destroyed` | An Organization is fully eliminated (terminal state — see `State_Machines.md` open conflict) |
| OrganizationSplit | `organization:lifecycle:split` | An Organization fractures into two or more factions |
| OrganizationMerged | `organization:lifecycle:merged` | Two Organizations combine |
| MemberJoined | `organization:member:joined` | A new member/Agent joins an Organization |
| MemberLeft | `organization:member:left` | A member departs (desertion, death, arrest) |
| LeaderChanged | `organization:leadership:changed` | (Already defined in `Organizations.md` as `organization:leadership:changed` — same event, confirmed consistent) |

## Territory Domain

| Plain name | Canonical event name | Emitted when |
|---|---|---|
| TerritoryClaimed | `territory:ownership:claimed` | A Territory gains its first/new owning Organization |
| TerritoryLost | `territory:ownership:lost` | A controlling Organization loses a Territory |
| TerritoryContested | `territory:ownership:contested` | Two or more Organizations have competing influence crossing a contest threshold |

## Economy Domain

| Plain name | Canonical event name | Emitted when |
|---|---|---|
| DrugShipmentStarted | `economy:shipment:started` | A supply-chain shipment begins (per `Economy.md`) |
| DrugShipmentIntercepted | `economy:shipment:intercepted` | Law enforcement or a rival disrupts a shipment |
| WeaponShipmentCompleted | `economy:shipment:completed` (with `shipmentType` field distinguishing drugs/weapons, rather than a separate event per good type — keeps the catalog from growing one event per commodity) | A shipment successfully arrives |
| MoneyLaundered | `economy:funds:laundered` | Illicit funds convert to clean funds (per `Economy.md`'s laundering process) |
| MoneyTransferred | `economy:funds:transferred` | **The canonical example from `ADR-0005`** — any funds movement between Economy and another domain |
| BusinessPurchased | `economy:business:purchased` | An Organization acquires a front/legitimate business |
| BusinessRaided | `economy:business:raided` | Law enforcement raids a business |

## Dispatch Domain

| Plain name | Canonical event name | Emitted when |
|---|---|---|
| DispatchCallCreated | `dispatch:call:created` | (Already defined in `DCE-0002`'s own examples — confirmed consistent) |
| OfficerAssigned | `dispatch:call:officer_assigned` | A unit is assigned to a call via the active adapter |

## Evidence Domain

| Plain name | Canonical event name | Emitted when |
|---|---|---|
| EvidenceCollected | `evidence:item:recovered` | (Already defined in `DCE-0002`'s examples as `evidence:item:recovered` — kept as-is rather than introducing a second name for the same thing) |
| EvidenceDestroyed | `evidence:item:destroyed` | Evidence is deliberately destroyed or naturally decays past recovery (per `Evidence.md`'s lifecycle) |

## Investigation Domain

| Plain name | Canonical event name | Emitted when |
|---|---|---|
| InvestigationOpened | `investigation:case:opened` | A new case file is created |
| InvestigationClosed | `investigation:case:closed` | A case reaches a terminal status |
| ArrestMade | `investigation:outcome:arrest` | An arrest results from a case or a live Incident |
| RaidExecuted | `investigation:outcome:raid` | A raid is carried out against a location tied to a case |

## Informant Domain

| Plain name | Canonical event name | Emitted when |
|---|---|---|
| InformantActivated | `investigation:informant:activated` | An informant begins providing intelligence (grouped under the Investigation domain rather than a standalone Informant domain, since informants only exist in service of casework — avoids a one-event domain) |

## Scenario / Escalation Domain

| Plain name | Canonical event name | Emitted when |
|---|---|---|
| ScenarioStarted | `organization:activity:started` | (Already defined in `DCE-0002`'s own examples — kept as-is; "Scenario" and "Organization activity" refer to the same thing per `Glossary.md`) |
| ScenarioEscalated | `organization:activity:escalated` | (Already defined in `DCE-0002`'s examples — kept as-is) |
| ScenarioResolved | `scenario:lifecycle:resolved` | A Scenario reaches any terminal outcome (success, failure, interrupted) — new canonical name, since neither existing doc had defined the resolution event explicitly |

**Note:** This table is exactly where the `Escalation.md` vs. `Scenarios_engine.md` conflict (flagged in the prior review) needs resolving before implementation — both documents describe scenario progression but neither currently emits events matching this catalog's names. Whichever model is chosen should be updated to emit `organization:activity:started/escalated` and `scenario:lifecycle:resolved` exactly as named here.

## World / Simulation Domain

| Plain name | Canonical event name | Emitted when |
|---|---|---|
| WorldTickStarted | `world:tick:started` | The Simulation Scheduler (`ADR-0004`) begins a new server tick's tier pipeline |
| WorldTickCompleted | `world:tick:completed` | All four priority tiers finish for that tick |

These two are lower-frequency-emission than they sound — per `ADR-0003`'s debouncing guidance and `DCE-0002`'s performance guidance, these should likely be emitted at a sampled interval (e.g., once per second of ticks) rather than genuinely every single tick, to avoid flooding the bus. Exact sampling rate is a `Config.Scheduler.TickEventSampleRate` concern, not hardcoded.

---

## What's Deliberately Not Yet Cataloged

Per `Goals.md`'s deferred list, events for World Chronicle, cross-server sync, and federal/political-pressure systems are not part of this v1.0 freeze — they'll get their own catalog addition when those systems are actually built, not reserved in advance.

## Relationship to Commands

Every "past-tense" event in this catalog corresponds to a "present-tense" Command in `Command_Catalog_v1.md` that, when successfully processed by its owning domain, results in that event being emitted. See that document for the Command side of the pair.
