print('Government MDT Client Started')
local isOpen = false

RegisterNetEvent('gov-mdt:client:sendToNUI', function(data)
    SendNUIMessage(data)
end)

local function openMDT()
    local playerData = exports.qbx_core:GetPlayerData()
    local job = playerData.job
    print('Opening MDT... Current Job:', job.name, 'Required Job:', Config.Job)
    
    if job.name ~= Config.Job then
        lib.notify({ title = 'Access Denied', description = 'Only government employees can access this. Your job: ' .. job.name, type = 'error' })
        return
    end

    if isOpen then return end
    
    local playerData = exports.qbx_core:GetPlayerData()
    local dashboardData = lib.callback.await('gov-mdt:server:getDashboardData', false)
    if not dashboardData then return end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        user = {
            name = dashboardData.user.name,
            job = dashboardData.user.job,
            grade_level = dashboardData.user.grade_level
        },
        dashboard = dashboardData
    })
    isOpen = true
end

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    isOpen = false
    cb('ok')
end)

RegisterNUICallback('searchCitizens', function(data, cb)
    local results = lib.callback.await('gov-mdt:server:searchCitizens', false, data.query)
    SendNUIMessage({
        action = 'updateSearchResults',
        results = results
    })
    cb('ok')
end)

RegisterNUICallback('getCitizenDetails', function(data, cb)
    local citizenData = lib.callback.await('gov-mdt:server:getCitizenData', false, data.citizenid)
    if citizenData then
        SendNUIMessage({
            action = 'updateCitizenProfile',
            profile = {
                citizenid = data.citizenid,
                firstname = citizenData.charinfo.firstname,
                lastname = citizenData.charinfo.lastname,
                birthdate = citizenData.charinfo.birthdate,
                phone = citizenData.charinfo.phone,
                nationality = citizenData.charinfo.nationality,
                job = citizenData.job.label .. ' (' .. (citizenData.job.grade.name or 'N/A') .. ')',
                family_card = citizenData.metadata.family_card,
                family = citizenData.family
            }
        })
    end
    cb('ok')
end)

RegisterNUICallback('saveKK', function(data, cb)
    local success = lib.callback.await('gov-mdt:server:saveFamilyCard', false, data.citizenid, data.kk)
    if success then
        lib.notify({ title = 'Success', description = 'Family Card updated.', type = 'success' })
    end
    cb('ok')
end)

RegisterNUICallback('getMarketItems', function(data, cb)
    lib.callback.await('gov-mdt:server:getMarketItems', false)
    cb('ok')
end)

RegisterNUICallback('updateMarketItem', function(data, cb)
    lib.callback.await('gov-mdt:server:updateMarketItem', false, data.item, data.label, data.price, data.category, data.max_stock, data.sell_price, data.min_buy_price, data.min_stock_percent)
    cb('ok')
end)

RegisterNUICallback('addCategory', function(data, cb)
    lib.callback.await('gov-mdt:server:addCategory', false, data.name, data.label)
    cb('ok')
end)

RegisterNUICallback('removeCategory', function(data, cb)
    lib.callback.await('gov-mdt:server:removeCategory', false, data.id)
    cb('ok')
end)

RegisterNUICallback('removeMarketItem', function(data, cb)
    lib.callback.await('gov-mdt:server:removeMarketItem', false, data.id)
    cb('ok')
end)


-- Announcement Callbacks
RegisterNUICallback('getAnnouncements', function(data, cb)
    local announcements = lib.callback.await('gov-mdt:server:getAnnouncements', false)
    SendNUIMessage({
        action = 'updateAnnouncements',
        data = announcements
    })
    cb(announcements)
end)

RegisterNUICallback('addAnnouncement', function(data, cb)
    local success = lib.callback.await('gov-mdt:server:addAnnouncement', false, data.title, data.message)
    cb(success)
end)

RegisterNUICallback('deleteAnnouncement', function(data, cb)
    local success = lib.callback.await('gov-mdt:server:deleteAnnouncement', false, data.id)
    cb(success)
end)

