-- DCE Layer 1 Ambient Materialization
-- Handles player-proximity-based promotion/demotion between Layer 0 and Layer 1.
-- Owned by dce-world per Simulation_Layers.md

local Layer1 = {}
local promotedRegions = {}  -- regionId -> { lastPlayerCheck, ambientActive }
local lastTickTime = {}

--- Get Config safely
local function getConfig()
    return _G.Config or {}
end

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
    
    -- Get players safely (FiveM server-side native)
    local players = {}
    local success, result = pcall(function()
        return GetPlayers()
    end)
    if success and result then
        players = result
    end

    for regionId, region in pairs(regions) do
        local currentLayer = region:GetLayer()
        local hasNearbyPlayer = false

        -- Check if any player is near this region
        if #players > 0 and region.bounds and region.bounds.center then
            for _, playerId in ipairs(players) do
                local pedSuccess, ped = pcall(function()
                    return GetPlayerPed(playerId)
                end)
                if pedSuccess and ped and ped ~= 0 then
                    local coordsSuccess, playerCoords = pcall(function()
                        return GetEntityCoords(ped)
                    end)
                    if coordsSuccess and playerCoords then
                        local Config = getConfig()
                        local radius = Config.World and Config.World.AmbientRadius or 150.0
                        local distanceToCenter = #(playerCoords - region.bounds.center)
                        if distanceToCenter <= radius then
                            hasNearbyPlayer = true
                            break
                        end
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
                DCE.Log("world", "info", "Layer promotion: %s 0 -> 1 (player nearby)", regionId)
            end

        elseif currentLayer == 1 and not hasNearbyPlayer then
            -- Check if ambient should linger before demoting
            local promoted = promotedRegions[regionId]
            if not promoted then
                promotedRegions[regionId] = { lastPlayerCheck = now, ambientActive = true }
            else
                local timeSinceLastPlayer = now - promoted.lastPlayerCheck
                local Config = getConfig()
                local lingerSeconds = 30  -- default
                if Config.World and Config.World.AmbientLingerTime then
                    lingerSeconds = Config.World.AmbientLingerTime / 1000
                end

                if timeSinceLastPlayer >= lingerSeconds then
                    -- Demote: Layer 1 -> Layer 0
                    if region:SetLayer(0) then
                        table.insert(promotions, {
                            regionId = regionId,
                            fromLayer = 1,
                            toLayer = 0,
                        })
                        promotedRegions[regionId] = nil
                        DCE.Log("world", "info", "Layer demotion: %s 1 -> 0 (no players nearby)", regionId)
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

_G.DCELayer1 = Layer1