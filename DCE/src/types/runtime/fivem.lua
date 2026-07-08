-- DCE FiveM Runtime Type Declarations
-- This file contains ONLY type declarations for FiveM natives actually used by DCE.
-- No runtime logic, no business logic.
-- This is the SINGLE authoritative source for FiveM type declarations.

---@class vector2
---@field [1] number x
---@field [2] number y

---@class vector3
---@field [1] number x
---@field [2] number y
---@field [3] number z

---@class vector4
---@field [1] number x
---@field [2] number y
---@field [3] number z
---@field [4] number w

---@class FiveMRuntime
---@field RegisterCommand fun(name:string, handler:fun(source:number, args:string[], rawCommand:string), restricted?:boolean):nil
---@field RegisterKeyMapping fun(commandName:string, description:string, category:string, key:string):nil
---@field RegisterNUICallback fun(name:string, handler:fun(data:table, cb:fun(response:table)):nil)
---@field RegisterNetEvent fun(eventName:string):nil
---@field AddEventHandler fun(eventName:string, handler:fun(...:any)):nil
---@field TriggerEvent fun(eventName:string, ...:any):nil
---@field RemoveEventHandler fun(eventName:string, handler:fun(...:any)):nil
---@field TriggerServerEvent fun(eventName:string, ...:any):nil
---@field TriggerClientEvent fun(eventName:string, target:number|string|string[], ...:any):nil
---@field SendNUIMessage fun(data:table):nil
---@field SetNuiFocus fun(...:boolean):nil
---@field SetNuiFocusKeepInput fun(keepInput:boolean):nil
---@field GetPlayerPed fun(playerId:number):number
---@field PlayerPedId fun():number
---@field GetEntityCoords fun(entity:number):vector3
---@field GetEntityHeading fun(entity:number):number
---@field GetPlayers fun():number[]
---@field IsPlayerAceAllowed fun(playerId:number, ace:string):boolean
---@field GetResourceState fun(resourceName:string):"missing"|"started"|"starting"|"stopped"
---@field GetCurrentResourceName fun():string
---@field LoadResourceFile fun(resourceName:string, file:string):string|nil

---@class ResourceEnvironment
---@field source number The current resource name (available in server scripts)

---@class JSON
---@field encode fun(value:any):string|nil
---@field decode fun(jsonString:string):any

---@class ExportsTable
---@field [string] fun(...:any):any

-- Runtime globals (declared here, also in .luarc.json diagnostics.globals for LuaLS discovery)
---@type vector3
vector3 = nil

---@type vector4
vector4 = nil

---@type fun(name:string, handler:fun(source:number, args:string[], rawCommand:string), restricted?:boolean):nil
RegisterCommand = nil

---@type fun(commandName:string, description:string, category:string, key:string):nil
RegisterKeyMapping = nil

---@type fun(name:string, handler:fun(data:table, cb:fun(response:table)):nil)
RegisterNUICallback = nil

---@type fun(eventName:string):nil
RegisterNetEvent = nil

---@type fun(eventName:string, handler:fun(...:any)):nil
AddEventHandler = nil

---@type fun(eventName:string, ...:any):nil
TriggerEvent = nil

---@type fun(eventName:string, ...:any):nil
TriggerServerEvent = nil

---@type fun(eventName:string, target:number|string|string[], ...:any):nil
TriggerClientEvent = nil

---@type fun(data:table):nil
SendNUIMessage = nil

---@type fun(...:boolean):nil
SetNuiFocus = nil

---@type fun(keepInput:boolean):nil
SetNuiFocusKeepInput = nil

---@type fun(playerId:number):number
GetPlayerPed = nil

---@type fun():number
PlayerPedId = nil

---@type fun(entity:number):vector3
GetEntityCoords = nil

---@type fun(entity:number):number
GetEntityHeading = nil

---@type fun():number[]
GetPlayers = nil

---@type fun(playerId:number, ace:string):boolean
IsPlayerAceAllowed = nil

---@type fun(resourceName:string):"missing"|"started"|"starting"|"stopped"
GetResourceState = nil

---@type fun():string
GetCurrentResourceName = nil

---@type fun(resourceName:string, file:string):string|nil
LoadResourceFile = nil

---@type fun():number
GetGameTimer = nil

---@type JSON
json = nil

---@type number
source = nil

---@type ExportsTable
exports = nil