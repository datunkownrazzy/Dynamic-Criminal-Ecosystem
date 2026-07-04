-- DCE Default Organization Definitions
-- Data-driven organization definitions. Adding a new organization requires only a new entry here.
-- Spec: docs/05_Organizations/Organizations.md

local Organizations = {}

Organizations["families"] = {
    id = "families",
    displayName = "Families",
    personality = {
        violence = 40,
        drugTrade = 70,
        extortion = 30,
        smuggling = 20,
        recruitment = 75,
        territorial = 85,
        planning = 50,
    },
    startingResources = {
        money = 15000,
        members = 20,
        vehicles = { "declasse_voodoo", "declasse_premier" },
    },
}

-- Additional organizations can be added below for the full vertical slice.
-- For the initial vertical slice, one organization is sufficient.

_G.DCEOrganizations = Organizations
