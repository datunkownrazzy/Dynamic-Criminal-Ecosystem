-- DCE Default Region Definitions
-- Data-driven region definitions. Adding a new region requires only a new entry here.
-- Spec: docs/04_Simulation/Regions.md

local Regions = {}

Regions["davis"] = {
    id = "davis",
    displayName = "Davis",
    bounds = {
        type = "circle",
        center = vector3(134.0, -1976.0, 20.0),
        radius = 500.0,
    },
    baseValues = {
        civilianDensity = 65,
        economicHealth = 30,
        policeBaseline = 20,
    },
    adjacentRegions = { "strawberry", "south_los_santos" },
}

-- Additional regions can be added below for the full vertical slice.
-- For the initial vertical slice, one region is sufficient.

_G.DCERegions = Regions
