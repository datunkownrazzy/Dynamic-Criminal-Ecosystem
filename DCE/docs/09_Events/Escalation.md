# DCE Subsystem Specification — Event Escalation & Lifecycle Promotion

## 1. Status & Metadata
* **Status:** DRAFT (Pending Review)
* **Author:** AI Lead Architect
* **Dependencies:** `docs/05_Organizations/Organizations.md`, `docs/08_AI/AIDirector.md`, `docs/04_World/WorldEngine.md`
* **Subsystem:** `dce-events`
* **Tracks Layout:** `docs/09_Events/Escalation.md`

---

## 2. Purpose
This document specifies the internal mechanics of **Scenario Escalation and Phase Promotion**. In DCE, criminal scenarios are not static, isolated events that run on linear tracks. They are stateful, branching trees assembled from atomic building blocks called **Stages**. 

This document defines how these stages progress chronologically, how they interact with civilian/police inputs, and how they dynamically scale their physical footprint across the **Four-Layer Simulation** model as players move throughout the San Andreas map.

---

## 3. The Stage Progression Architecture
Every Scenario selected by the AI Director executes across an abstract timeline called the **Lifecycle Chain**. This chain tracks how an operation develops from conception to environmental consequence.

### 3.1 The Lifecycle Chain Stages
1. **Planning:** Statistical Layer 0 state updates. The organization allocates money and flags involved assets (vehicles, safehouses).
2. **Travel:** Selected Agents begin moving toward the destination vector. If unobserved, this is handled purely via statistical timing grids.
3. **Preparation:** Setting up the location (e.g., lookouts taking positions, opening a warehouse door, initializing a transaction space).
4. **Execution:** The core criminal transaction or incident window (e.g., crack cooking, extortion handshake, high-tier smuggling handoff).
5. **Reaction:** How the scene changes based on outside interaction (e.g., civilian runs away, silent trip-wire alarm fires, lookouts sound an alert).
6. **Escape:** Retraction of assets from the scene via optimized flight-path mapping.
7. **Investigation:** Scene cleanup or preservation of dynamic evidence chains left behind for law enforcement forensics.
8. **Long-term Consequences:** Faction memory adjustments, territory heat updates, and supply chain modifications.

---

## 4. Four-Layer Simulation Promotion (Fidelity Scaling)
As players or police officers physically move closer to a running scenario, the Event Director elevates its physical manifestation layer to balance performance costs seamlessly.

```text
 [ Player Outside Boundary Radius ] ──> Layer 0 (Statistical, numbers only)
                 │
   (Player enters macro-grid unit)
                 ▼
 [ Player Approaching Scene Vector ] ──> Layer 1 (Ambient atmosphere, lookouts spawn)
                 │
   (Player within interaction radius)
                 ▼
 [ Player Witnesses Handoff/Op ]    ──> Layer 2 (Interactive, entities interact)
                 │
   (Shots fired / 911 dispatched)
                 ▼
 [ Full Active Scene / Combat ]     ──> Layer 3 (Major Incident, full AI combat trees)

4.1 Boundary Matrix Trigger Rules
Promotion Shift Triggering Conditions Engine Action
Layer 0 → Layer 1: Active player crosses into the 500mx500m macro-grid cell holding the event. Core allocates resource space and prepares entity tables.
Layer 1 → Layer 2: Player crosses the contextual interaction threshold (default: 150m from center point).Physical peds and vehicles spawn using occluded spawning logic (behind walls/corners).
Layer 2 → Layer 3: Weapons discharge detected, direct player/police aggro, or witness 911 call completes.Incident links directly to DispatchService and activates aggressive AI behavioral combat profiles.

5. Escalation Branching & Data Schema
Escalation maps out how an incident mutates dynamically based on external disruption variables. These behaviors are configured as clear data paths in /schemas/events/.

5.1 Branching Decision Matrix Example
JSON
{
  "stageId": "stage_execution_deal",
  "defaultDuration": 300,
  "triggers": {
    "onPlayerAggro": {
      "condition": "Faction.Personality.violence >= 50",
      "branchToTrue": "stage_major_shootout",
      "branchToFalse": "stage_evasive_escape"
    },
    "onCivilianWitness": {
      "chance": 65,
      "branchTo": "stage_reaction_vague_call"
    }
  }
}
If an incident pushes to a new branch, the EventDirector terminates the active stage behavioral loop, executes clean entity cleanup frames if required, and boots up the configuration routine of the newly targeted structural branch state.

6. Emitted Events
The Event Escalation module pipes telemetry downstream via the internal Event Bus:

event:scenario:created — { scenarioId, factionId, macroGridCoordinates }

event:stage:promoted — { incidentId, fromLayer, toLayer, currentStage }

event:scenario:disrupted — { incidentId, reason, civilianInterference }

event:scenario:resolved — { incidentId, executionSuccessState, materialYield }

7. What This Document Does Not Cover
How the AI Director scores which scenario to pick initially → docs/08_AI/AIDirector.md

How dispatch calls get packaged and passed into external CAD models → docs/10_Dispatch/CADIntegration.md

How forensic evidence degrades over time at an investigation scene → docs/11_Evidence/Evidence.md