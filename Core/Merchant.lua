local _, T = ...

local Addon = T.Addon
local DB = T.DB
local Wallet = T.Wallet

-- Learns vendors while their window is open: every entry that costs a currency or an
-- item is stored account-wide, with the vendor's position.
local Merchant = {}
T.Merchant = Merchant

local MAX_RETRIES = 10
local RETRY_DELAY = 0.5

local open, pending, retries = false, false, 0

-- "C1234" for creatures, "G1234" for game objects; "N<name>" when the GUID is unreadable
local function vendorKey()
    local guid = UnitGUID("npc")
    if Addon.Usable(guid) then
        local unitType, _, _, _, _, id = strsplit("-", guid)
        id = tonumber(id)
        if id and (unitType == "Creature" or unitType == "Vehicle") then return "C" .. id end
        if id and unitType == "GameObject" then return "G" .. id end
    end
    local name = UnitName("npc")
    if Addon.Usable(name) and name then return "N" .. name end
    return nil
end

local function where()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not Addon.Usable(mapID) then return nil end
    local x, y
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
        x, y = pos:GetXY()
        if not (Addon.Usable(x) and Addon.Usable(y)) or (x == 0 and y == 0) then x, y = nil, nil end
    end
    local sub = GetSubZoneText()
    return mapID, x, y, sub ~= "" and sub or nil
end

