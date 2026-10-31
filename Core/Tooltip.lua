local _, T = ...

local L = T.L
local Addon = T.Addon
local DB = T.DB
local Offers = T.Offers

-- Adds a short "spend it at" block to currency tooltips (currency panel, bags, links)
-- and to item tooltips of items vendors take in payment.
local Tooltip = {}
T.Tooltip = Tooltip

local MAX_VENDORS = 4

-- The post-call fires several times per tooltip; remembered outside the Blizzard frame.
local written = setmetatable({}, { __mode = "k" })

local function add(tooltip, kind, id)
    if not DB.Profile().currencyTooltip then return end
    if not Addon.Usable(id) then return end
    local key = kind .. id
    if written[tooltip] == key then return end

    local found = Offers.ForToken(kind, id)
    if #found == 0 then return end
    written[tooltip] = key

    local byVendor, order = {}, {}
    local affordable = 0
    for _, f in ipairs(found) do
        local name = f.vendor.name or L["Vendor"]
        if not byVendor[name] then
            byVendor[name] = { count = 0, zone = Offers.ZoneName(f.vendor.map) }
            order[#order + 1] = name
        end
        byVendor[name].count = byVendor[name].count + 1
        if (Offers.Times(f.offer) or 0) >= 1 then affordable = affordable + 1 end
    end
    table.sort(order, function(a, b) return byVendor[a].count > byVendor[b].count end)

    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(L["Wherewith"], L["Offers: %d, affordable: %d"]:format(#found, affordable),
        0.2, 0.8, 1, 1, 1, 1)
    for i, name in ipairs(order) do
        if i > MAX_VENDORS then
            tooltip:AddLine(L["... and %d more"]:format(#order - MAX_VENDORS), 0.6, 0.6, 0.6)
            break
        end
        local v = byVendor[name]
        tooltip:AddDoubleLine(name, (v.zone or "") .. "  " .. v.count, 1, 0.82, 0, 0.8, 0.8, 0.8)
    end
    tooltip:Show()
end

function Tooltip.Initialize()
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then return end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Currency, function(tooltip, data)
        if data and data.id then add(tooltip, "currency", data.id) end
    end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if data and data.id then add(tooltip, "item", data.id) end
    end)
    for _, tt in ipairs({ GameTooltip, _G.ItemRefTooltip }) do
        if tt then tt:HookScript("OnTooltipCleared", function(self) written[self] = nil end) end
    end
end
