# DCE-0004: Perception Pressure for Covert Enforcement Signals

**Status:** Proposed  
**Version:** 0.1  
**Owner:** Architecture  
**Dependencies:** dce-ai, dce-world, Event Bus

---

## 1. Purpose

Add a new AI-facing pressure layer that makes criminal organizations react to law enforcement presence more realistically, including:

- clearly visible police activity such as marked patrols, uniforms, and obvious patrol presence
- covert enforcement signals such as GND/detective-style units, plainclothes officers, and unmarked vehicles

The goal is not to make the AI “see police” in a literal sense, but to model a believable perception of exposure and risk. The system should make organizations hesitate, abort, or shift to lower-profile behavior when enforcement presence feels credible and uncomfortable.

---

## 2. Problem Statement

The current AI scoring model already uses:

- organizational heat
- regional police presence
- general deterrents for risk

However, it does not distinguish between:

- obvious visible pressure
- subtle covert pressure

This means the AI cannot yet react to the difference between a visible patrol and an undercover unit that may be watching the same area. That gap makes the simulation feel less nuanced and less believable for roleplay-heavy servers.

---

## 3. Scope

### In Scope

- Add a new AI pressure concept called `perceptionPressure`
- Distinguish between visible and covert enforcement signals
- Use that pressure as a scoring deterrent in the AI director decision layer
- Allow organizations to react by delaying, aborting, or shifting to lower-profile activities
- Expose the feature through configuration so it can be tuned without code changes

### Out of Scope

- Full player-detection or target-specific AI logic
- Hardcoded rules for specific police factions or job names
- A new service layer
- Full social-network-style warning behavior beyond a simple pressure response

---

## 4. Architectural Approach

This feature should be implemented as an extension of the existing AI and world-state flow, not as a separate subsystem.

### Ownership

- `dce-world` provides raw environmental context and enforcement-relevant signals
- `dce-ai` converts those signals into organization-facing pressure
- `dce-events` may optionally subscribe to pressure events for later expansion

This keeps ownership clean and avoids introducing a new service that duplicates existing responsibilities.

---

## 5. Functional Design

### 5.1 New Pressure Model

The AI should track a per-organization pressure value with two subcomponents:

- `visiblePressure` — for obvious police presence
- `covertPressure` — for subtle or undercover pressure

The combined value should be:

```lua
perceptionPressure = visiblePressure + covertPressure
```

### 5.2 Pressure Sources

#### Visible Pressure

Examples:
- marked patrol units
- uniforms or obvious police clothing
- visible police presence in the same region
- active lights/sirens or obvious enforcement behavior

#### Covert Pressure

Examples:
- plainclothes units
- detective-style units
- unmarked vehicles
- repeated surveillance patterns
- suspicious police presence that is not immediately obvious

### 5.3 Pressure Behavior

When pressure rises, the AI should begin to prefer lower-profile actions.

Examples:
- avoid high-heat activities
- delay operations until pressure drops
- switch to low-footprint or planning-heavy activities
- warn contacts or reduce exposure risk
- abort if pressure spikes beyond a threshold

---

## 6. Data Contract

### 6.1 Region State Extension

The region state passed into AI scoring should optionally include a new field:

```lua
regionState.enforcementSignals = {
    visible = 0,   -- 0-100
    covert = 0,    -- 0-100
    confidence = 0 -- 0-100, optional reliability rating
}
```

If this field is absent, the system should safely default to zero.

### 6.2 Organization Runtime Extension

The organization runtime should gain:

```lua
runtime.perceptionPressure = 0
runtime.visiblePressure = 0
runtime.covertPressure = 0
runtime.pressureAlertCooldown = 0
runtime.lastPressureSource = nil
```

### 6.3 Pressure Decay

Pressure should decay over time so it does not remain permanently elevated.

Suggested behavior:
- pressure decays gradually each tick
- high covert pressure decays more slowly than visible pressure
- repeated sightings should temporarily reinforce pressure rather than simply stack forever

---

## 7. Configuration Design

Add a new configuration block under `Config.AI`.

```lua
Config.AI.PerceptionPressure = {
    Enabled = true,
    VisibleWeight = 1.0,
    CovertWeight = 0.7,
    DecayRate = 1.5,
    VisibleThreshold = 35,
    CovertThreshold = 25,
    SpikeThreshold = 60,
    CooldownMinutes = 10,
    HighHeatMultiplier = 0.6,
}
```

