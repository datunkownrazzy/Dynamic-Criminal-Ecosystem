# DCE v2 — Administrative Interface Catalog

**Date:** 2026-07-10  
**Phase:** 3  
**Author:** Lead Software Architect

---

## Purpose

This catalog defines the complete administrative interface specification for every DCE subsystem. The Control Center must be capable of inspecting, visualizing, configuring, and administrating every major subsystem without ever owning business logic.

---

## Phase 1 — Administrative Surface Audit

### Subsystem Administrative Surfaces

| Subsystem | Internal Data | Visible Data | Private Data | Editable Data | Observable Only | Executable Ops | Confirm Required | Never Exposed |
|-----------|--------------|--------------|--------------|---------------|-----------------|--------------|------------------|-------------|
| Core/Registry | All service registrations | Service names, status | Internal registry state | Register/Unregister services | List services | ✅ | Cleanup all | ✅ |
| Scheduler | Task definitions, timers | Task list, status, intervals | Timer handles | Pause/Resume/Reschedule | ListTasks output | ✅ | ClearAll | ✅ |
| Event Bus | Handler tables, metrics | Event list, metrics | Internal handler refs | Clear handlers | GetMetrics output | ✅ | None | Emit interception |
| Logger | Log entries, config | Recent logs | File handles | Set log level | Log output | ✅ | Clear logs | ✅ |
| World | Regions, state, time, weather | Region states, time, weather | Simulation internals | Time/weather set | Region/world data | ✅ | Layer ticks | ✅ |
| Organizations | Org state, finances, heat | All org data | Internal AI decisions | Create/Update/Delete | Org states, heat | ✅ | Force decisions | ✅ |
| AI Director | Decision queues, scoring | Active decisions | Scoring algorithms | Evaluate org | Decision history | ✅ | ✅ | Clear decisions |
| Dispatch | Calls, units, assignments | Active calls | CAD internals | Create/Update/Resolve | Call states | ✅ | Transfer units | ✅ |
| Evidence | Items, chains, cases | All evidence data | Chain secrets | Transfer/Link | Evidence states | ✅ | Verify evidence | ✅ |
| Scenario Engine | Templates, active scenarios | Active scenarios | Scenario logic | Create/Interdict | Scenario states | ✅ | Execute scenario | ✅ |
| Territory | Ownership, contests, history | Territory data | Influence calc | Claim/Contest | Territory states | ✅ | None | ✅ |
| Economy | Accounts, transactions, flows | Account balances | Transaction processing | Inject/Remove money | Financial state | ✅ | ✅ | System balances |

---

## Phase 2 — Administrative Contract

### Standard Administrative Contract Methods

Every subsystem shall implement the following administrative contract methods:

#### Status Contract
```
GetStatus() → { state: "running"|"paused"|"error", lastTick: number, uptime: number }
```

#### Health Contract
```
GetHealth() → { healthy: boolean, errorCount: number, lastError: string, errorRate: number }
```

#### Metrics Contract
```
GetMetrics() → { dispatchTimes: table, errorRates: table, throughput: number }
```

#### Statistics Contract
```
GetStatistics() → { totalProcessed: number, currentCount: number, peakCount: number }
```

#### Configuration Contract
```
GetConfiguration() → { config: table }  -- Returns current config without secrets
```

#### Capabilities Contract
```
GetCapabilities() → { admin: boolean, readOnly: boolean, actions: string[] }
```

#### Administrative Actions Contract
```
Enable() / Disable() / Reset() / Reload() / MaintenanceMode()
```

---

## Phase 3 — Visualization Architecture

### Subsystem Visualization Requirements

#### Organizations Visualization

| Aspect | Preferred Viz | Dashboard | Graph Type |
|--------|---------------|-----------|------------|
| Hierarchy | Node graph | Org Manager | Tree/directed graph |
| Territory | World map overlay | World Manager | Heatmap/polygon |
| Relationships | Network graph | Org Manager | Undirected graph |
| Finances | Bar/line chart | Economics (deferred) | Time series |
| Heat | World overlay | World Manager | Color gradient |
| Operations | Timeline | AI Manager | Gantt chart |
| Leadership | Table + Detail | Org Manager | Table |

#### World Visualization

| Aspect | Preferred Viz | Dashboard | Graph Type |
|--------|---------------|-----------|------------|
| Regions | Map overlay | World Manager | Geographic |
| MLOs | List + Map markers | World Manager | Table/geographic |
| Interiors | List | World Manager | Table |
| Streaming | Flow diagram | World Manager | Sankey |
| Simulation Layers | Timeline | World Manager | Timeline |
| Civilian Density | Heatmap | World Manager | Heatmap |
| Active Incidents | Map markers | Dispatch Manager | Geographic |
| Named Places | Map labels | World Manager | Geographic |

#### Dispatch Visualization