-- Department Callbacks
RegisterNUICallback('getEmployees', function(data, cb)
    local employees = lib.callback.await('gov-mdt:server:getEmployees', false)
    cb(employees)
end)

RegisterNUICallback('updateEmployeeGrade', function(data, cb)
    local success = lib.callback.await('gov-mdt:server:updateEmployeeGrade', false, data.citizenid, data.newGrade)
    cb(success)
end)

RegisterNUICallback('fireEmployee', function(data, cb)
    local success = lib.callback.await('gov-mdt:server:fireEmployee', false, data.citizenid)
    cb(success)
end)

RegisterNUICallback('hireEmployee', function(data, cb)
    local success = lib.callback.await('gov-mdt:server:hireEmployee', false, data.citizenid)
    cb(success)
end)

-- License Callback
RegisterNUICallback('getNearbyPlayers', function(data, cb)
    local players = {}
    local coords = GetEntityCoords(cache.ped)
    local nearby = lib.getNearbyPlayers(coords, 5.0) -- 5 meters radius
    
    for i=1, #nearby do
        local targetPed = GetPlayerPed(nearby[i].id)
        local targetServerId = GetPlayerServerId(nearby[i].id)
        local targetPlayer = exports.qbx_core:GetPlayer(targetServerId)
        
        if targetPlayer then
            table.insert(players, {
                name = targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname,
                citizenid = targetPlayer.PlayerData.citizenid
            })
        end
    end
    cb(players)
end)

RegisterNUICallback('updateLicense', function(data, cb)
    local success, message = lib.callback.await('gov-mdt:server:updateLicense', false, data.citizenid, data.licenseType, data.state)
    cb({success = success, message = message})
end)

RegisterNUICallback('getSalesLogs', function(data, cb)
    local logs = lib.callback.await('gov-mdt:server:getSalesLogs', false, data.date)
    cb(logs)
end)

RegisterNUICallback('showDocToNearby', function(data, cb)
    TriggerServerEvent('gov-mdt:server:showDocument', data.id)
    cb('ok')
end)

RegisterNUICallback('getDocuments', function(data, cb)
    local docs = lib.callback.await('gov-mdt:server:getDocuments', false)
    cb(docs)
end)

RegisterNUICallback('addDocument', function(data, cb)
    local success = lib.callback.await('gov-mdt:server:addDocument', false, data.title, data.content)
    cb(success)
end)

RegisterNUICallback('getDocumentById', function(data, cb)
    local doc = lib.callback.await('gov-mdt:server:getDocumentById', false, data.id)
    cb(doc)
end)

RegisterNUICallback('updateDocument', function(data, cb)
    local success = lib.callback.await('gov-mdt:server:updateDocument', false, data.id, data.title, data.content)
    cb(success)
end)

RegisterNUICallback('deleteDocument', function(data, cb)
    TriggerServerEvent('gov-mdt:server:deleteDocument', data.id)
    cb('ok')
end)

RegisterNUICallback('giveDocToNearby', function(data, cb)
    local coords = GetEntityCoords(cache.ped)
    local nearby = lib.getNearbyPlayers(coords, 5.0)
    local options = {
        {
            title = 'Give to Self (Test)',
            description = 'Hand over a physical copy to yourself.',
            icon = 'user',
            onSelect = function()
                TriggerServerEvent('gov-mdt:server:givePhysicalDoc', GetPlayerServerId(PlayerId()), data.id)
            end
        }
    }

    for i=1, #nearby do
        local targetServerId = GetPlayerServerId(nearby[i].id)
        options[#options+1] = {
            title = 'Give to ID: ' .. targetServerId,
            description = 'Hand over a physical copy of this document.',
            icon = 'hand-holding',
            onSelect = function()
                TriggerServerEvent('gov-mdt:server:givePhysicalDoc', targetServerId, data.id)
            end
        }
    end

    lib.registerContext({
        id = 'gov_give_doc_menu',
        title = 'Select Recipient',
        options = options
    })
    lib.showContext('gov_give_doc_menu')
    cb('ok')
end)

