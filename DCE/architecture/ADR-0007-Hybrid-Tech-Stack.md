# ADR-0007: Hybrid Tech Stack - Language Responsibilities

**Status:** Accepted
**Date:** 2026-07-04
**Author:** Architecture
**Dependencies:** PROJECT_PRINCIPLES.md, ServiceContracts.md, EventContracts.md

---

## Problem

DCE is currently 100% Lua, which aligns with FiveM conventions. However, as the simulation scales with more organizations, territories, and active incidents, performance considerations become critical. This ADR defines clear boundaries for when to introduce additional languages while preserving the architectural principles of the framework.

---

## Decision

### Language Roster and Responsibilities

DCE uses a three-tier language strategy:

| Language | Role | Boundaries |
|----------|------|------------|
| **Lua** | Authoritative Runtime | All simulation logic, service orchestration, event bus, state management |
| **C#** | Performance Coprocessor | Optional computation acceleration only - never owns gameplay state |
| **JavaScript** | Presentation Layer | NUI interfaces only - never contains simulation logic |

### Lua (Primary Runtime)

**Responsibilities:**
- Service orchestration and lifecycle management
- World simulation (time, weather, regions)
- Event Bus and pub/sub communication
- AI Director decision-making
- Scenario engine and escalation
- Organization state management
- Territory simulation logic
- Dispatch/Evidence generation
- Plugin loading and registration
- Integration adapters (ERS, native)
- Configuration and persistence orchestration

**Rationale:**
FiveM's native environment is Lua. Most simulation logic consists of state transitions, event routing, and coordination rather than CPU-intensive computation. Keeping the majority of the project in Lua maximizes compatibility, lowers the barrier for contributors, and simplifies debugging.

### C# (Performance Coprocessor)

**Approved responsibilities:**
- Large statistical simulations
- Graph algorithms (evidence relationships, territory graphs)
- Evidence graph traversal
- Route optimization
- Territory influence calculations
- Spatial indexing
- Large-scale pathfinding
- Heatmap generation
- Future analytics engine

**C# MUST NEVER:**
- Own gameplay logic
- Hold authoritative state
- Initiate gameplay events
- Bypass service boundaries

**Integration Pattern:**
```
Lua Service
    │
    │ publishes computation request event
    ▼
admin:computation:requested
    │
    ├──▶ Computation Service (Lua adapter)
    │        │
    │        └──▶ C# Export (computes, returns result)
    │
    └──▶ Result returned to Lua Service
            Service continues with its logic
```

### JavaScript (Presentation Layer)

**Approved responsibilities:**
- Admin Dashboard UI
- Territory Editor UI
- Analytics graphs
- World Inspector
- Performance Monitor
- Plugin Manager UI
- Configuration UI
- Future Scenario Composer

**JavaScript MUST NEVER:**
- Contain simulation logic
- Make decisions about game state
- Bypass admin permission model

**Integration Pattern:**
```
JavaScript (NUI)
    │
    │ RegisterNUICallback
    ▼
Event: dce-admin:server:request
    │
    ▼
Admin Service (Lua)
    │
    │ DCE:GetService("Target")
    ▼
Target Service (owns its own state)
    │
    │ returns data
    ▼
Admin Service → Client Event
    │
    ▼
JavaScript renders data
```

---

## Consequences

### Positive
- Clear boundaries prevent logic creep into wrong layers
- C# remains optional - servers without it work normally
- JS interfaces are isolated from core simulation
- Contributors know exactly where code belongs

### Architectural Requirements
- Every service defines performance targets (see ADR-0008)
- Profiling must demonstrate bottleneck before C# introduction
- NUI communication must go through Admin Service only
- C# exports are treated as adapters, not services

### Migration Policy
When Lua performance exceeds thresholds:
1. Profile to identify the bottleneck
2. Optimize Lua first (algorithmic improvements)
3. If still over budget, create `dce-compute` C# module
4. C# module exposes same interface as Lua fallback
5. No existing Lua code changes required