| Aspect | Preferred Viz | Dashboard | Graph Type |
|--------|---------------|-----------|------------|
| Active Calls | List + Map | Dispatch Manager | Table/geographic |
| Unit Assignments | Map lines | Dispatch Manager | Flow |
| Priorities | Color-coded list | Dispatch Manager | Table |
| Response Timelines | Timeline | Dispatch Manager | Timeline |
| Queue Status | Queue diagram | Dispatch Manager | Flow |

#### Evidence Visualization

| Aspect | Preferred Viz | Dashboard | Graph Type |
|--------|---------------|-----------|------------|
| Custody Chains | Directed graph | Evidence Manager | Tree |
| Investigations | Case cards | Evidence Manager | Table |
| Relationships | Network graph | Evidence Manager | Undirected graph |
| Evidence Graph | Evidence tree | Evidence Manager | Tree |

#### AI Director Visualization

| Aspect | Preferred Viz | Dashboard | Graph Type |
|--------|---------------|-----------|------------|
| Decision Queues | Queue list | AI Manager | Table |
| Active Objectives | Card list | AI Manager | Table |
| Decision History | Timeline | AI Manager | Timeline |
| Behavior Trees | Tree diagram | AI Manager | Tree |

#### Scheduler Visualization

| Aspect | Preferred Viz | Dashboard | Graph Type |
|--------|---------------|-----------|------------|
| Running Jobs | List | Server Monitor | Table |
| Execution Timelines | Gantt chart | Server Monitor | Timeline |
| Performance | Line chart | Server Monitor | Time series |
| Latency | Histogram | Server Monitor | Histogram |

---

## Phase 4 — World Platform Integration Specification

### World Platform Services

| Service | Administrative Interface | Adapter Needed | CC Consumer |
|---------|------------------------|---------------|-------------|
| WorldService | GetRegionState, GetAllRegionIds, GetAllRegionStates, GetTime, GetWeather, Layer0Tick, Layer1Tick | WorldAdapter | LocationManager |
| RegionModel | Region state, layer, adjacent regions | RegionAdapter | LocationManager |
| LocationProviders | Create, Update, Delete, List, Teleport | LocationAdapter | LocationEditor |
| TerritoryService | ListTerritories, GetTerritory, ClaimTerritory | TerritoryAdapter | WorldManager |

### WorldAdapter Interface Specification

```lua
--- Administrative World Adapter Interface
---@class IWorldAdapter
---@field GetRegionCatalog fun():table<List of region summaries>
---@field GetRegionDetails fun(regionId:string):table|nil
---@field GetWorldTime fun():table<Current simulated time>
---@field GetWorldWeather fun():string
---@field GetLocationCatalog fun():table<List of locations>
---@field GetLocationDetails fun(locationId:string):table|nil
---@field CreateLocation fun(data:table):boolean, string|nil
---@field UpdateLocation fun(id:string, data:table):boolean, string|nil
---@field DeleteLocation fun(id:string):boolean
---@field GetTerritoryCatalog fun():table<List of territories>
---@field GetTerritoryDetails fun(territoryId:string):table|nil
```

---

## Phase 5 — Organization Platform Integration Specification

### Organization Administrative Model

| Aspect | Data Source | Visibility | Edit Allowance |
|--------|-------------|------------|----------------|
| Structure | Organizations.GetState | Full | Full |
| Membership | Organizations.GetState.members | List | Add/Remove |
| Leadership | Organizations.GetLeadership | Full | Full |
| Territory | (Future Territory service) | Full | Claim/Release |
| Economy | Organizations.AddMoney, future Finance | Summary | Inject/Remove |
| Heat | Organizations.AddHeat | Current + History | ✅ |
| Relationships | (Future Relationship service) | Full | Edit |
| AI Goals | AIDirector.GetActiveDecision | View | Trigger |
| Operations | AIDirector + Organizations | View | ✅ |
| Recruitment | Organizations internal | None | Trigger AI |
| War State | Organizations internal | Summaries | None |
| Resource Flow | (Future Economy) | Summaries | Inject/Remove |
| Command Hierarchy | Organizations.GetLeadership | Full | Full |

---

## Phase 6 — Runtime Monitoring Specification

### Server Monitor Data Requirements

| Metric | Source | Collection Method | Display |
|--------|--------|-------------------|---------|
| CPU Usage | System | Periodic sample | Gauge |
| Memory | System | Periodic sample | Gauge |
| Server FPS | System | Periodic sample | Gauge |
| Tick Usage | Scheduler | ListTasks + GetMetrics | Bar chart |
| Event Throughput | EventBus.GetMetrics | totalDispatches | Line chart |
| Plugin Health | PluginRegistry | Plugin status | Table |
| Service Health | Each service GetHealth | Each service | Table |
| Resource Health | Framework | Resource state | Table |
| Runtime Warnings | EventBus | Error events | Alert list |
| Performance Regressions | Scheduler | Error counts | Alert list |
| Simulation Bottlenecks | World/AI/Dispatch events | Event frequency | Timeline |

---

## Phase 7 — Administrative Workflows

