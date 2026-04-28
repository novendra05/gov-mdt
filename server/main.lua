local exports = exports
local qbx = exports.qbx_core

-- Register Stash
MySQL.ready(function()
    exports.ox_inventory:RegisterStash(Config.WarehouseStash.id, Config.WarehouseStash.label, Config.WarehouseStash.slots, Config.WarehouseStash.weight)
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `gov_sales_logs` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `item` VARCHAR(50) NOT NULL,
            `amount` INT NOT NULL,
            `price` INT NOT NULL,
            `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `gov_market_items` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `item` VARCHAR(50) NOT NULL UNIQUE,
            `label` VARCHAR(100) NOT NULL,
            `price` INT NOT NULL DEFAULT 0,
            `category` VARCHAR(50) NOT NULL DEFAULT 'General',
            `min_buy_price` INT NOT NULL DEFAULT 0,
            `min_stock_percent` INT NOT NULL DEFAULT 80
        );
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `gov_market_categories` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(50) NOT NULL UNIQUE,
            `label` VARCHAR(100) NOT NULL
        );
    ]])

    -- Ensure columns exist
    MySQL.query("ALTER TABLE `gov_market_items` ADD COLUMN IF NOT EXISTS `category` VARCHAR(50) NOT NULL DEFAULT 'General'")
    MySQL.query("ALTER TABLE `gov_market_items` ADD COLUMN IF NOT EXISTS `max_stock` INT NOT NULL DEFAULT 100")
    MySQL.query("ALTER TABLE `gov_market_items` ADD COLUMN IF NOT EXISTS `current_stock` INT NOT NULL DEFAULT 0")
    MySQL.query("ALTER TABLE `gov_market_items` ADD COLUMN IF NOT EXISTS `sell_price` INT NOT NULL DEFAULT 0")
    MySQL.query("ALTER TABLE `gov_market_items` ADD COLUMN IF NOT EXISTS `min_buy_price` INT NOT NULL DEFAULT 0")
    MySQL.query("ALTER TABLE `gov_market_items` ADD COLUMN IF NOT EXISTS `min_stock_percent` INT NOT NULL DEFAULT 80")

    -- Announcements Table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `gov_announcements` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `title` VARCHAR(100) NOT NULL,
            `message` TEXT NOT NULL,
            `author` VARCHAR(100) NOT NULL,
            `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    ]])

    -- Legal Documents Table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `gov_documents` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `title` VARCHAR(100) NOT NULL,
            `content` TEXT NOT NULL,
            `author` VARCHAR(100) NOT NULL,
            `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    ]])
end)

-- Helper to check for high rank (Boss)
local function isHighRank(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    -- Level 3 is the highest rank (Governor)
    return player.PlayerData.job.name == 'government' and player.PlayerData.job.grade.level >= 3
end

-- Get Dashboard Data
lib.callback.register('gov-mdt:server:getDashboardData', function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil end

    local totalCitizens = MySQL.scalar.await('SELECT COUNT(*) FROM players')
    
    -- Calculate Revenue (Purchases are positive, Sales to Gov are negative for gov cash flow)
    -- But usually Gov wants to see "Volume", so let's show Total Money Circulated
    local totalRevenue = MySQL.scalar.await('SELECT SUM(price) FROM gov_sales_logs') or 0
    local totalSales = MySQL.scalar.await('SELECT COUNT(*) FROM gov_sales_logs')
    
    -- Top Selling Item
    local topItemResult = MySQL.single.await('SELECT item, SUM(amount) as total FROM gov_sales_logs GROUP BY item ORDER BY total DESC LIMIT 1')
    local topItem = topItemResult and (topItemResult.item .. " (" .. topItemResult.total .. ")") or "None"

    -- Warehouse Health (Average stock percentage)
    local marketStats = MySQL.query.await('SELECT current_stock, max_stock FROM gov_market_items')
    local avgStock = 0
    if marketStats and #marketStats > 0 then
        local totalPercent = 0
        for i=1, #marketStats do
            totalPercent = totalPercent + (marketStats[i].current_stock / marketStats[i].max_stock)
        end
        avgStock = math.round((totalPercent / #marketStats) * 100)
    end

    local recentSales = MySQL.query.await('SELECT * FROM gov_sales_logs ORDER BY timestamp DESC LIMIT 5')
    
    return {
        user = {
            name = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname,
            job = player.PlayerData.job.label .. " - " .. player.PlayerData.job.grade.name,
            grade_level = player.PlayerData.job.grade.level
        },
        totalCitizens = totalCitizens,
        totalSales = totalSales,
        totalRevenue = totalRevenue,
        topItem = topItem,
        warehouseHealth = avgStock,
        recentSales = recentSales,
        latestAnnouncement = MySQL.single.await('SELECT * FROM gov_announcements ORDER BY timestamp DESC LIMIT 1')
    }
end)

-- Warehouse Access Check
lib.callback.register('gov-mdt:server:getWarehouses', function(source)
    local src = source
    if not isHighRank(src) then
        return {error = "You do not have permission to access the warehouse manual management."}
    end
    
    local categories = MySQL.query.await('SELECT * FROM gov_market_categories')
    return {categories = categories}
end)

-- Citizen Search
lib.callback.register('gov-mdt:server:searchCitizens', function(source, query)
    local results = MySQL.query.await([[
        SELECT citizenid, charinfo 
        FROM players 
        WHERE citizenid LIKE ? 
        OR charinfo LIKE ? 
        OR charinfo LIKE ?
        LIMIT 20
    ]], {
        '%' .. query .. '%', -- Citizen ID
        '%' .. query .. '%', -- First/Last Name (contained in charinfo)
        '%' .. query .. '%'  -- Birthdate (contained in charinfo)
    })
    
    local citizens = {}
    if results then
        for i=1, #results do
            local charinfo = json.decode(results[i].charinfo)
            citizens[#citizens+1] = {
                citizenid = results[i].citizenid,
                firstname = charinfo.firstname,
                lastname = charinfo.lastname,
                fullname = charinfo.firstname .. ' ' .. charinfo.lastname,
                dob = charinfo.birthdate or 'Unknown'
            }
        end
    end
    return citizens
end)

-- Get Citizen Details
lib.callback.register('gov-mdt:server:getCitizenData', function(source, citizenid)
    local result = MySQL.single.await('SELECT charinfo, metadata, job FROM players WHERE citizenid = ?', {citizenid})
    if result then
        local charinfo = json.decode(result.charinfo)
        local metadata = json.decode(result.metadata)
        local job = json.decode(result.job)
        
        -- Find Family Members
        local familyMembers = {}
        if metadata.family_card and metadata.family_card ~= '' then
            local familyResults = MySQL.query.await([[
                SELECT citizenid, charinfo 
                FROM players 
                WHERE JSON_EXTRACT(metadata, '$.family_card') = ? 
                AND citizenid != ?
            ]], {metadata.family_card, citizenid})
            
            if familyResults then
                for i=1, #familyResults do
                    local fCharinfo = json.decode(familyResults[i].charinfo)
                    familyMembers[#familyMembers+1] = {
                        name = fCharinfo.firstname .. ' ' .. fCharinfo.lastname,
                        citizenid = familyResults[i].citizenid
                    }
                end
            end
        end

        return {
            charinfo = charinfo,
            metadata = metadata,
            job = job,
            family = familyMembers
        }
    end
    return nil
end)

-- Save Family Card (KK)
lib.callback.register('gov-mdt:server:saveFamilyCard', function(source, citizenid, kk_data)
    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if player then
        player.Functions.SetMetaData('family_card', kk_data)
        return true
    else
        local result = MySQL.single.await('SELECT metadata FROM players WHERE citizenid = ?', {citizenid})
        if result then
            local metadata = json.decode(result.metadata)
            metadata.family_card = kk_data
            MySQL.update.await('UPDATE players SET metadata = ? WHERE citizenid = ?', {json.encode(metadata), citizenid})
            return true
        end
    end
    return false
end)

-- Get Market Data (Items & Categories)
lib.callback.register('gov-mdt:server:getMarketItems', function(source)
    local src = source
    local items = MySQL.query.await('SELECT * FROM gov_market_items')
    local categories = MySQL.query.await('SELECT * FROM gov_market_categories')
    
    -- Sync Stock with actual Stash contents
    if items and #items > 0 then
        for i=1, #items do
            local item = items[i]
            local stashId = 'gov_stash_' .. (item.category or 'General')
            
            -- Get actual count from ox_inventory stash
            local actualCount = exports.ox_inventory:GetItem(stashId, item.item, nil, true) or 0
            
            if actualCount ~= item.current_stock then
                MySQL.update.await('UPDATE gov_market_items SET current_stock = ? WHERE id = ?', {actualCount, item.id})
                items[i].current_stock = actualCount -- Update local table for immediate NUI refresh
            end
        end
    end

    -- Register Stashes for each category (ensure they exist)
    if categories then
        for i=1, #categories do
            local stashId = 'gov_stash_' .. categories[i].name
            exports.ox_inventory:RegisterStash(stashId, 'Gov Warehouse: ' .. categories[i].label, 200, 10000000)
        end
    end

    TriggerClientEvent('gov-mdt:client:sendToNUI', src, {
        action = 'renderMarketItems',
        items = items,
        categories = categories
    })
    return {items = items, categories = categories}
end)

-- Update Market Item (Add/Edit)
lib.callback.register('gov-mdt:server:updateMarketItem', function(source, item, label, price, category, max_stock, sell_price, min_buy_price, min_stock_percent)
    local src = source
    if not isHighRank(src) then return false end
    
    local stockPercentLimit = min_stock_percent or 80
    MySQL.query.await('INSERT INTO gov_market_items (item, label, price, category, max_stock, sell_price, min_buy_price, min_stock_percent) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label = ?, price = ?, category = ?, max_stock = ?, sell_price = ?, min_buy_price = ?, min_stock_percent = ?', {
        item, label, price, category, max_stock, sell_price, min_buy_price, stockPercentLimit, label, price, category, max_stock, sell_price, min_buy_price, stockPercentLimit
    })
    return true
end)

-- Remove Market Item
lib.callback.register('gov-mdt:server:removeMarketItem', function(source, id)
    local src = source
    if not isHighRank(src) then return false end
    
    MySQL.query.await('DELETE FROM gov_market_items WHERE id = ?', {id})
    return true
end)

-- Add Category
lib.callback.register('gov-mdt:server:addCategory', function(source, name, label)
    local src = source
    if not isHighRank(src) then return false end
    
    MySQL.query.await('INSERT INTO gov_market_categories (name, label) VALUES (?, ?)', {name, label})
    return true
end)

-- Remove Category
lib.callback.register('gov-mdt:server:removeCategory', function(source, id)
    local src = source
    if not isHighRank(src) then return false end
    
    MySQL.query.await('DELETE FROM gov_market_categories WHERE id = ?', {id})
    return true
end)

-- Citizen Sell Item
lib.callback.register('gov-mdt:server:sellItemToGov', function(source, itemData, amount)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    
    -- Check Quota
    local marketItem = MySQL.single.await('SELECT current_stock, max_stock FROM gov_market_items WHERE item = ?', {itemData.item})
    if not marketItem then return false, 'Item not found in market.' end

    local remainingQuota = marketItem.max_stock - marketItem.current_stock
    if amount > remainingQuota then
        return false, 'Quota exceeded. Remaining: ' .. remainingQuota
    end

    local item = exports.ox_inventory:GetItem(src, itemData.item, nil, false)
    if not item or item.count < amount then
        return false, 'Not enough items.'
    end

    -- Dynamic Price Calculation
    local currentPrice = itemData.price
    if itemData.min_buy_price and itemData.min_buy_price > 0 and itemData.price > itemData.min_buy_price then
        local stockPercent = marketItem.current_stock / marketItem.max_stock
        local targetPercent = (itemData.min_stock_percent or 80) / 100.0
        
        if stockPercent >= targetPercent then
            currentPrice = itemData.min_buy_price
        else
            currentPrice = itemData.price
        end
    end

    local totalPrice = currentPrice * amount
    local stashId = 'gov_stash_' .. (itemData.category or 'General')

    if exports.ox_inventory:RemoveItem(src, itemData.item, amount) then
        player.Functions.AddMoney('cash', totalPrice, 'Sold to Government')
        
        -- Add to Warehouse Stash
        exports.ox_inventory:AddItem(stashId, itemData.item, amount)

        -- Update Stock
        MySQL.update.await('UPDATE gov_market_items SET current_stock = current_stock + ? WHERE item = ?', {amount, itemData.item})

        -- Log to Sales
        MySQL.insert.await('INSERT INTO gov_sales_logs (citizenid, name, item, amount, price) VALUES (?, ?, ?, ?, ?)', {
            player.PlayerData.citizenid,
            player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
            itemData.label,
            amount,
            totalPrice
        })
        return true, 'Sold ' .. amount .. 'x ' .. itemData.label .. ' to ' .. itemData.category .. ' warehouse for $' .. totalPrice
    end

    return false, 'Failed to remove item.'
end)

-- Citizen Buy Item from Gov
lib.callback.register('gov-mdt:server:buyItemFromGov', function(source, itemData, amount)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    
    local totalPrice = (itemData.sell_price or 0) * amount
    if player.PlayerData.money.cash < totalPrice then
        return false, 'Not enough cash.'
    end

    local stashId = 'gov_stash_' .. (itemData.category or 'General')
    local stashItem = exports.ox_inventory:GetItem(stashId, itemData.item, nil, false)
    
    if not stashItem or stashItem.count < amount then
        return false, 'Government warehouse does not have enough stock.'
    end

    if exports.ox_inventory:RemoveItem(stashId, itemData.item, amount) then
        player.Functions.RemoveMoney('cash', totalPrice, 'Bought from Government')
        exports.ox_inventory:AddItem(src, itemData.item, amount)

        -- Log to Sales (as a purchase)
        MySQL.insert.await('INSERT INTO gov_sales_logs (citizenid, name, item, amount, price) VALUES (?, ?, ?, ?, ?)', {
            player.PlayerData.citizenid,
            player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
            '[PURCHASE] ' .. itemData.label,
            amount,
            -totalPrice -- Negative price indicates government income/citizen spending
        })
        return true, 'Bought ' .. amount .. 'x ' .. itemData.label .. ' for $' .. totalPrice
    end

    return false, 'Failed to process purchase.'
end)

-- Get Sales Logs

-- Log Sale (Utility for other scripts or manual entry)
RegisterNetEvent('gov-mdt:server:logSale', function(data)
    -- data: { citizenid, name, item, amount, price }
    MySQL.insert.await('INSERT INTO gov_sales_logs (citizenid, name, item, amount, price) VALUES (?, ?, ?, ?, ?)', {
        data.citizenid,
        data.name,
        data.item,
        data.amount,
        data.price
    })
end)

-- Test Command (Remove for production or restrict to admin)
RegisterCommand('testgovlog', function(source, args)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    
    TriggerEvent('gov-mdt:server:logSale', {
        citizenid = player.PlayerData.citizenid,
        name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
        item = args[1] or 'Gold Bar',
        amount = tonumber(args[2]) or 1,
        price = tonumber(args[3]) or 1000
    })
    print('Log added for testing.')
end, true)

-- Announcement Management
lib.callback.register('gov-mdt:server:getAnnouncements', function(source)
    return MySQL.query.await('SELECT * FROM gov_announcements ORDER BY timestamp DESC')
end)

lib.callback.register('gov-mdt:server:addAnnouncement', function(source, title, message)
    local src = source
    if not isHighRank(src) then return false end
    
    local player = exports.qbx_core:GetPlayer(src)
    local author = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
    
    MySQL.insert.await('INSERT INTO gov_announcements (title, message, author) VALUES (?, ?, ?)', {title, message, author})
    return true
end)


lib.callback.register('gov-mdt:server:deleteAnnouncement', function(source, id)
    local src = source
    if not isHighRank(src) then return false end
    MySQL.query.await('DELETE FROM gov_announcements WHERE id = ?', {id})
    return true
end)

-- License Management
lib.callback.register('gov-mdt:server:updateLicense', function(source, citizenid, licenseType, state)
    local src = source
    if not isHighRank(src) then return false end

    local targetPlayer = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if targetPlayer then
        -- Player is online
        local licenses = targetPlayer.PlayerData.metadata.licences
        licenses[licenseType] = state
        targetPlayer.Functions.SetMetaData('licences', licenses)
        return true, "License updated for " .. targetPlayer.PlayerData.charinfo.firstname
    else
        -- Player is offline, need to update database directly
        local result = MySQL.single.await('SELECT metadata FROM players WHERE citizenid = ?', {citizenid})
        if result then
            local metadata = json.decode(result.metadata)
            if not metadata.licences then metadata.licences = {} end
            metadata.licences[licenseType] = state
            MySQL.update.await('UPDATE players SET metadata = ? WHERE citizenid = ?', {json.encode(metadata), citizenid})
            return true, "License updated in database (Player offline)"
        end
    end
    return false, "Citizen not found."
end)

-- Employee Management
lib.callback.register('gov-mdt:server:getEmployees', function(source)
    local src = source
    if not isHighRank(src) then return {} end
    
    local results = MySQL.query.await('SELECT citizenid, charinfo, job FROM players WHERE job LIKE ?', {'%"name":"government"%'})
    local employees = {}
    
    for i=1, #results do
        local charinfo = json.decode(results[i].charinfo)
        local job = json.decode(results[i].job)
        local isOnline = exports.qbx_core:GetPlayerByCitizenId(results[i].citizenid) ~= nil
        
        table.insert(employees, {
            citizenid = results[i].citizenid,
            name = charinfo.firstname .. " " .. charinfo.lastname,
            grade = job.grade.level,
            grade_name = job.grade.name,
            isOnline = isOnline
        })
    end
    
    return employees
end)

lib.callback.register('gov-mdt:server:updateEmployeeGrade', function(source, citizenid, newGrade)
    local src = source
    if not isHighRank(src) then return false end
    
    local targetPlayer = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if targetPlayer then
        targetPlayer.Functions.SetJob('government', newGrade)
        return true
    else
        -- Offline update
        local result = MySQL.single.await('SELECT job FROM players WHERE citizenid = ?', {citizenid})
        if result then
            local job = json.decode(result.job)
            job.grade.level = newGrade
            MySQL.update.await('UPDATE players SET job = ? WHERE citizenid = ?', {json.encode(job), citizenid})
            return true
        end
    end
    return false
end)

lib.callback.register('gov-mdt:server:fireEmployee', function(source, citizenid)
    local src = source
    if not isHighRank(src) then return false end
    
    local targetPlayer = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if targetPlayer then
        targetPlayer.Functions.SetJob('unemployed', 0)
        return true
    else
        -- Offline update
        local defaultJob = {name = 'unemployed', label = 'Unemployed', payment = 10, type = 'none', onDuty = true, grade = {name = 'Unemployed', level = 0}}
        MySQL.update.await('UPDATE players SET job = ? WHERE citizenid = ?', {json.encode(defaultJob), citizenid})
        return true
    end
    return false
end)

lib.callback.register('gov-mdt:server:hireEmployee', function(source, citizenid)
    local src = source
    if not isHighRank(src) then return false end
    
    local targetPlayer = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if targetPlayer then
        targetPlayer.Functions.SetJob('government', 0)
        return true
    else
        -- Offline update
        local govJob = {name = 'government', label = 'Government', payment = 100, type = 'government', onDuty = true, grade = {name = 'Staff', level = 0}}
        MySQL.update.await('UPDATE players SET job = ? WHERE citizenid = ?', {json.encode(govJob), citizenid})
        return true
    end
    return false
end)

-- Legal Documents Management
lib.callback.register('gov-mdt:server:getDocuments', function()
    return MySQL.query.await('SELECT * FROM gov_documents ORDER BY timestamp DESC')
end)

lib.callback.register('gov-mdt:server:getDocumentById', function(source, id)
    return MySQL.single.await('SELECT * FROM gov_documents WHERE id = ?', {id})
end)

lib.callback.register('gov-mdt:server:updateDocument', function(source, id, title, content)
    local success = MySQL.update.await('UPDATE gov_documents SET title = ?, content = ? WHERE id = ?', {title, content, id})
    return success > 0
end)

lib.callback.register('gov-mdt:server:addDocument', function(source, title, content)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local author = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
    
    local id = MySQL.insert.await('INSERT INTO gov_documents (title, content, author) VALUES (?, ?, ?)', {title, content, author})
    return id > 0
end)

lib.callback.register('gov-mdt:server:getSalesLogs', function(source, filterDate)
    local query = 'SELECT * FROM gov_sales_logs WHERE DATE(timestamp) = CURDATE() ORDER BY timestamp DESC'
    local params = {}
    
    if filterDate and filterDate ~= "" then
        query = 'SELECT * FROM gov_sales_logs WHERE DATE(timestamp) = ? ORDER BY timestamp DESC'
        params = {filterDate}
    end
    
    return MySQL.query.await(query, params)
end)

RegisterNetEvent('gov-mdt:server:deleteDocument', function(id)
    local src = source
    if not isHighRank(src) then return end
    MySQL.query.await('DELETE FROM gov_documents WHERE id = ?', {id})
end)

RegisterNetEvent('gov-mdt:server:givePhysicalDoc', function(targetId, docId)
    local src = source
    local target = tonumber(targetId)
    print(string.format("[gov-mdt] Handover Attempt - Doc: %s, To ID: %s", docId, target))
    
    local doc = MySQL.single.await('SELECT * FROM gov_documents WHERE id = ?', {docId})
    if not doc then 
        print("[gov-mdt] Error: Document not found in DB")
        return 
    end

    -- Get current staff member's name for certification
    local staff = exports.qbx_core:GetPlayer(src)
    local staffName = staff.PlayerData.charinfo.firstname .. " " .. staff.PlayerData.charinfo.lastname

    local metadata = {
        docId = doc.id,
        title = doc.title,
        content = doc.content,
        author = staffName, -- Automatically fill with the staff name who gives it
        timestamp = doc.timestamp,
        description = "Official Document: " .. doc.title .. "\nCertified by: " .. staffName
    }

    print("[gov-mdt] Metadata being sent to inventory:", json.encode(metadata))
    
    -- Using a more explicit AddItem syntax for ox_inventory
    local success = exports.ox_inventory:AddItem(target, 'legal_document', 1, metadata, nil)
    
    if success then
        print("[gov-mdt] Item added successfully to ID", target)
        TriggerClientEvent('ox_lib:notify', src, { title = 'Document Given', description = 'Handed a physical copy to ID ' .. target, type = 'success' })
        if src ~= target then
            TriggerClientEvent('ox_lib:notify', target, { title = 'Document Received', description = 'You received a physical document.', type = 'info' })
        end
    else
        print("^1[gov-mdt] FAILED to add item 'legal_document' to ID " .. target .. ". Check ox_inventory logs!^7")
        TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Could not add item. Check server console!', type = 'error' })
    end
end)

-- Usable Item Logic (ox_inventory)
exports('legal_document', function(event, item, inventory, slot, data)
    if event == 'usingItem' then
        print("[gov-mdt] Item 'legal_document' is being USED by ID:", inventory.id, "at SLOT:", slot)
        
        -- Get the actual slot data to find metadata
        local slotData = exports.ox_inventory:GetSlot(inventory.id, slot)
        local metadata = slotData and slotData.metadata
        
        print("[gov-mdt] Found Metadata from GetSlot:", json.encode(metadata))

        if not metadata or not metadata.docId then
            TriggerClientEvent('ox_lib:notify', inventory.id, { title = 'Invalid Document', description = 'This document is empty or damaged.', type = 'error' })
            return false
        end

        local doc = {
            id = metadata.docId,
            title = metadata.title,
            content = metadata.content,
            author = metadata.author,
            timestamp = metadata.timestamp
        }
        TriggerClientEvent('gov-mdt:client:viewDocument', inventory.id, doc)
        return false -- Don't consume the item
    end
end)

RegisterNetEvent('gov-mdt:server:applyForDocument', function(docType, name, details)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local title = ""
    local content = ""
    
    if docType == 'kk' then
        title = "Kartu Keluarga: " .. name
        content = "DOKUMEN RESMI KELUARGA\n====================\nNama Kepala Keluarga / Anggota: " .. name .. "\nDetail & Alamat: " .. details .. "\n\nDokumen ini diterbitkan atas pengajuan mandiri warga."
    elseif docType == 'siu' then
        title = "Surat Izin Usaha: " .. name
        content = "IZIN OPERASIONAL BISNIS\n====================\nNama Pemilik / Badan Usaha: " .. name .. "\nDeskripsi & Lokasi: " .. details .. "\n\nIzin ini berlaku sejak tanggal penerbitan oleh pemerintah."
    elseif docType == 'st' then
        title = "Surat Sertifikat Tanah: " .. name
        content = "SERTIFIKAT HAK MILIK TANAH\n====================\nPemilik Sah: " .. name .. "\nLokasi & Batas Tanah: " .. details .. "\n\nDokumen ini merupakan bukti kepemilikan aset yang sah."
    end

    local author = "Citizen Self-Service"
    
    MySQL.insert.await('INSERT INTO gov_documents (title, content, author) VALUES (?, ?, ?)', {title, content, author})
    
    TriggerClientEvent('ox_lib:notify', src, { 
        title = 'Application Submitted', 
        description = 'Your application for ' .. title .. ' has been sent to the Government.', 
        type = 'success' 
    })
    
    -- Optional: Notify all online government employees
    local players = exports.qbx_core:GetQBPlayers()
    for _, v in pairs(players) do
        if v.PlayerData.job.name == 'government' then
            TriggerClientEvent('ox_lib:notify', v.PlayerData.source, { 
                title = 'New Application', 
                description = 'A new citizen document application is waiting for review.', 
                type = 'info' 
            })
        end
    end
end)

RegisterNetEvent('gov-mdt:server:showDocument', function(docId)
    local src = source
    local doc = MySQL.single.await('SELECT * FROM gov_documents WHERE id = ?', {docId})
    if not doc then return end

    local coords = GetEntityCoords(GetPlayerPed(src))
    local players = GetActivePlayers()
    for i=1, #players do
        local targetSrc = players[i]
        local targetPed = GetPlayerPed(targetSrc)
        local targetCoords = GetEntityCoords(targetPed)
        if #(coords - targetCoords) < 5.0 then
            TriggerClientEvent('gov-mdt:client:viewDocument', targetSrc, doc)
        end
    end
end)