local function itemInfo(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        return C_MerchantFrame.GetItemInfo(index)
    end
    local name, _, price, stackCount, numAvailable, isPurchasable, isUsable, hasExtendedCost, currencyID =
        GetMerchantItemInfo(index)
    return {
        name = name, price = price, stackCount = stackCount, numAvailable = numAvailable,
        isPurchasable = isPurchasable, isUsable = isUsable, hasExtendedCost = hasExtendedCost,
        currencyID = currencyID,
    }
end

local function parseLink(link)
    if not link then return nil end
    local id = link:match("currency:(%d+)")
    if id then return "currency", tonumber(id) end
    id = link:match("item:(%d+)")
    if id then return "item", tonumber(id) end
    return nil
end

-- What the entry sells: kind, id; nil while the client has not cached it yet.
local function entryGoods(index, info)
    if info.currencyID and info.currencyID > 0 then return "currency", info.currencyID end
    local itemID = GetMerchantItemID and GetMerchantItemID(index)
    if itemID then return "item", itemID end
    return parseLink(GetMerchantItemLink(index))
end

-- A currency cost may come without a link; it is then one of the vendor's currencies
-- with the same name or icon.
local function currencyByNameOrIcon(name, texture)
    if not GetMerchantCurrencies then return nil end
    for _, id in ipairs({ GetMerchantCurrencies() }) do
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        if info and ((name and info.name == name) or (texture and info.iconFileID == texture)) then return id end
    end
    return nil
end

-- Returns the costs, or nil if one of them is not cached yet; an empty table if the
-- entry is gold only.
local function entryCosts(index)
    local costs = {}
    for c = 1, GetMerchantItemCostInfo(index) or 0 do
        local texture, value, link, name = GetMerchantItemCostItem(index, c)
        local kind, id = parseLink(link)
        if not kind then
            id = currencyByNameOrIcon(name, texture)
            kind = id and "currency" or nil
        end
        if not kind or not value then return nil end
        costs[#costs + 1] = { kind = kind, id = id, amount = value }
    end
    return costs
end

local function offerKey(offer)
    local parts = { Wallet.Key(offer.kind, offer.id) }
    for _, c in ipairs(offer.costs) do parts[#parts + 1] = Wallet.Key(c.kind, c.id) .. "x" .. c.amount end
    return table.concat(parts, ":")
end

local function showsEverything()
    if not (GetMerchantFilter and LE_LOOT_FILTER_ALL) then return true end
    return GetMerchantFilter() == LE_LOOT_FILTER_ALL
end

-- Returns whether every entry could be read.
local function scan()
    local key = vendorKey()
    if not key then return true end

    local offers, complete = {}, true
    for i = 1, GetMerchantNumItems() do
        local info = itemInfo(i)
        if info and (GetMerchantItemCostInfo(i) or 0) > 0 then
            local kind, id = entryGoods(i, info)
            local costs = entryCosts(i)
            if kind and costs then
                if #costs > 0 then
                    offers[#offers + 1] = {
                        kind = kind, id = id, costs = costs,
                        qty = (info.stackCount or 1) > 1 and info.stackCount or nil,
                        gold = (info.price or 0) > 0 and info.price or nil,
                    }
                end
            else
                complete = false
            end
        end
    end

    local vendors = DB.Vendors()
    local vendor = vendors[key]
    if #offers == 0 and not vendor then return complete end

    local mapID, x, y, sub = where()
    vendor = vendor or {}
    vendor.name = UnitName("npc") or vendor.name
    vendor.seen = time()
    if mapID then
        vendor.map, vendor.x, vendor.y, vendor.sub = mapID, x, y, sub
    end

    if complete and showsEverything() then
        vendor.offers = offers
    else
        -- A filtered or partial view: add what was read, keep the rest.
        local merged, order = {}, {}
        for _, o in ipairs(vendor.offers or {}) do
            local k = offerKey(o)
            merged[k] = o
            order[#order + 1] = k
        end
        for _, o in ipairs(offers) do
            local k = offerKey(o)
            if not merged[k] then order[#order + 1] = k end
            merged[k] = o
        end
        vendor.offers = {}
        for _, k in ipairs(order) do vendor.offers[#vendor.offers + 1] = merged[k] end
    end

    if #vendor.offers == 0 then
        vendors[key] = nil
    else
        vendors[key] = vendor
    end
    if Merchant.debug then
        Addon.Print(("scan %s: %d offers, complete=%s, %d entries"):format(key, #vendor.offers,
            tostring(complete), GetMerchantNumItems()))
    end
    return complete
end

local function request()
    if pending or not open then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        if not open then return end
        local complete = scan()
        Addon.Refresh()
        if not complete and retries < MAX_RETRIES then
            retries = retries + 1
            C_Timer.After(RETRY_DELAY, request)
        end
    end)
end

function Merchant.Initialize()
    Addon.RegisterEvent("MERCHANT_SHOW", function()
        open, retries = true, 0
        request()
    end)
    Addon.RegisterEvent("MERCHANT_CLOSED", function() open = false end)
    Addon.RegisterEvent("MERCHANT_UPDATE", request)
    Addon.RegisterEvent("MERCHANT_FILTER_ITEM_UPDATE", request)
    Addon.RegisterEvent("GET_ITEM_INFO_RECEIVED", request)
end

function Merchant.IsOpen() return open end

-- /ww debug at an open vendor: what the client reports, raw.
function Merchant.Dump()
    Merchant.debug = true
    if not open then
        Addon.Print("debug on; open a vendor and run /ww debug again")
        return
    end
    local guid = UnitGUID("npc")
    Addon.Print(("npc %s, guid usable=%s, key=%s, entries=%d, currencies=%s"):format(
        tostring(UnitName("npc")), tostring(Addon.Usable(guid)), tostring(vendorKey()), GetMerchantNumItems(),
        table.concat({ tostringall(GetMerchantCurrencies and GetMerchantCurrencies()) }, ",")))
    for i = 1, math.min(GetMerchantNumItems(), 8) do
        local info = itemInfo(i) or {}
        local parts = { ("#%d %s ext=%s id=%s"):format(i, tostring(info.name), tostring(info.hasExtendedCost),
            tostring(GetMerchantItemID(i))) }
        for c = 1, GetMerchantItemCostInfo(i) or 0 do
            local texture, value, link, name = GetMerchantItemCostItem(i, c)
            parts[#parts + 1] = ("[%s x%s %s %s]"):format(tostring(name), tostring(value), tostring(texture),
                link and link:gsub("|", "||") or "nolink")
        end
        Addon.Print(table.concat(parts, " "))
    end
    request()
end
