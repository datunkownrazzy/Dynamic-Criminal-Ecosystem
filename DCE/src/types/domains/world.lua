-- DCE World Domain Type Declarations
-- This file contains ONLY type declarations for the World simulation domain.
-- No runtime logic, no business logic.

--- @class IRegion
--- Region Model: The spatial/data unit the World Engine simulates.
---@field id string Unique region identifier
---@field displayName string Human-readable region name
---@field bounds table Region boundary definition
---@field adjacentRegions string[] Adjacent region IDs
---@field baseValues table Base statistical values
---@field runtime table Runtime state values
---@field GetState fun(self:IRegion):RegionState
---@field GetLayer fun(self:IRegion):number
---@field SetLayer fun(self:IRegion, layer:number):boolean
---@field DriftTowardBaseline fun(self:IRegion, deltaTime:number):nil
---@field AddHeat fun(self:IRegion, amount:number):nil
---@field AddViolence fun(self:IRegion, amount:number):nil
---@field SetGangInfluence fun(self:IRegion, orgId:string, influence:number):nil
---@field GetDominantOrg fun(self:IRegion):string|nil, number
---@field IsControlledBy fun(self:IRegion, orgId:string, threshold:number):boolean

--- @class IWorldState
--- World State Model: Global time, weather, and synced state.
---@field time table Current time state {hour, minute, day, isNight}
---@field weather table Current weather state {current, previous, lastChange, nextScheduledChange}
---@field UpdateTime fun(self:IWorldState, deltaTime:number):nil
---@field GetTime fun(self:IWorldState):TimeState
---@field GetWeather fun(self:IWorldState):string
---@field SetWeather fun(self:IWorldState, weatherType:string):nil
---@field MaybeChangeWeather fun(self:IWorldState):boolean

--- @class IWorldService
--- World Engine Service: Maintains world state, regions, and layer simulation.
---@field Initialize fun(self:IWorldService):nil
---@field GetRegionState fun(self:IWorldService, regionId:string):RegionState|nil
---@field GetAdjacentRegions fun(self:IWorldService, regionId:string):string[]
---@field GetAllRegionIds fun(self:IWorldService):string[]
---@field GetRegionLayer fun(self:IWorldService, regionId:string):number
---@field GetTime fun(self:IWorldService):TimeState
---@field GetWeather fun(self:IWorldService):string
---@field GetAllRegionStates fun(self:IWorldService):RegionState[]
---@field Layer0Tick fun(self:IWorldService):nil
---@field Layer1Tick fun(self:IWorldService):nil
---@field TimeTick fun(self:IWorldService):nil
---@field WeatherTick fun(self:IWorldService):nil
---@field Shutdown fun(self:IWorldService):nil

--- @class ILayer0
--- Layer 0 Statistical Simulation: Updates statistical values for all regions.
---@field Tick fun(regions:table, worldState:IWorldState):table

--- @class ILayer1
--- Layer 1 Ambient Materialization: Handles player-proximity-based promotion/demotion.
---@field Tick fun(regions:table, worldState:IWorldState):table
---@field IsRegionActive fun(self:ILayer1, regionId:string):boolean
---@field GetActiveRegions fun(self:ILayer1):string[]
---@field Clear fun(self:ILayer1):nil

--- @class TimePriority
--- Time simulation priority enum.
TimePriority = {
    Low = 1,
    Medium = 2,
    High = 3,
}