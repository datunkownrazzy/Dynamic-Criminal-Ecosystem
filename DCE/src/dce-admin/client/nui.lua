-- DCE Admin NUI Client
-- Handles NUI display and user interaction

-- ============================================================================
-- NUI Control
-- ============================================================================

local hasFocus = false

--- Set focus to NUI
local function SetNUICFocus(hasFocusValue)
    if SetNuiFocus then
        SetNuiFocus(hasFocusValue, hasFocusValue)
    end
end

--- Open admin dashboard
RegisterNetEvent('dce-admin:client:openDashboard')
AddEventHandler('dce-admin:client:openDashboard', function()
    if not hasFocus then
        hasFocus = true
        SetNUICFocus(true)
        if SendNUIMessage then
            SendNUIMessage({
                action = 'open',
            })
        end
    end
end)

--- Close admin dashboard
RegisterNetEvent('dce-admin:client:closeDashboard')
AddEventHandler('dce-admin:client:closeDashboard', function()
    hasFocus = false
    SetNUICFocus(false)
end)

--- Handle NUI callback from JS
---@param data table
---@param cb fun(response:table)
RegisterNUICallback('close', function(data, cb)
    hasFocus = false
    SetNUICFocus(false)
    cb({})
end)

--- Handle data requests from JS
RegisterNUICallback('getDashboardData', function(data, cb)
    TriggerServerEvent('dce-admin:server:getDashboardData')
    cb({})
end)

RegisterNUICallback('getOrganizations', function(data, cb)
    TriggerServerEvent('dce-admin:server:getOrganizations')
    cb({})
end)

RegisterNUICallback('getIncidents', function(data, cb)
    TriggerServerEvent('dce-admin:server:getIncidents')
    cb({})
end)

RegisterNUICallback('getServices', function(data, cb)
    TriggerServerEvent('dce-admin:server:getServices')
    cb({})
end)

RegisterNUICallback('getTasks', function(data, cb)
    TriggerServerEvent('dce-admin:server:getTasks')
    cb({})
end)

RegisterNUICallback('getEvents', function(data, cb)
    TriggerServerEvent('dce-admin:server:getEvents')
    cb({})
end)

RegisterNUICallback('getDebugHistory', function(data, cb)
    TriggerServerEvent('dce-admin:server:getDebugHistory')
    cb({})
end)

RegisterNUICallback('getAuditLog', function(data, cb)
    TriggerServerEvent('dce-admin:server:getAuditLog')
    cb({})
end)

RegisterNUICallback('executeDebug', function(data, cb)
    TriggerServerEvent('dce-admin:server:executeDebug', data.command, data.args)
    cb({})
end)