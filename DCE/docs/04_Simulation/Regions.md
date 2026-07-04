# DCE Regions

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** World Engine, Simulation Layers, Configuration Philosophy

---

## Purpose

This document defines the Region data structure — the spatial/data unit the World Engine simulates. "Territory" (as used in earlier design conversations and in Organization-facing docs) refers to *ownership and control* of a Region by an Organization; "Region" is the underlying spatial container that ownership applies to. This distinction matters because a Region continues to exist, and continues being simulated, independent of whether any Organization currently controls it.

---

## Region Definition

A Region is a data-defined spatial area (polygon or radius-based, implementation detail left to `dce-world`'s internals) with an associated data file under `/schemas/regions/`:

```json
{
  "id": "davis",
  "displayName": "Davis",
  "bounds": { "type": "polygon", "points": [ /* ... */ ] },
  "baseValues": {
    "civilianDensity": 65,
    "economicHealth": 30,
    "policeBaseline": 20
  },
  "adjacentRegions": ["strawberry", "south_los_santos"]
}
```

Regions are **data, not code** (per `Configuration_Philosophy.md`'s config-vs-data distinction) — adding a new Region should never require a code change, only a new data file plus, if using it in gameplay, an entry referenced by whatever Organization/Territory data claims it.

---

## Tracked Runtime State

Distinct from the static `baseValues` above (which describe what a Region tends toward absent other influence), each Region has runtime state maintained by `dce-world`:

| Field | Meaning |
|---|---|
| `policePresence` | Current police activity level, drifts toward `baseValues.policeBaseline` absent active patrol assignment |
| `civilianDensity` | Current estimated civilian traffic, varies by time of day |
| `gangInfluence` | Per-organization influence values (a Region can have multiple organizations with nonzero influence simultaneously — see Contested state) |
| `economicHealth` | Slow-moving; affected by sustained crime/violence over time |
| `heat` | Current attention level (see `Glossary.md` — single scalar for v1.0, per `Goals.md`) |
| `violence` | Recent violent-incident frequency, decays over time |
| `layer` | Current ambient simulation layer (0 or 1) for this Region — see `Simulation_Layers.md` |

Runtime state is what `World.GetRegionState(regionId)` (referenced in `World_Engine.md`) returns — the static `baseValues` are the "resting point" the runtime state drifts toward absent other pressure, not what's returned to consumers directly.

---

## Territory Lifecycle (Ownership Layer)

While a Region is the spatial container, **Territory** status is the ownership/control state layered on top, owned conceptually by `dce-ai`/`dce-territories` rather than `dce-world` (a Region can exist and be simulated even with no owning Organization — e.g., early game state, or a recently-cleared area):

```
Neutral → Claimed → Developed → Prosperous → Contested → Violent → Police Crackdown → Recovered
```

This lifecycle and its transition conditions belong in a future `dce-territories` specification; it's noted here only to make the Region/Territory distinction explicit and avoid the two concepts being conflated in implementation.

---

## Adjacency

`adjacentRegions` exists because several planned mechanics depend on knowing which Regions border each other — a gang war spilling into a neighboring Region, a pursuit crossing Region boundaries, or influence "bleeding" into adjacent Regions from a strongly controlled one. v1.0 does not need to implement all of these, but the adjacency data should be present from the start, since retrofitting spatial adjacency data after content already exists is far more tedious than including it in the initial schema.

---

## Region Size Guidance

Regions should be sized so that:
- Layer 0 statistical simulation per Region stays cheap (a Region is a bundle of a dozen or so numbers, not something requiring spatial queries every tick).
- A player can meaningfully perceive being "in" one Region vs. another (matches the mental model of a named neighborhood/district, not an arbitrary grid cell).

This is content-design guidance, not a hard technical constraint — but building the very first Region data files at a wildly inconsistent granularity (one giant Region covering half the map next to a dozen tiny ones) will make Layer 0 tuning and player-facing consistency harder later. Worth establishing a rough target Region count/size early and noting it in `/schemas/regions/README.md` when that's written.

---

## API Surface (World Engine)

```lua
World.GetRegionState(regionId) -> { policePresence, civilianDensity, gangInfluence, economicHealth, heat, violence, layer, ... }
World.GetAdjacentRegions(regionId) -> { regionId, ... }
World.GetAllRegionIds() -> { regionId, ... }
World.GetRegionAtCoords(coords) -> regionId | nil
```

Territory ownership queries (`GetTerritoryOwner(regionId)`, etc.) belong to the future `dce-territories` Service, not the World Engine — consistent with the Region/Territory separation above.
