local playerTokens     = {}
local lastTokenRequest = {}
local TOKEN_EXPIRY     = 3600

local function generateToken()
    local chars  = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result = {}
    for i = 1, 64 do
        result[i] = chars:sub(math.random(1, #chars), math.random(1, #chars))
    end
    return table.concat(result) .. tostring(os.time())
end

local function issueToken(src)
    local token = generateToken()
    playerTokens[src] = { token = token, issuedAt = os.time() }
    TriggerClientEvent('fr_compmachine:receiveToken', src, token)
end

local function handleCheatDetection(src, reason)
    if not src or not GetPlayerName(src) then return end
    print(('[fr_compmachine][Anti-Cheat] %s (ID:%d) — %s'):format(GetPlayerName(src), src, reason))
    DropPlayer(src, '[Anti-Cheat] Suspicious action detected.')
end

local function validateToken(src, clientToken)
    local record = playerTokens[src]
    if not record then
        handleCheatDetection(src, 'No token on file — possible event spoofing')
        return false
    end
    if (os.time() - record.issuedAt) > TOKEN_EXPIRY then
        playerTokens[src] = nil
        handleCheatDetection(src, 'Token expired — possible replay attack')
        return false
    end
    if record.token ~= clientToken then
        handleCheatDetection(src, 'Token mismatch — possible event spoofing')
        return false
    end
    playerTokens[src] = nil
    issueToken(src)
    return true
end

RegisterNetEvent('fr_compmachine:requestToken', function()
    local src = tonumber(source) or 0
    if src <= 0 then return end
    local now = os.time()
    if lastTokenRequest[src] and (now - lastTokenRequest[src]) < 5 then return end
    lastTokenRequest[src] = now
    issueToken(src)
end)

AddEventHandler('playerDropped', function()
    local src = tonumber(source) or 0
    playerTokens[src]     = nil
    lastTokenRequest[src] = nil
end)

local discordWebhookURL   = LogsConfig.discordWebhook
local compensationStorage = {}
local lastRedeem          = {}

math.randomseed(os.time())

local function generateCode(length)
    local charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local code    = ''
    for i = 1, length do
        local idx = math.random(1, #charset)
        code = code .. charset:sub(idx, idx)
    end
    return code
end

local function loadCompensationCodes()
    local ok = pcall(function()
        local results = exports.oxmysql:executeSync('SELECT code, items FROM compensation_codes', {})
        if results and #results > 0 then
            for _, row in ipairs(results) do
                compensationStorage[row.code] = json.decode(row.items)
            end
        end
    end)
end

local function sendDiscordLog(str)
    if discordWebhookURL == '' then return end
    PerformHttpRequest(discordWebhookURL, function() end, 'POST', json.encode({
        username = 'Comp System',
        embeds   = {{
            title       = 'Compensation Log',
            description = str,
            color       = 3447003,
            timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        }}
    }), { ['Content-Type'] = 'application/json' })
end

lib.addCommand('comp', {
    help       = 'Open compensation builder UI',
    restricted = 'group.admin',
}, function(source)
    TriggerClientEvent('comp_ui:openAdmin', source)
end)

RegisterNetEvent('fr_compmachine:store_compensation', function(clientToken, items)
    local src = tonumber(source) or 0
    if src <= 0 then return end
    if not validateToken(src, clientToken) then return end
    if type(items) ~= 'table' then return end

    local validItems = {}
    for _, item in ipairs(items) do
        local amount = tonumber(item.amount)
        if type(item.item) == 'string' and #item.item > 0
            and amount and amount > 0 and amount <= 1000000 then
            validItems[#validItems + 1] = { item = item.item, amount = math.floor(amount) }
        end
    end
    if #validItems == 0 then return end

    local code       = generateCode(10)
    local playerName = GetPlayerName(src)
    local labelParts = {}
    for _, item in ipairs(validItems) do
        labelParts[#labelParts + 1] = item.item .. ' x' .. item.amount
    end
    local itemsString = table.concat(labelParts, ', ')

    pcall(function()
        exports.oxmysql:insert('INSERT INTO compensation_codes (code, items) VALUES (?, ?)', {
            code, json.encode(validItems)
        }, function(insertedId)
            if insertedId then
                compensationStorage[code] = validItems
                TriggerClientEvent('comp_ui:copyCode', src, code)
                TriggerClientEvent('ox_lib:notify', src, {
                    title       = 'Comp Created',
                    description = 'Code: ' .. code .. ' — copied to clipboard',
                    type        = 'success',
                    duration    = 6000,
                })
                sendDiscordLog(('**Comp Registered By:** `%s` (ID: `%d`)\n**Code:** `%s`\n**Items:** `%s`'):format(
                    playerName, src, code, itemsString
                ))
            else
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Error', description = 'Failed to save the code.', type = 'error'
                })
            end
        end)
    end)
end)

RegisterNetEvent('redeem_compensation_code', function(code)
    local src = tonumber(source) or 0
    if src <= 0 then return end

    local now = os.time()
    if lastRedeem[src] and (now - lastRedeem[src]) < 3 then return end
    lastRedeem[src] = now

    local playerName = GetPlayerName(src)

    if not compensationStorage[code] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error', description = 'Invalid or already redeemed code.', type = 'error'
        })
        TriggerClientEvent('comp_ui:notify', src, 'Invalid or already redeemed code.', 'error')
        return
    end

    local items = compensationStorage[code]
    compensationStorage[code] = nil
    exports.oxmysql:execute('DELETE FROM compensation_codes WHERE code = ?', { code })

    local moneyTypes = { cash = true, bank = true, crypto = true }
    local labelParts = {}
    for _, item in ipairs(items) do
        local name = item.item:lower()
        local success = false

        if moneyTypes[name] then
            local moneyType = name == 'money' and 'cash' or name
            local player = exports.qbx_core:GetPlayer(src)
            if player then
                success = player.Functions.AddMoney(moneyType, item.amount, 'compensation')
            end
        else
            success = exports.ox_inventory:AddItem(src, item.item, item.amount)
        end

        if success then
            labelParts[#labelParts + 1] = item.item .. ' x' .. item.amount
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error', description = 'Failed to give: ' .. item.item, type = 'error'
            })
            TriggerClientEvent('comp_ui:notify', src, 'Failed to give: ' .. item.item, 'error')
            return
        end
    end

    local itemsString = table.concat(labelParts, ', ')

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Redeemed!', description = 'Items given: ' .. itemsString,
        type = 'success', duration = 6000,
    })
    TriggerClientEvent('comp_ui:notify', src, 'Items redeemed! ' .. itemsString, 'success')

    Citizen.SetTimeout(1800, function()
        TriggerClientEvent('comp_ui:close', src)
    end)

    sendDiscordLog(('**Comp Claimed By:** `%s` (ID: `%d`)\n**Code:** `%s`\n**Items:** `%s`'):format(
        playerName, src, code, itemsString
    ))
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    loadCompensationCodes()
    print('^2[fr_compmachine]^7 Resource started.')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    compensationStorage = {}
    playerTokens        = {}
end)
