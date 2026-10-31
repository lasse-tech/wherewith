local _, T = ...

local Wallet = T.Wallet

-- The mount journal's source text names vendor, zone and price for every mount sold
-- for a currency, e.g. "Vendor: X|nZone: Y|nCost: 5,000|T<icon>:0|t". The price
-- icon is matched against the icons of the currencies the character owns. These
-- offers carry no position and are marked as coming from the journal.
local Journal = {}
T.Journal = Journal

local offers

local getFileID = _G.GetFileIDFromPath

local function strip(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1"))
end

local function lines(source)
    local out = {}
    for line in (source .. "|n"):gmatch("(.-)|n") do
        line = strip(line):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then out[#out + 1] = line end
    end
    return out
end

local function valueOf(line)
    return line:match("^[^:]+:%s*(.+)$") or line
end

local function iconIndex()
    local byIcon = {}
    for _, c in ipairs(Wallet.OwnedCurrencies()) do
        local icon = Wallet.Icon(c.kind, c.id)
        if icon then byIcon[icon] = c.id end
    end
    return byIcon
end

local function toFileID(texture)
    local n = tonumber(texture)
    if n then return n end
    if not getFileID then return nil end
    local ok, id = pcall(getFileID, texture)
    return ok and id or nil
end

local function amountOf(text)
    local digits = text:gsub("[^%d]", "")
    return tonumber(digits)
end

-- Every "<amount> <currency icon or link>" pair in a source string.
local function costs(source, byIcon)
    local found = {}
    for amount, id in source:gmatch("([%d%.,]+)%s*|Hcurrency:(%d+)") do
        found[#found + 1] = { kind = "currency", id = tonumber(id), amount = amountOf(amount) }
    end
    for amount, texture in source:gmatch("([%d%.,]+)%s*|T([^:|]+)") do
        local currencyID = byIcon[toFileID(texture) or -1]
        if currencyID then
            found[#found + 1] = { kind = "currency", id = currencyID, amount = amountOf(amount) }
        end
    end
    return found
end

local function read()
    local list = {}
    if not (C_MountJournal and C_MountJournal.GetMountIDs) then return list end
    local byIcon = iconIndex()
    if not next(byIcon) then return list end
    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local _, _, source = C_MountJournal.GetMountInfoExtraByID(mountID)
        if source and (source:find("|T", 1, true) or source:find("|Hcurrency", 1, true)) then
            local found = costs(source, byIcon)
            if #found > 0 then
                local name, spellID, icon, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
                local text = lines(source)
                list[#list + 1] = {
                    kind = "mount", id = mountID, name = name, icon = icon, spellID = spellID,
                    collected = isCollected, costs = found, source = text,
                    vendor = text[1] and valueOf(text[1]), zone = text[2] and valueOf(text[2]),
                }
            end
        end
    end
    return list
end

function Journal.Offers()
    if not offers then offers = read() end
    return offers
end

function Journal.Invalidate()
    offers = nil
end
