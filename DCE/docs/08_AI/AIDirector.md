# DCE Subsystem Specification — AI Director

**Status:** Draft (Pending Review)  
**Version:** 1.0  
**Owner:** Architecture  
**Dependencies:** Service Registry, Universal Event Bus, World Engine, Regions, Organizations

---

## 1. Purpose

The AI Director (`AIDirector`) is the operational logic center of DCE. It acts as a non-deterministic, data-driven system that evaluates the passive state vectors of World Regions and Criminal Organizations, and translates them into active, contextual game events. 

While `Organizations.md` defines criminal-entity truth and `Regions.md` defines environmental truth, the AI Director reads both and executes decisions. It manages:
1. **The Scoring Pass Matrix** (evaluating and selecting Candidate Scenarios).
2. **Organization State Transitions** (evaluating when a faction shifts states).
3. **Behavioral Restrictions/Privileges** unlocked by each Organization State.

---

## 2. Time-Slicing & Evaluation Loop

To preserve server frame rates within FiveM's single-threaded environment, the AI Director strictly avoids global, synchronous evaluation sweeps. It utilizes a round-robin, time-sliced scheduler.

* **The Cycle:** Instead of processing every organization and region on a single 5-minute timer, the Director evaluates exactly **one** Organization or **one** Region grid per frame tick.
* **The Cadence:** For a server tracking 10 organizations and 50 macro-regions, a complete map-wide statistical evaluation pass finishes every 60 frames (approximately 1 second at 60 FPS), dropping the continuous frame cost to near-zero.

---

## 3. Organization State Transitions & Privileges

As established in `Organizations.md`, the Organization Service merely hosts the state enum. The logic governing transitions and state-based behavioral privileges lives entirely within the AI Director.

### 3.1 Transition Conditions Matrix

| From State | To State | Trigger / Threshold Conditions |
| :--- | :--- | :--- |
| `Stable` | `Aggressive Expansion` | `money` > 150% baseline threshold AND `morale` > 70 AND `heat` < 40. |
| `Any State` | `Conflict` | A rival organization's scoring pass succeeds on a Turf Contestation scenario inside an owned territory. |
| `Any State` | `Under Investigation` | Police intelligence metrics (tracked in `Intelligence.md`) cross the critical threshold (> 75). |
| `Under Investigation` | `Suppressed` | A major law enforcement raid scenario resolves with a high player-police success rating. |
| `Suppressed` | `Recovering` | `heat` decays below 30 AND a configurable minimum cooldown time (e.g., 2 hours) elapses. |

### 3.2 State-Based Behavioral Unlocks
The AI Director injects the current organization state as a definitive gatekeeper filter before running any scenario scoring algorithms:

* **`Dormant` / `Suppressed`:** Only selects low-profile, non-violent scenarios (`planning` heavy, low footprint, zero public noise) like small-scale smuggling deliveries or back-alley recruitment.
* **`Aggressive Expansion`:** Automatically adds a flat $+25$ baseline weight modifier to all Turf Infiltration, Commercial Front Extortion, and Drive-By Skirmish scenario candidates.
* **`Under Investigation`:** Filters out any scenario with a base `heat` output greater than 10. Forces the organization to prioritize front businesses and money laundering systems.

---

## 4. The Scoring Engine

For any given candidate Scenario, the AI Director computes a composite score ($S$) mapping dynamically between `0` and `100`:

$$S = \text{BaseWeight} + \sum (\text{Modifiers}) - \sum (\text{Deterrents})$$

If $S < 40$, the candidate is completely thrown out of execution consideration. If it passes, it enters a weighted lottery pool for selection within that region.

### 4.1 Evaluation Matrix Mapping

The scoring loop pulls properties explicitly from the target organization's config files and active memory state:

```lua
-- Conceptual evaluation snapshot within a time-sliced tick
local orgState = Organizations.GetState(orgId)
local targetRegion = WorldEngine.GetRegion(regionId)

-- Naming matches camelCase layout established in Organizations.md
local traits = orgIdentity.personality 
local stats = orgState.runtime

Trait Multipliers: If a Scenario is tagged as type = "narcotics", its score is modified directly by traits.drugTrade. If traits.violence is exceptionally high, weapon deployment and asset defense scenarios receive priority scaling.

Resource Scaling: If stats.money drops below baseline maintenance costs, the weight of high-risk, immediate-payout scenarios (e.g., Stolen Vehicle Rings, Interactive Robberies) scales aggressively to simulate organizational desperation.

Environmental Context: Modifiers are blended against regional variables (e.g., Rain/Night scales traits.smuggling efficiency; high regional police presence acts as an exponential deterrent deduction weight).

5. Emitted Events
The AI Director publishes specific operational events to let external systems hook into the decision loop:

ai:director:decision:executed — { organizationId, regionId, selectedScenarioId }

ai:director:state_transition:enforced — { organizationId, oldState, newState, reason }

ai:director:ceilings:throttled — { scenarioId, layerIndex } (Fired when an incident cannot promote to Layer 3 due to performance caps).

6. What This Document Does Not Cover
The multi-stage progression pathways of active incidents → Escalation.md

The physical creation and configuration schemas of event scenarios → Scenarios.md

The tracking layout of law enforcement investigations and case building → Investigations.md