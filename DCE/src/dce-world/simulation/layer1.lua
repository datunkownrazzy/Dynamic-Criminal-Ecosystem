-- DCE Layer 1 Ambient Materialization
-- Handles player-proximity-based promotion/demotion between Layer 0 and Layer 1.
-- Owned by dce-world per Simulation_Layers.md

local Layer1 = {}
local promotedRegions = {}  -- regionId -> { lastPlayerCheck, ambientActive }
local lastTickTime = {}

--- Execute a Layer 1 tick: check player proximity and promote/demote regions.
---@param regions table All region instances keyed by ID
---@return table promotions List of { regionId, fromLayer, toLayer } for regions that changed
function Layer1.Tick(regions)
    local now = os.time()
    local deltaTime = 3 -- default: assume 3 seconds
    local lastTick = lastTickTime["layer1"]
    if lastTick then
        deltaTime = now - lastTick
    end
    lastTickTime["layer1"] = now

    local promotions = {}
    local players = GetPlayers()

    for regionId, region in pairs(regions) do
        local currentLayer = region:GetLayer()
        local hasNearbyPlayer = false

        -- Check if any player is near this region
        if #players > 0 then
            for _, playerId in ipairs(players) do
                local ped = GetPlayerPed(playerId)
                if ped and ped ~= 0 then
                    local playerCoords = GetEntityCoords(ped)
                    local distanceToCenter = #(playerCoords - region.bounds.center)
                    if distanceToCenter <= Config.World.AmbientRadius then
                        hasNearbyPlayer = true
                        break
                    end
                end
            end
        end

        if currentLayer == 0 and hasNearbyPlayer then
            -- Promote: Layer 0 -> Layer 1
            if region:SetLayer(1) then
                table.insert(promotions, {
                    regionId = regionId,
                    fromLayer = 0,
                    toLayer = 1,
                })
                DCE:Log("world", "info", "Layer promotion: %s 0 -> 1 (player nearby)", regionId)
            end

        elseif currentLayer == 1 and not hasNearbyPlayer then
            -- Check if ambient should linger before demoting
            local promoted = promotedRegions[regionId]
            if not promoted then
                promotedRegions[regionId] = { lastPlayerCheck = now, ambientActive = true }
            else
                local timeSinceLastPlayer = now - promoted.lastPlayerCheck
                local lingerMs = Config.World.AmbientLingerTime / 1000

                if timeSinceLastPlayer >= lingerMs then
                    -- Demote: Layer 1 -> Layer 0
                    if region:SetLayer(0) then
                        table.insert(promotions, {
                            regionId = regionId,
                            fromLayer = 1,
                            toLayer = 0,
                        })
                        promotedRegions[regionId] = nil
                        DCE:Log("world", "info", "Layer demotion: %s 1 -> 0 (no players nearby)", regionId)
                    end
                end
            end
        elseif hasNearbyPlayer then
            -- Player is still nearby, update the last check time
            if promotedRegions[regionId] then
                promotedRegions[regionId].lastPlayerCheck = now
            end
        end
    end

    return promotions
end

--- Check if a specific region currently has ambient materialization active.
---@param regionId string
---@return boolean
function Layer1.IsRegionActive(regionId)
    return promotedRegions[regionId] ~= nil
end

--- Get all currently active (Layer 1) regions.
---@return table Array of region IDs
function Layer1.GetActiveRegions()
    local active = {}
    for regionId, _ in pairs(promotedRegions) do
        table.insert(active, regionId)
    end
    return active
end

--- Clear all promotion states. Called during shutdown.
function Layer1.Clear()
    for regionId, _ in pairs(promotedRegions) do
        promotedRegions[regionId] = nil
    end
end

return Layer1