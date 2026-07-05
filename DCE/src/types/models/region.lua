-- DCE Region Model Type Declarations
-- This file contains ONLY type declarations for the Region model.
-- No runtime logic, no business logic.

--- @class RegionCoordinates
--- Region coordinate system (vector3).
---@field x number X coordinate
---@field y number Y coordinate
---@field z number Z coordinate

--- @class RegionBounds
--- Region boundary definition.
---@field type "circle"|"polygon" Boundary type
---@field center vector3 Center point
---@field radius number|nil Circle radius
---@field points vector3[]|nil Polygon vertices

--- @class RegionStaticValues
--- Region static values (base statistical values).
---@field civilianDensity number Base civilian density 0-100
---@field economicHealth number Base economic health 0-100
---@field policeBaseline number Base police presence 0-100