### Configuration Notes

- `VisibleWeight` should be stronger than `CovertWeight`
- `VisibleThreshold` should trigger obvious caution behavior
- `CovertThreshold` should trigger subtle caution behavior
- `SpikeThreshold` should trigger stronger avoidance or deferral
- `CooldownMinutes` should prevent pressure from causing constant panic loops

---

## 8. Scoring Integration

The AI scoring pass should incorporate the new pressure as an additional deterrent.

### Proposed formula change

```lua
local visiblePressureDeterrent = regionState.enforcementSignals.visible * Config.AI.PerceptionPressure.VisibleWeight
local covertPressureDeterrent = regionState.enforcementSignals.covert * Config.AI.PerceptionPressure.CovertWeight

score = score - visiblePressureDeterrent
score = score - covertPressureDeterrent
```

### Behavior Rules

- If `visiblePressure >= VisibleThreshold`, penalize high-profile operations more heavily
- If `covertPressure >= CovertThreshold`, penalize suspicious or visible activities even if the police presence is not obvious
- If `perceptionPressure >= SpikeThreshold`, strongly reduce the score of aggressive or high-heat activities
- If heat is already high, multiply the penalty so the AI feels the pressure more sharply

This should be additive to the existing heat and police-presence penalties, not a replacement.

---

## 9. Runtime Behavior Rules

### 9.1 Pressure Thresholds

- Low: no meaningful change
- Moderate: activity selection shifts toward lower-profile operations
- High: organization delays or aborts riskier actions
- Spike: organization changes approach, moves assets, or avoids the area

### 9.2 Example Outcomes

When pressure crosses a threshold:
- a drug sale may be deferred
- a delivery may be rescheduled
- a visible operation may be replaced with a planning-heavy or low-footprint action
- the organization may avoid operating in that region for a short cooldown window

---

## 10. Event Emission

The AI should emit events for observability and future expansion.

### Proposed events

- `organization:perception:pressure_updated`
- `organization:perception:pressure_spiked`
- `organization:activity:deferred`

### Suggested payload

```lua
{
    organizationId = orgId,
    regionId = regionId,
    visiblePressure = visiblePressure,
    covertPressure = covertPressure,
    perceptionPressure = perceptionPressure,
    reason = "covert_enforcement"
}
```

These events should be emitted only when pressure crosses a meaningful threshold, not every tick.

---

## 11. Implementation Plan

### File 1: `DCE/src/dce-ai/config.lua`

Add configuration values for:
- pressure weights
- thresholds
- decay settings
- cooldowns

### File 2: `DCE/src/dce-ai/models/organization.lua`

Add runtime fields and helper methods for:
- setting pressure values
- decaying pressure
- applying pressure spikes

### File 3: `DCE/src/dce-ai/services/organizations.lua`

Expose public helpers for:
- `SetPerceptionPressure(orgId, visible, covert)`
- `ApplyPerceptionPressure(orgId, visible, covert, source)`
- `DecayPerceptionPressure(orgId, deltaTime)`

### File 4: `DCE/src/dce-ai/simulation/scoring.lua`

Update scoring to:
- read `regionState.enforcementSignals`
- apply visible/covert deterrents
- integrate the pressure thresholds into candidate selection

### File 5: `DCE/src/dce-world/models/region.lua` or the relevant world-state provider

Ensure the region state can carry enforcement signal data, even if the first implementation passes zeros by default.

### File 6: `DCE/src/dce-events/...` (optional, later)

Subscribe to pressure events if additional systems such as dispatch, evidence, or civilian AI should react later.

---

## 12. Acceptance Criteria

The feature is considered complete when:

1. Organizations can react to visible and covert enforcement pressure through the AI scoring layer.
2. Plainclothes, detective-style, or unmarked-vehicle pressure reduces the score of high-profile activities.
3. Pressure decays over time and does not permanently lock organizations into avoidance behavior.
4. The behavior is tunable through config without requiring code edits.
5. The system degrades safely when no enforcement signal data is present.

---

## 13. Implementation Notes for Cline

Implement this as a small, incremental feature in the existing AI layer.

Recommended order:
1. add config values
2. add runtime fields and decay helpers
3. update scoring logic
4. add event emission for meaningful pressure changes
5. verify behavior with low-risk simulations and ensure no regressions

Keep the first pass conservative. The initial version should influence scoring and activity selection, not attempt to create a full stealth or counter-surveillance system.
