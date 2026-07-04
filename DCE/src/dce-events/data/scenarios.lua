-- DCE Default Scenario Definitions
-- Data-driven scenario definitions.

local Scenarios = {}

Scenarios["drug_sale"] = {
    type = "drug_sale",
    displayName = "Drug Sale",
    stages = { "Planning", "Travel", "Preparation", "Execution", "Reaction", "Escape", "Resolution" },
    dispatchTriggerStage = "Execution",
    heatOutput = 10,
    violenceOutput = 5,
    evidenceOutput = 1,
}

_G.DCEScenarios = Scenarios
