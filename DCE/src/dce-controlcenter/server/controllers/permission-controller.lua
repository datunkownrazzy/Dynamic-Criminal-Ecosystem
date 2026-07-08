-- DCE Control Center v2 - Permission Controller
-- Handles permission checks and role-based access

local PermissionController = {}
local logger
local DCE = _G.DCE

--- Initialize
function PermissionController.Init(log)
    logger = log
end

--- Log helper
local function log(level, msg, ...)
    if logger then
        logger.Log("permission-controller", level, msg, ...)
    end
end

--- Check permission for a player
---@param source number
---@param permission string
---@return boolean
function PermissionController.Check(source, permission)
    if not source or not permission then
        return false
    end
    
    -- Check if DCE service is available for permission check
    local ControlCenter = DCE and DCE.GetService and DCE.GetService("ControlCenter")
    if ControlCenter and ControlCenter.HasPermission then
        -- Map permissions to roles
        if permission == "admin" or permission == "access_controlcenter" then
            return ControlCenter.HasPermission(source)
        end
    end
    
    -- Fallback to ACE checks
    if IsPlayerAceAllowed then
        local roles = (_G.Config and _G.Config.CC and _G.Config.CC.Permissions and _G.Config.CC.Permissions.Roles) or {}
        
        -- Check if permission exists in roles
        for role, perms in pairs(roles) do
            for _, perm in ipairs(perms) do
                if perm == permission and IsPlayerAceAllowed(source, perm) then
                    return true
                end
            end
        end
        
        -- Direct ACE check
        if IsPlayerAceAllowed(source, permission) then
            return true
        end
    end
    
    return false
end

--- Get player roles
---@param source number
---@return table
function PermissionController.GetRoles(source)
    local roles = {}
    local roleMap = (_G.Config and _G.Config.CC and _G.Config.CC.Permissions and _G.Config.CC.Permissions.Roles) or {}
    
    for role, perms in pairs(roleMap) do
        for _, perm in ipairs(perms) do
            if IsPlayerAceAllowed(source, perm) then
                table.insert(roles, role)
                break
            end
        end
    end
    
    return roles
end

return PermissionController