local _, T = ...

local Addon = T.Addon
local DB = T.DB
local Wallet = T.Wallet
local Journal = T.Journal

-- Turns what was learned into what the window shows: offers with their price, whether
-- the character can afford them now and whether they are collected already.
local Offers = {}
T.Offers = Offers

local collectedCache = {}

local function mountCollected(itemID)
    if not (C_MountJournal and C_MountJournal.GetMountFromItem) then return nil end
    local mountID = C_MountJournal.GetMountFromItem(itemID)
    if not mountID then return nil end
    return (select(11, C_MountJournal.GetMountInfoByID(mountID))) and true or false
end

local function petCollected(itemID)
    if not (C_PetJournal and C_PetJournal.GetPetInfoByItemID) then return nil end
    local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(itemID))
    if not speciesID then return nil end
    local numCollected = C_PetJournal.GetNumCollectedInfo(speciesID)
    return (numCollected or 0) > 0
end

local function toyCollected(itemID)
    if not (C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(itemID)) then return nil end
    return PlayerHasToy(itemID) and true or false
end

local function appearanceCollected(itemID)
    if not (C_TransmogCollection and C_TransmogCollection.GetItemInfo) then return nil end
    local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemID)
    if not appearanceID or not sourceID then return nil end
    local info = C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
    if info then return info.appearanceIsCollected and true or false end
    return C_TransmogCollection.PlayerHasTransmog(itemID) and true or false
end

-- Recipes, decor and the like say so in their tooltip.
local function tooltipKnown(itemID)
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID and ITEM_SPELL_KNOWN) then return nil end
    local data = C_TooltipInfo.GetItemByID(itemID)
    if not data or not data.lines then return nil end
    for _, line in ipairs(data.lines) do
        if line.leftText == ITEM_SPELL_KNOWN then return true end
    end
    return nil
end

-- true / false for collectibles, nil for anything that is not one
function Offers.Collected(kind, id)
    if kind == "mount" then
        return (select(11, C_MountJournal.GetMountInfoByID(id))) and true or false
    end
    if kind ~= "item" then return nil end
    local cached = collectedCache[id]
    if cached ~= nil then return cached ~= "none" and cached or nil end
    -- Tooltip and appearance data of an uncached item are incomplete; ask again later.
    if not C_Item.IsItemDataCachedByID(id) then
        C_Item.RequestLoadItemDataByID(id)
        return nil
    end
    local result = mountCollected(id)
    if result == nil then result = petCollected(id) end
    if result == nil then result = toyCollected(id) end
    if result == nil then result = appearanceCollected(id) end
    if result == nil then result = tooltipKnown(id) end
    collectedCache[id] = result == nil and "none" or result
    return result
end

function Offers.InvalidateCollected()
    wipe(collectedCache)
end

-- Categories --------------------------------------------------------------------
-- Blizzard's item classes; mounts and companion pets are subclasses of Miscellaneous
-- and get entries of their own.

local MISC = Enum.ItemClass.Miscellaneous
local OWN_MISC = {
    [Enum.ItemMiscellaneousSubclass.Mount] = true,
    [Enum.ItemMiscellaneousSubclass.CompanionPet] = true,
}

function Offers.Category(offer)
    if offer.kind == "mount" then return "misc:" .. Enum.ItemMiscellaneousSubclass.Mount end
    if offer.kind == "currency" then return "currency" end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(offer.id)
    if not classID then return "class:" .. MISC end
    if classID == MISC and OWN_MISC[subclassID] then return "misc:" .. subclassID end
    return "class:" .. classID
end

function Offers.CategoryName(key)
    if key == "currency" then return T.L["Currency"] end
    local kind, id = key:match("^(%a+):(%d+)$")
    id = tonumber(id)
    if kind == "misc" then return C_Item.GetItemSubClassInfo(MISC, id) end
    if kind == "class" then return C_Item.GetItemClassInfo(id) end
    return nil
end

