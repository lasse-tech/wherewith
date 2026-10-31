local _, T = ...

local Addon = T.Addon

-- What the character owns. A "token" is anything a vendor takes in payment besides
-- gold: { kind = "currency" | "item", id = number }. Keys like "c1792" / "i190311".
local Wallet = {}
T.Wallet = Wallet

function Wallet.Key(kind, id)
    return (kind == "currency" and "c" or "i") .. id
end

function Wallet.ParseKey(key)
    local k, id = key:match("^([ci])(%d+)$")
    if not k then return nil end
    return k == "c" and "currency" or "item", tonumber(id)
end

local function currencyInfo(id)
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if not info or not info.name or info.name == "" then return nil end
    return info
end

-- amount usable at a vendor (bags only for items), extra = held elsewhere (bank, warband bank)
function Wallet.Amount(kind, id)
    if kind == "currency" then
        local info = currencyInfo(id)
        local q = info and info.quantity
        if not Addon.Usable(q) then return nil, 0 end
        return q, 0
    end
    local bags = C_Item.GetItemCount(id, false, false, false, false)
    local all = C_Item.GetItemCount(id, true, false, true, true)
    if not Addon.Usable(bags) or not Addon.Usable(all) then return nil, 0 end
    return bags, math.max(0, all - bags)
end

function Wallet.Name(kind, id)
    if kind == "currency" then
        local info = currencyInfo(id)
        return info and info.name
    end
    local name = C_Item.GetItemNameByID(id)
    if not name then C_Item.RequestLoadItemDataByID(id) end
    return name
end

function Wallet.Icon(kind, id)
    if kind == "currency" then
        local info = currencyInfo(id)
        return info and info.iconFileID
    end
    return C_Item.GetItemIconByID(id)
end

function Wallet.Quality(kind, id)
    if kind == "currency" then
        local info = currencyInfo(id)
        return info and info.quality
    end
    return C_Item.GetItemQualityByID(id)
end

function Wallet.Description(kind, id)
    if kind ~= "currency" then return nil end
    local info = currencyInfo(id)
    local text = info and info.description
    if text == "" then return nil end
    return text
end

function Wallet.Link(kind, id)
    if kind == "currency" then
        return C_CurrencyInfo.GetCurrencyLink(id, 0)
    end
    return (select(2, C_Item.GetItemInfo(id)))
end

local function listCurrencyID(index)
    local link = C_CurrencyInfo.GetCurrencyListLink(index)
    if not link then return nil end
    if C_CurrencyInfo.GetCurrencyIDFromLink then
        return C_CurrencyInfo.GetCurrencyIDFromLink(link)
    end
    return tonumber(link:match("currency:(%d+)"))
end

-- Reading collapsed groups of the currency list means expanding them; they are
-- collapsed again right after, last one first so the remembered indices stay valid.
-- Expanding and collapsing fire CURRENCY_DISPLAY_UPDATE themselves, a frame later;
-- those echoes must not trigger another read.
local QUIET = 1
local owned, busy, readAt = nil, false, 0

local function readOwned()
    local list, opened = {}, {}
    busy = true
    local i = 1
    while i <= C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.isHeader then
            if not info.isHeaderExpanded then
                C_CurrencyInfo.ExpandCurrencyList(i, true)
                opened[#opened + 1] = i
            end
        elseif info then
            local id = listCurrencyID(i)
            local q = info.quantity
            if id and Addon.Usable(q) and q > 0 then
                list[#list + 1] = { kind = "currency", id = id, key = Wallet.Key("currency", id) }
            end
        end
        i = i + 1
    end
    for j = #opened, 1, -1 do
        C_CurrencyInfo.ExpandCurrencyList(opened[j], false)
    end
    busy = false
    readAt = GetTime()
    return list
end

-- Currencies with a balance above zero, read lazily and cached until the next change.
function Wallet.OwnedCurrencies()
    if not owned then owned = readOwned() end
    return owned
end

function Wallet.Invalidate()
    if busy or GetTime() - readAt < QUIET then return end
    owned = nil
end
