## DCE v1.0 – Living Criminal World

This roadmap is the v1.0 scope checklist for the framework. Each item below is covered by a dedicated document under the architecture, simulation, AI, economy, evidence, investigation, and core docs folders.

### Core Systems Coverage

| v1.0 Item | Covered By | Notes |
|---|---|---|
| World simulation | [docs/04_Simulation/World_Engine.md](../04_Simulation/World_Engine.md), [docs/04_Simulation/Regions.md](../04_Simulation/Regions.md), [docs/04_Simulation/Simulation_Layers.md](../04_Simulation/Simulation_Layers.md), [docs/04_Simulation/Time.md](../04_Simulation/Time.md), [docs/04_Simulation/Weather.md](../04_Simulation/Weather.md) | Defines the world state model, region context, simulation layers, and environmental state. |
| Gang AI | [docs/05_Organizations/Organizations.md](../05_Organizations/Organizations.md), [docs/08_AI/AIDirector.md](../08_AI/AIDirector.md), [docs/08_AI/Hierarchy.md](../08_AI/Hierarchy.md) | Covers organization state, AI decision-making, and leadership hierarchy. |
| Territory management | [docs/06_Territories/Territories.md](../06_Territories/Territories.md), [docs/04_Simulation/Regions.md](../04_Simulation/Regions.md) | Covers territory influence, lifecycle, and ownership state. |
| Economy | [docs/07_Economy/Economy.md](../07_Economy/Economy.md), [docs/07_Economy/Procurement.md](../07_Economy/Procurement.md) | Covers illicit funds, operating budget, and procurement flow. |
| Event Director | [docs/09_Events/Escalation.md](../09_Events/Escalation.md), [docs/09_Events/Scenarios_engine.md](../09_Events/Scenarios_engine.md) | Covers scenario escalation and stage progression. |
| Event escalation | [docs/09_Events/Escalation.md](../09_Events/Escalation.md) | Defines the lifecycle chain and layer promotion model. |
| Dispatch integration | [docs/10_Dispatch/Dispatch.md](../10_Dispatch/Dispatch.md), [docs/16_Integrations/IntegrationManager.md](../16_Integrations/IntegrationManager.md) | Covers dispatch, CAD/MDT bridging, and adapter loading. |
| Evidence generation | [docs/11_Evidence/Evidence.md](../11_Evidence/Evidence.md), [docs/11_Evidence/Evidence_Registry.md](../11_Evidence/Evidence_Registry.md), [docs/09_Events/Scenario_Evidence_Integration.md](../09_Events/Scenario_Evidence_Integration.md) | Covers evidence ownership, registry state, and evidence-to-scenario linkage. |
| Investigation framework | [docs/12_Investigations/Investigations.md](../12_Investigations/Investigations.md) | Covers investigation casework and evidence-to-case flow. |
| World persistence | [docs/03_Core/Persistence.md](../03_Core/Persistence.md) | Covers persistence ownership, save/load coordination, and migration expectations. |
| Admin UI | [docs/03_Core/Admin_UI.md](../03_Core/Admin_UI.md) | Covers the v1.0 admin visibility scope and its permission model. |
| Plugin SDK | [docs/03_Core/Plugin_SDK.md](../03_Core/Plugin_SDK.md) | Covers the plugin registration surface and v1.0 extension points. |

### Architecture Guardrails Applied

The documents above are written around the same rules captured in [../01_Project/PROJECT_PRINCIPLES.md](../01_Project/PROJECT_PRINCIPLES.md) and [../../AGENTS.md](../../AGENTS.md):

- single-owner service boundaries,
- event-driven communication through the Event Bus,
- config-driven tuning rather than hardcoded values,
- persistence ownership per service,
- and performance budgets / graceful degradation for simulation systems.