-- Every category among the learned offers, by name.
function Offers.Categories()
    local seen, list = {}, {}
    local function add(key)
        if seen[key] then return end
        seen[key] = true
        list[#list + 1] = { key = key, name = Offers.CategoryName(key) or key }
    end
    for _, vendor in pairs(DB.Vendors()) do
        for _, o in ipairs(vendor.offers or {}) do add(Offers.Category(o)) end
    end
    if DB.Profile().showJournal and #Journal.Offers() > 0 then add(Offers.Category({ kind = "mount" })) end
    table.sort(list, function(x, y) return x.name < y.name end)
    return list
end

-- How often the character can buy it right now: a number, or nil if a balance is unreadable.
function Offers.Times(offer)
    local times = math.huge
    for _, c in ipairs(offer.costs) do
        local have = Wallet.Amount(c.kind, c.id)
        if not have then return nil end
        times = math.min(times, math.floor(have / c.amount))
    end
    if offer.gold then times = math.min(times, math.floor(GetMoney() / offer.gold)) end
    return times
end

function Offers.ZoneName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name
end

local function displayName(offer)
    if offer.kind == "mount" then return offer.name end
    return Wallet.Name(offer.kind, offer.id)
end

local function fromVendors(out)
    for key, vendor in pairs(DB.Vendors()) do
        for _, o in ipairs(vendor.offers or {}) do
            out[#out + 1] = {
                origin = "vendor", vendorKey = key, vendor = vendor.name, map = vendor.map,
                x = vendor.x, y = vendor.y, sub = vendor.sub, seen = vendor.seen,
                zone = Offers.ZoneName(vendor.map),
                kind = o.kind, id = o.id, qty = o.qty, gold = o.gold, costs = o.costs,
            }
        end
    end
end

local function fromJournal(out, learnedMounts)
    for _, m in ipairs(Journal.Offers()) do
        if not learnedMounts[m.id] then
            out[#out + 1] = {
                origin = "journal", vendorKey = "journal:" .. (m.vendor or "?"), vendor = m.vendor,
                zone = m.zone, source = m.source,
                kind = "mount", id = m.id, name = m.name, icon = m.icon, spellID = m.spellID, costs = m.costs,
            }
        end
    end
end

local function matches(offer, needle)
    if not needle then return true end
    local fields = { offer.name, offer.vendor, offer.zone, offer.sub }
    for _, c in ipairs(offer.costs) do fields[#fields + 1] = Wallet.Name(c.kind, c.id) end
    for _, f in ipairs(fields) do
        if f and f:lower():find(needle, 1, true) then return true end
    end
    return false
end

local function ownsEveryToken(offer)
    for _, c in ipairs(offer.costs) do
        local have, extra = Wallet.Amount(c.kind, c.id)
        if have and have + extra <= 0 then return false end
    end
    return true
end

-- All offers that pass the current filters, decorated with name, times and collected.
function Offers.List(search)
    local profile = DB.Profile()
    local needle = search and search ~= "" and search:lower() or nil

    local raw = {}
    fromVendors(raw)
    if profile.showJournal then
        local learnedMounts = {}
        for _, o in ipairs(raw) do
            if o.kind == "item" and C_MountJournal and C_MountJournal.GetMountFromItem then
                local mountID = C_MountJournal.GetMountFromItem(o.id)
                if mountID then learnedMounts[mountID] = true end
            end
        end
        fromJournal(raw, learnedMounts)
    end

    local list = {}
    for _, o in ipairs(raw) do
        o.name = displayName(o)
        o.collected = Offers.Collected(o.kind, o.id)
        o.times = Offers.Times(o)
        local keep = matches(o, needle)
            and not (profile.hideCollected and o.collected)
            and not (profile.onlyAffordable and (o.times or 0) < 1)
            and (profile.category == "all" or Offers.Category(o) == profile.category)
            and not (profile.onlyOwned and not ownsEveryToken(o))
        if keep then list[#list + 1] = o end
    end
    return list
end

-- Every offer that takes the given token, unfiltered; for the tooltip of a currency.
function Offers.ForToken(kind, id)
    local found = {}
    for _, vendor in pairs(DB.Vendors()) do
        for _, o in ipairs(vendor.offers or {}) do
            for _, c in ipairs(o.costs) do
                if c.kind == kind and c.id == id then
                    found[#found + 1] = { vendor = vendor, offer = o }
                    break
                end
            end
        end
    end
    return found
end

function Offers.Initialize()
    for _, event in ipairs({ "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "TOYS_UPDATED",
                             "TRANSMOG_COLLECTION_UPDATED", "NEW_RECIPE_LEARNED" }) do
        Addon.RegisterEvent(event, function()
            Offers.InvalidateCollected()
            Journal.Invalidate()
            Addon.Refresh()
        end)
    end
end