### Workflow 1: Organization Lifecycle

```
1. Create Organization
   → OrganizationEditor.CreateOrganization()
   → OrganizationAdapter.CreateOrganization()

2. Assign Territory
   → WorldManager.GetTerritories()
   → OrganizationEditor.UpdateOrganization(assign territory)

3. Configure AI
   → AIDirector.EvaluateOrganization(orgId)

4. Spawn Leadership
   → OrganizationEditor.UpdateOrganization(set leader)

5. Initialize Economy
   → (Deferred to Economy system)

6. Start Simulation
   → World.Layer0Tick/World.Layer1Tick
```

### Workflow 2: Location Lifecycle

```
1. Create Location Type
   → LocationManager.RequestCreateLocation(type)
   → WorldAdapter.CreateLocation()

2. Assign Region
   → WorldManager.GetLocations()
   → WorldAdapter.UpdateLocation(regionId)

3. Register Streaming
   → (Deferred to Streaming system)

4. Generate Metadata
   → LocationProvider.Preview()

5. Validate
   → LocationProvider.Validate()

6. Publish
   → Persist to storage
```

### Workflow 3: Simulation Control

```
1. Pause Simulation
   → Scheduler.Pause("world:layer0:tick")
   → Scheduler.Pause("world:layer1:tick")
   → World.SetPause(true)

2. Modify World
   → WorldAdapter.UpdateLocation()
   → WorldAdapter.UpdateRegion()

3. Resume Scheduler
   → Scheduler.Resume("world:layer0:tick")
   → Scheduler.Resume("world:layer1:tick")

4. Broadcast Changes
   → EventBus.Emit("world:admin:changed")
```

---

## Phase 8 — Integration Matrix

### Complete Integration Chain

| Subsystem | Admin Interface | Adapter | CC Service | Plugin | UI | Visualization |
|-----------|-----------------|---------|------------|---------|-----|---------------|
| World | World:GetRegionState, GetTime, GetWeather | WorldAdapter | LocationManager | world-manager | Tabs: Locations/Territories/Providers | Geographic/Table |
| Organizations | Organizations:GetAllOrgStates, GetState | OrganizationAdapter | OrganizationEditor | organization-manager | Org cards | Network Graph |
| Dispatch | Dispatch:GetActiveCalls, CreateCall | DispatchAdapter | (none) | dispatch-manager | Call list | Timeline/Geographic |
| Evidence | Evidence:GetAllEvidence, TransferEvidence | EvidenceAdapter | (none) | evidence-manager | Evidence table | Tree/Heatmap |
| AI Director | AIDirector:GetActiveDecision, Tick | AIAdapter | (none) | ai-manager | Decision cards | Timeline/Tree |
| Scheduler | Scheduler:ListTasks, Pause, Resume | SchedulerAdapter | (none) | server-monitor | Task list | Timeline/Performance |
| Event Bus | EventBus:GetMetrics, GetStats | EventBus (direct) | (none) | (none) | (none) | Metrics dashboard |
| Territory | (Future) | TerritoryAdapter | LocationManager | world-manager | Territory map | Geographic/Heatmap |

---

## Phase 9 — Gap Analysis

### Missing Adapters

| Adapter | Required For | Priority |
|---------|--------------|----------|
| WorldAdapter | Location/territory editing | High |
| OrganizationAdapter | Organization editing | High |
| DispatchAdapter | Dispatch monitoring | High |
| EvidenceAdapter | Evidence browser | High |
| AIAdapter | AI dashboard | Medium |
| TerritoryAdapter | Territory visualization | Medium |

### Missing Metrics

| Metric | Subsystem | Priority |
|--------|-----------|----------|
| Territory ownership history | Territory | High |
| Heat history | Organizations | Medium |
| Decision history | AI Director | Medium |
| Task timing history | Scheduler | Medium |
| Evidence transfer history | Evidence | Low |

### Missing Events

| Event | Subsystem | Priority |
|-------|-----------|----------|
| territory:ownership:claimed | Territory | High |
| territory:ownership:lost | Territory | High |
| territory:ownership:contested | Territory | High |
| economy:account:created | Economy | Medium |
| investigation:case:opened | Investigation | Medium |

### Missing Administrative Capabilities

| Capability | Subsystem | Priority |
|------------|-----------|----------|
| GetHealth on all services | All | Medium |
| GetMetrics on all services | All | Medium |
| Administrative actions (Enable/Disable) | All | Low |
| Configuration editor | All | Medium |

---

## Implementation Roadmap

### Phase 4 Priority Items

| Priority | Task | Subsystem | Effort |
|----------|------|-----------|--------|
| 1 | Implement WorldAdapter | dce-world | Medium |
| 2 | Implement OrganizationAdapter | dce-ai | Medium |
| 3 | Add admin endpoints to services | All services | Low |
| 4 | Create Territory system | dce-world | High |
| 5 | Connect plugins to endpoints | CC | Low |