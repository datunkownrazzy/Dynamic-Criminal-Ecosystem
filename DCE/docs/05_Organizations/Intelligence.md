# DCE Subsystem Specification — Organization Memory & Intelligence

## 1. Status & Metadata
* **Status:** DRAFT (Pending Review)
* **Author:** AI Lead Architect
* **Dependencies:** `docs/05_Organizations/Organizations.md`, `docs/08_AI/AIDirector.md`, `docs/11_Evidence/Evidence.md`
* **Subsystem:** `dce-ai` / `dce-investigations`
* **Tracks Layout:** `docs/05_Organizations/Intelligence.md`

---

## 2. Purpose
This specification governs the continuous, dynamic tug-of-war between two linked metrics:
1. **Organization Memory:** An organization's internal tracking of localized law enforcement pressure, heat vectors, and hostile rival boundaries.
2. **Police Intelligence:** The state of law enforcement knowledge regarding a specific criminal faction's leadership structure, asset arrays, and supply networks.

Rather than static global flags, this subsystem establishes a floating equilibrium where criminal operations organically adapt to police behavior, and investigative focus yields compounding exposure for organizations.

---

## 3. Organization Memory (The Adaptive Loop)
Organizations are not amnesiac entities; they track environmental anomalies and adjust their local operational risks accordingly.

### 3.1 Memory Architecture
An organization's runtime state maintains a transient memory cache mapped by `regionId`:

```lua
-- Conceptual layout inside Faction memory arrays
orgState.memory = {
    regions = {
        ["rancho"] = {
            policePressure = 45.2,   -- Localized patrol density indicator
            interdictions  = 3,      -- Failed operations count over trailing 24h
            lastRaidTimestamp = 1719878400
        }
    },
    rivalAggression = {
        ["ballas"] = 85.0           -- Tracked threat indicator from specific rivals
    }
}

3.2 Behavioral Modification MechanicsWhen policePressure spikes inside a specific region, the AI Director directly penalizes local scoring metrics:
The Suppression Shift: If policePressure > 60, any interactive street scenario (Layer 2) for that organization in that specific region suffers an immediate, flat $-30$ deduction to its baseline scoring weight.
The Operational Relocation: High localized pressure forces the organization to route transport logistics (Logistics.md) away from targeted zones, shifting statistical supply routes to adjacent, lower-pressure regions.

3.3 Memory Decay: Organization memory fields decay naturally over real-world time via the scheduler tick, returning to a standard baseline if left un-triggered:
Pressurenew = pressurecurrent X e^-xt
Where x represents a structural configuration decay factor, and t represents elapsed server time

4. Police Intelligence (The Investigation Graph)
Police Intelligence is a non-linear, cumulative value mapping from 0 to 100 that measures law enforcement's structural exposure of an organization. This metric is held by the state engine and explicitly unlocked via player-police actions.

4.1 Compounding Thresholds Matrix
As police characters accumulate evidence, complete arrests, or perform surveillance, the intelligence score shifts, unlocking persistent data vectors to the department:

Intelligence Score
>25 Known Aliases & Vehicles: Generic Lookouts map to specific named suspects or vehicle plates in dispatch text : Minor Heat multipliers applied to regional transport scoring weights
>50 Safehouse Detection : Active safehouses within the target region register as permanent markers on investigative cad menus : shifting to an under investigation state becomes an active transition threat.
>75 Supply Network Mapping: Wholesale transit operations, production facillities and distribution hubs are exposed : enabled the unlocking of high-tier raid scenarios by the event director
100 Structural Compromise: the exact command hierarchy tree (Boss to lieutenants) is fully unmasked : Organization state forced to under Investigation. core morale parameters decay daily by 10%

4.2 The Intelligence Tug-of-War (Decay vs Accumulation)
Plaintext
    [ Player Actions ]                          [ Faction Countermeasures ]
    • Evidence Processing                       • Intimidating Witnesses
    • Suspect Interrogations  ───┐        ┌───  • Relocating Assets / Hubs
    • Asset Interdictions        │        │     • Forensic Cleaning / Opsec
                                 ▼        ▼
                        ┌──────────────────────────┐
                        │    Police Intelligence   │
                        │    (Dynamic Scalar)      │
                        └──────────────────────────┘

Accumulation Drivers: Processing physical items (ballistics, prints), conducting forensic analysis on vehicles, and locking in successful convictions appends floating numbers directly to the faction's intelligence meter.

Countermeasure Mitigation: Organizations can actively push back. If an organization has a high personality.planning metric, they execute clean-up protocols. Executing silent front business operations, destroying compromised assets, or intimidating civilian witnesses forces the intelligence value to steadily bleed down.

5. Emitted Events
The Memory & Intelligence system handles telemetry outputs via the core EventBus:

intelligence:police:floors_crossed — { organizationId, currentScore, unlockedTier }

intelligence:faction:memory_spiked — { organizationId, regionId, metricType, updatedValue }

intelligence:countermeasure:executed — { organizationId, countermeasureType, reductionValue }

6. What This Document Does Not Cover
The foundational structures and item fields of physical scene evidence → docs/11_Evidence/Evidence.md

The tracking layout of search warrants and grand jury filings → docs/12_Investigations/Warrants.md

The functional coordination of money laundering channels → docs/07_Economy/Laundering.md