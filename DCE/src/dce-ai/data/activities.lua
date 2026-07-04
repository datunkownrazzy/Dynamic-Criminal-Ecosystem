-- DCE Default Activity Definitions
-- Data-driven activity definitions. Adding a new activity requires only a new entry here.

local Activities = {}

Activities["drug_sale"] = {
    id = "drug_sale",
    displayName = "Drug Sale",
    type = "narcotics",
    baseWeight = 50,
    minHeat = 0,
    maxHeat = 60,
    minMembers = 2,
    durationMinutes = 15,
    heatOutput = 10,
    violenceOutput = 5,
    moneyOutput = 5000,
    personalityAffinities = {
        drugTrade = 1.5,   -- orgs with high drugTrade get a 1.5x multiplier
        violence = 0.5,    -- violence affinity has less impact on drug sales
    },
    forbiddenStates = { "Suppressed", "Dormant" },
}

-- Additional activities can be added below for the full vertical slice.
-- For the initial vertical slice, one activity is sufficient.

_G.DCEActivities = Activities