-- Event to view document (For people receiving the document or using it)
RegisterNetEvent('gov-mdt:client:viewDocument', function(doc)
    print("[gov-mdt] Receiving viewDocument event for:", doc.title)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'viewDocument',
        doc = doc
    })
end)

RegisterNUICallback('closeViewer', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('openWarehouse', function(data, cb)
    local items = lib.callback.await('gov-mdt:server:getMarketItems', false)
    local options = {}
    
    if items.categories and #items.categories > 0 then
        for i=1, #items.categories do
            options[#options+1] = {
                title = items.categories[i].label .. ' Warehouse',
                description = 'Open stash for ' .. items.categories[i].label .. ' items.',
                icon = 'box-open',
                onSelect = function()
                    SetNuiFocus(false, false)
                    isOpen = false
                    exports.ox_inventory:openInventory('stash', 'gov_stash_' .. items.categories[i].name)
                end
            }
        end
    else
        options[#options+1] = { title = 'No warehouses configured.', disabled = true }
    end

    lib.registerContext({
        id = 'gov_warehouse_menu',
        title = 'Government Warehouses',
        options = options
    })
    lib.showContext('gov_warehouse_menu')
    cb('ok')
end)

-- Function to open market with optional filter
function openGovMarket(filter, mode)
    local data = lib.callback.await('gov-mdt:server:getMarketItems', false)
    local items = data.items
    
    if not items or #items == 0 then
        lib.notify({ title = 'Market', description = 'No items are currently listed in the government market.', type = 'inform' })
        return
    end

    -- Initial Mode Selection
    if not mode then
        lib.registerContext({
            id = 'gov_market_main',
            title = 'Government Market',
            options = {
                {
                    title = 'Sell Items to Government',
                    description = 'Sell your resources for quick cash.',
                    icon = 'hand-holding-dollar',
                    onSelect = function() openGovMarket(nil, 'sell') end
                },
                {
                    title = 'Buy Items from Government',
                    description = 'Purchase resources from government stock.',
                    icon = 'cart-shopping',
                    onSelect = function() openGovMarket(nil, 'buy') end
                }
            }
        })
        lib.showContext('gov_market_main')
        return
    end

    local options = {}

    -- Search Option
    options[#options+1] = {
        title = filter and '❌ Clear Search: "' .. filter .. '"' or '🔍 Search Item...',
        description = filter and 'Show all items' or 'Filter the market list',
        icon = filter and 'xmark' or 'magnifying-glass',
        onSelect = function()
            if filter then
                openGovMarket(nil, mode)
            else
                local search = lib.inputDialog('Market Search', {
                    {type = 'input', label = 'Item Name', icon = 'search'},
                })
                if search and search[1] then
                    openGovMarket(search[1]:lower(), mode)
                end
            end
        end
    }

    for i=1, #items do
        local label = items[i].label:lower()
        local matches = not filter or label:find(filter) or items[i].category:lower():find(filter)

        if matches then
            if mode == 'sell' then
                local current = items[i].current_stock or 0
                local max = items[i].max_stock or 100
                local remaining = max - current
                local isFull = remaining <= 0

                local currentPrice = items[i].price
                if items[i].min_buy_price and items[i].min_buy_price > 0 and items[i].price > items[i].min_buy_price then
                    local stockPercent = current / max
                    local targetPercent = (items[i].min_stock_percent or 80) / 100.0
                    
                    if stockPercent >= targetPercent then
                        currentPrice = items[i].min_buy_price
                    else
                        currentPrice = items[i].price
                    end
                end

                options[#options+1] = {
                    title = items[i].label .. (isFull and ' (OUT OF STOCK)' or ''),
                    description = string.format('[%s] Price: $%d | Quota: %d/%d', items[i].category, currentPrice, current, max),
                    icon = 'hand-holding-dollar',
                    disabled = isFull,
                    progress = (current / max) * 100,
                    colorScheme = isFull and 'red' or 'blue',
                    onSelect = function()
                        local input = lib.inputDialog('Sell ' .. items[i].label, {
                            {type = 'number', label = 'Amount', description = 'Quota remaining: ' .. remaining, icon = 'hashtag', min = 1, max = remaining, default = 1},
                        })
                        if input then
                            local amount = tonumber(input[1])
                            local success, message = lib.callback.await('gov-mdt:server:sellItemToGov', false, items[i], amount)
                            if success then lib.notify({ title = 'Market', description = message, type = 'success' })
                            else lib.notify({ title = 'Market', description = message, type = 'error' }) end
                        end
                    end
                }
            elseif mode == 'buy' then
                local current = items[i].current_stock or 0
                local price = items[i].sell_price or 0
                local isEmpty = current <= 0

                options[#options+1] = {
                    title = items[i].label .. (isEmpty and ' (OUT OF STOCK)' or ''),
                    description = string.format('[%s] Price: $%d | In Stock: %d', items[i].category, price, current),
                    icon = 'cart-shopping',
                    disabled = isEmpty or price <= 0,
                    onSelect = function()
                        local input = lib.inputDialog('Buy ' .. items[i].label, {
                            {type = 'number', label = 'Amount', description = 'Warehouse stock: ' .. current .. ' | Price: $' .. price .. ' each', icon = 'hashtag', min = 1, max = current, default = 1},
                        })
                        if input then
                            local amount = tonumber(input[1])
                            local success, message = lib.callback.await('gov-mdt:server:buyItemFromGov', false, items[i], amount)
                            if success then lib.notify({ title = 'Market', description = message, type = 'success' })
                            else lib.notify({ title = 'Market', description = message, type = 'error' }) end
                        end
                    end
                }
            end
        end
    end

    lib.registerContext({
        id = 'gov_market_list',
        title = (mode == 'buy' and 'Buy from Government' or 'Sell to Government'),
        menu = 'gov_market_main',
        options = options
    })
    lib.showContext('gov_market_list')
end

-- Citizen Market Command
RegisterCommand('govmarket', function()
    openGovMarket(nil)
end)

-- Command
RegisterCommand(Config.Command, function()
    openMDT()
end)

-- NPC & Target System
local govNPC = nil
local npcCoords = vector4(-539.13, -204.47, 37.65, 209.85)
local npcModel = `a_m_m_business_01` -- Changed to a very common business model

CreateThread(function()
    -- Add Blip for Market FIRST so we can see where it is
    local blip = AddBlipForCoord(npcCoords.x, npcCoords.y, npcCoords.z)
    SetBlipSprite(blip, 480) -- Person icon
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 2)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Government Market")
    EndTextCommandSetBlipName(blip)

    print("^2[gov-mdt] Attempting to spawn NPC...")
    
    -- Request Model with Timeout
    RequestModel(npcModel)
    local timeout = 0
    while not HasModelLoaded(npcModel) and timeout < 50 do -- 5 seconds timeout
        Wait(100)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(npcModel) then
        print("^1[gov-mdt] Model failed to load in time. Using fallback...")
        npcModel = `mp_m_freemode_01` -- Fallback to basic male player model
        RequestModel(npcModel)
        while not HasModelLoaded(npcModel) do Wait(10) end
    end
    
    -- Create Ped
    govNPC = CreatePed(4, npcModel, npcCoords.x, npcCoords.y, npcCoords.z - 1.0, npcCoords.w, false, false)
    
    if DoesEntityExist(govNPC) then
        print("^2[gov-mdt] NPC Spawned successfully!")
        SetEntityHeading(govNPC, npcCoords.w)
        FreezeEntityPosition(govNPC, true)
        SetEntityInvincible(govNPC, true)
        SetBlockingOfNonTemporaryEvents(govNPC, true)
        
        -- Animation: Looking at clipboard
        RequestAnimDict("amb@world_human_clipboard@male@idle_a")
        local animTimeout = 0
        while not HasAnimDictLoaded("amb@world_human_clipboard@male@idle_a") and animTimeout < 30 do
            Wait(100)
            animTimeout = animTimeout + 1
        end
        
        if HasAnimDictLoaded("amb@world_human_clipboard@male@idle_a") then
            TaskPlayAnim(govNPC, "amb@world_human_clipboard@male@idle_a", "idle_c", 8.0, 0.0, -1, 1, 0, 0, 0, 0)
        end

        -- Add Ox Target for Service Point
        exports.ox_target:addLocalEntity(govNPC, {
            {
                name = 'gov_market_npc',
                label = 'Talk to Government Clerk',
                icon = 'fa-solid fa-briefcase',
                onSelect = function()
                    openGovMarket(nil, nil)
                end
            }
        })
    else
        print("^1[gov-mdt] Critical error: Could not spawn ped entity!")
    end

    -- NEW: Public Service NPC (Registration)
    local regNPCModel = `a_f_y_business_02`
    local regNPCCoords = vector4(-551.97, -193.22, 38.22 - 1.0, 206.73)
    RequestModel(regNPCModel)
    while not HasModelLoaded(regNPCModel) do Wait(10) end
    
    local regNPC = CreatePed(4, regNPCModel, regNPCCoords.x, regNPCCoords.y, regNPCCoords.z, regNPCCoords.w, false, false)
    SetEntityHeading(regNPC, regNPCCoords.w)
    FreezeEntityPosition(regNPC, true)
    SetEntityInvincible(regNPC, true)
    SetBlockingOfNonTemporaryEvents(regNPC, true)
    
    exports.ox_target:addLocalEntity(regNPC, {
        {
            name = 'gov_registration_npc',
            label = 'Register Official Documents',
            icon = 'fa-solid fa-file-signature',
            onSelect = function()
                openCitizenRegistration()
            end
        }
    })
end)

function openCitizenRegistration()
    -- Step 1: Select Type (Simple dialog to choose)
    local typeSelection = lib.inputDialog('Select Document to Register', {
        {type = 'select', label = 'What would you like to register?', options = {
            {value = 'kk', label = 'Kartu Keluarga (Family Card)'},
            {value = 'siu', label = 'Surat Izin Usaha (Business License)'},
            {value = 'st', label = 'Surat Tanah (Land Deed)'}
        }, required = true},
    })

    if not typeSelection then return end
    local docType = typeSelection[1]

    -- Prepare data for the Large NUI Form
    local data = {
        action = 'openRegistration',
        type = docType,
        label = (docType == 'kk' and 'Kartu Keluarga') or (docType == 'siu' and 'Izin Usaha') or 'Surat Tanah',
        template = ""
    }
    
    if docType == 'kk' then
        data.template = "DAFTAR ANGGOTA KELUARGA:\n1. [Nama Kepala Keluarga] - (Hubungan: Ayah)\n2. [Nama Istri] - (Hubungan: Ibu)\n3. [Nama Anak] - (Hubungan: Anak)\n\nALAMAT DOMISILI:\n[Ketik Alamat Lengkap Disini]"
    elseif docType == 'siu' then
        data.template = "NAMA USAHA: \nJENIS USAHA: \nLOKASI USAHA: \nMODAL USAHA: "
    elseif docType == 'st' then
        data.template = "LOKASI TANAH: \nLUAS TANAH: \nBATAS UTARA: \nBATAS SELATAN: "
    end

    SetNuiFocus(true, true)
    SendNUIMessage(data)
end

RegisterNUICallback('closeRegistration', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('submitRegistration', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('gov-mdt:server:applyForDocument', data.type, data.name, data.details)
    cb(true)
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    if govNPC then DeleteEntity(govNPC) end
    -- We can add cleanup for regNPC too if needed
end)
