local _, T = ...

local Wallet = T.Wallet

local UI = {}
T.UI = UI

UI.GOLD  = { 1, 0.82, 0 }
UI.GREY  = { 0.6, 0.6, 0.6 }
UI.WHITE = { 1, 1, 1 }
UI.GREEN = { 0.25, 1, 0.25 }
UI.RED   = { 1, 0.3, 0.3 }
UI.BLUE  = { 0.2, 0.8, 1 }

UI.READY = "Interface\\RaidFrame\\ReadyCheck-Ready"
UI.NOT   = "Interface\\RaidFrame\\ReadyCheck-NotReady"
UI.ICON_FALLBACK = 134400   -- INV_Misc_QuestionMark

function UI.Hex(c)
    return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end

function UI.Colored(c, text)
    return UI.Hex(c) .. text .. "|r"
end

function UI.AddLine(tt, text, c, wrap)
    tt:AddLine(text, c[1], c[2], c[3], wrap)
end

function UI.QualityColor(quality)
    local c = quality and ITEM_QUALITY_COLORS[quality]
    return c and { c.r, c.g, c.b } or UI.WHITE
end

function UI.Number(n)
    return BreakUpLargeNumbers(n)
end

function UI.TokenIcon(kind, id, size)
    return ("|T%s:%d|t"):format(Wallet.Icon(kind, id) or UI.ICON_FALLBACK, size or 0)
end

-- "450 [icon]  20 [icon]", each part red when the character has too little of it
function UI.CostText(offer, size)
    local parts = {}
    for _, c in ipairs(offer.costs) do
        local have = Wallet.Amount(c.kind, c.id)
        local color = (have and have >= c.amount) and UI.WHITE or UI.RED
        parts[#parts + 1] = UI.Colored(color, UI.Number(c.amount)) .. " " .. UI.TokenIcon(c.kind, c.id, size)
    end
    if offer.gold then
        parts[#parts + 1] = GetCoinTextureString(offer.gold)
    end
    return table.concat(parts, "  ")
end

function UI.Coords(offer)
    if not (offer.x and offer.y) then return nil end
    return ("%.1f, %.1f"):format(offer.x * 100, offer.y * 100)
end
