local clientToken            = nil
local tokenReady             = false
local pendingCalls           = {}
local tokenRequested         = false
local tokenRequestGeneration = 0

local function beginTokenRequest()
    tokenRequestGeneration = tokenRequestGeneration + 1
    local gen = tokenRequestGeneration
    tokenRequested = true
    TriggerServerEvent('fr_compmachine:requestToken')
    SetTimeout(10000, function()
        if gen == tokenRequestGeneration and clientToken == nil then
            tokenRequested = false
        end
    end)
end

RegisterNetEvent('fr_compmachine:receiveToken', function(token)
    clientToken    = token
    tokenReady     = true
    tokenRequested = false

    if #pendingCalls > 0 then
        local call = table.remove(pendingCalls, 1)
        local t    = clientToken
        clientToken = nil
        tokenReady  = false
        TriggerServerEvent(call.eventName, t, table.unpack(call.args))
        if #pendingCalls > 0 then beginTokenRequest() end
    end
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(200) end
    Wait(500)
    beginTokenRequest()
end)

local function triggerServer(eventName, ...)
    local args = { ... }
    if tokenReady and clientToken then
        local t    = clientToken
        clientToken = nil
        tokenReady  = false
        TriggerServerEvent(eventName, t, table.unpack(args))
    else
        pendingCalls[#pendingCalls + 1] = { eventName = eventName, args = args }
        if not tokenRequested then beginTokenRequest() end
    end
end

local nuiOpen = false

RegisterNUICallback('submitComp', function(data, cb)
    if not data.items or #data.items == 0 then cb('ok') return end
    triggerServer('fr_compmachine:store_compensation', data.items)
    cb('ok')
end)

RegisterNUICallback('redeemCode', function(data, cb)
    if data.code and #data.code == 10 then
        TriggerServerEvent('redeem_compensation_code', data.code)
    end
    cb('ok')
end)

RegisterNUICallback('closeUI', function(_, cb)
    SetNuiFocus(false, false)
    nuiOpen = false
    cb('ok')
end)

RegisterNetEvent('comp_ui:openAdmin', function()
    SetNuiFocus(true, true)
    nuiOpen = true
    SendNUIMessage({ type = 'openAdmin' })
end)

RegisterNetEvent('comp_ui:openRedeem', function()
    SetNuiFocus(true, true)
    nuiOpen = true
    SendNUIMessage({ type = 'openRedeem' })
end)

RegisterNetEvent('comp_ui:notify', function(message, style)
    if nuiOpen then
        SendNUIMessage({ type = 'notify', message = message, style = style })
    end
end)

RegisterNetEvent('comp_ui:copyCode', function(code)
    lib.setClipboard(tostring(code))
    SendNUIMessage({ type = 'submitSuccess', code = code })
end)

local props = {
    { coords = Config.compPropLocation, model = Config.prop }
}

local function registerPropWithTarget(entity)
    exports.ox_target:addLocalEntity(entity, {
        {
            name     = 'redeem_compensation',
            icon     = 'fas fa-ticket',
            label    = 'Redeem Comp',
            onSelect = function()
                TriggerEvent('comp_ui:openRedeem')
            end
        }
    })
end

local function spawnProp(propData)
    local model = propData.model
    RequestModel(model)
    local elapsed = 0
    while not HasModelLoaded(model) do
        Wait(100)
        elapsed = elapsed + 100
        if elapsed >= 5000 then
            lib.notify({ title = 'Error', description = 'Failed to load model.', type = 'error' })
            return
        end
    end
    if not DoesEntityExist(propData.entity) then
        local prop = CreateObject(model, propData.coords.x, propData.coords.y, propData.coords.z, false, false, false)
        SetEntityHeading(prop, propData.coords.w)
        PlaceObjectOnGroundProperly(prop)
        FreezeEntityPosition(prop, true)
        propData.entity = prop
        registerPropWithTarget(prop)
    end
end

local function ensureProps()
    for _, propData in ipairs(props) do
        if not DoesEntityExist(propData.entity) then spawnProp(propData) end
    end
end

CreateThread(function()
    while true do
        ensureProps()
        Wait(10000)
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Citizen.SetTimeout(1000, ensureProps)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, propData in ipairs(props) do
        if DoesEntityExist(propData.entity) then
            DeleteEntity(propData.entity)
        end
    end
end)

RegisterNetEvent('trigger_compensation_menu', function()
    TriggerEvent('comp_ui:openAdmin')
end)
