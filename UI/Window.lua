local _, T = ...
local L = T.L
local DB = T.DB
local UI = T.UI
local Layout = T.Layout
local Wallet = T.Wallet
local Offers = T.Offers
local Waypoint = T.Waypoint
local Addon = T.Addon

local Window = {}
T.Window = Window

local WIDTH, HEIGHT = 500, 480
local PAD, TITLE_H, TOOLBAR_H, FOOTER_H = 8, 24, 24, 20
local SCROLLBAR_W = 26

local frame

-- Tooltip -------------------------------------------------------------------

local function costLines(tt, offer)
    UI.AddLine(tt, L["Price"], UI.GOLD)
    for _, c in ipairs(offer.costs) do
        local have, extra = Wallet.Amount(c.kind, c.id)
        local enough = have and have >= c.amount
        local left = UI.TokenIcon(c.kind, c.id) .. " " .. (Wallet.Name(c.kind, c.id) or "?")
        local right = UI.Number(c.amount) .. " / " .. (have and UI.Number(have) or "?")
        if extra and extra > 0 then right = right .. UI.Colored(UI.GREY, " (+" .. UI.Number(extra) .. ")") end
        local rc = enough and UI.GREEN or UI.RED
        tt:AddDoubleLine(left, right, 1, 1, 1, rc[1], rc[2], rc[3])
    end
    if offer.gold then
        local enough = GetMoney() >= offer.gold
        local rc = enough and UI.GREEN or UI.RED
        tt:AddDoubleLine(L["Gold"], GetCoinTextureString(offer.gold), 1, 1, 1, rc[1], rc[2], rc[3])
    end
end

local function offerTooltip(offer)
    return function(tt)
        if offer.kind == "item" then
            tt:SetItemByID(offer.id)
        elseif offer.kind == "currency" then
            tt:SetCurrencyByID(offer.id)
        elseif offer.spellID and tt.SetMountBySpellID then
            tt:SetMountBySpellID(offer.spellID)
        else
            tt:SetText(offer.name or "?")
        end
        tt:AddLine(" ")
        if offer.origin == "journal" then
            UI.AddLine(tt, L["From the mount journal - no position known"], UI.BLUE)
            for _, line in ipairs(offer.source or {}) do UI.AddLine(tt, line, UI.GREY, true) end
        else
            tt:AddDoubleLine(L["Vendor"], offer.vendor or "?", 1, 0.82, 0, 1, 1, 1)
            local where = offer.zone or "?"
            if offer.sub and offer.sub ~= offer.zone then where = offer.sub .. ", " .. where end
            local coords = UI.Coords(offer)
            if coords then where = where .. " (" .. coords .. ")" end
            tt:AddDoubleLine(L["Where"], where, 1, 0.82, 0, 1, 1, 1)
        end
        if offer.qty then tt:AddDoubleLine(L["Quantity"], offer.qty, 1, 0.82, 0, 1, 1, 1) end
        tt:AddLine(" ")
        costLines(tt, offer)
        if offer.times and offer.times >= 1 then
            UI.AddLine(tt, L["Purchases possible now: %d"]:format(offer.times), UI.GREEN)
        end
        if offer.collected then UI.AddLine(tt, L["Already collected"], UI.GREY) end
        if offer.seen then
            UI.AddLine(tt, L["Last seen: %s"]:format(date("%Y-%m-%d", offer.seen)), UI.GREY)
        end
        tt:AddLine(" ")
        if Waypoint.Possible(offer) then UI.AddLine(tt, L["Click: set a waypoint"], UI.GREY) end
        UI.AddLine(tt, L["Shift-click: link in chat, Ctrl-click: try on"], UI.GREY)
    end
end

local function offerLink(offer)
    if offer.kind == "mount" then
        return offer.spellID and C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(offer.spellID)
    end
    return Wallet.Link(offer.kind, offer.id)
end

local function offerClick(offer)
    return function()
        if IsShiftKeyDown() or Addon.ShiftDown() then
            local link = offerLink(offer)
            if link then ChatEdit_InsertLink(link) end
        elseif IsControlKeyDown() then
            if offer.kind == "mount" then
                if DressUpMount then DressUpMount(offer.id) end
            elseif offer.kind == "item" then
                local link = Wallet.Link("item", offer.id)
                if link then DressUpItemLink(link) end
            end
        elseif Waypoint.Possible(offer) then
            Waypoint.Set(offer)
        end
    end
end

-- Rows ----------------------------------------------------------------------

local function offerIcon(offer)
    if offer.kind == "mount" then return offer.icon end
    return Wallet.Icon(offer.kind, offer.id)
end

local function offerLabel(offer)
    local name = offer.name or L["Loading..."]
    if offer.qty then name = name .. " x" .. offer.qty end
    return name
end

local function offerColor(offer)
    if offer.collected then return UI.GREY end
    if offer.kind == "mount" then return UI.QualityColor(4) end
    return UI.QualityColor(Wallet.Quality(offer.kind, offer.id))
end

local function offerRow(offer, middle)
    Layout.Row({
        icon = offerIcon(offer),
        label = offerLabel(offer),
        labelColor = offerColor(offer),
        middle = middle,
        right = UI.CostText(offer),
        status = (offer.times or 0) >= 1 and UI.READY or nil,
        tooltip = offerTooltip(offer),
        onClick = offerClick(offer),
    })
end

local function byAffordThenName(a, b)
    local fa, fb = (a.times or 0) >= 1, (b.times or 0) >= 1
    if fa ~= fb then return fa end
    return (a.name or "") < (b.name or "")
end

-- Grouped by currency ---------------------------------------------------------

local function amountOf(offer, kind, id)
    for _, c in ipairs(offer.costs) do
        if c.kind == kind and c.id == id then return c.amount end
    end
    return 0
end

local function tokenTooltip(kind, id, extraLine)
    return function(tt)
        if kind == "currency" then tt:SetCurrencyByID(id) else tt:SetItemByID(id) end
        if extraLine then
            tt:AddLine(" ")
            UI.AddLine(tt, extraLine, UI.GREY, true)
        end
    end
end

local function drawByCurrency(list, searching)
    local groups, order = {}, {}
    for _, o in ipairs(list) do
        for _, c in ipairs(o.costs) do
            local key = Wallet.Key(c.kind, c.id)
            if not groups[key] then
                groups[key] = { kind = c.kind, id = c.id, offers = {}, name = Wallet.Name(c.kind, c.id) or "?" }
                order[#order + 1] = key
            end
            local g = groups[key].offers
            g[#g + 1] = o
        end
    end
    table.sort(order, function(a, b) return groups[a].name < groups[b].name end)

    for _, key in ipairs(order) do
        local g = groups[key]
        local affordable = 0
        for _, o in ipairs(g.offers) do
            if (o.times or 0) >= 1 then affordable = affordable + 1 end
        end
        local have = Wallet.Amount(g.kind, g.id)
        local summary = (have and UI.Number(have) or "?") .. " " .. UI.TokenIcon(g.kind, g.id)
            .. UI.Colored(UI.GREY, "   " .. L["%d/%d affordable"]:format(affordable, #g.offers))
        if Layout.Header({
            key = "c:" .. key, label = g.name, icon = Wallet.Icon(g.kind, g.id), summary = summary,
            tooltip = tokenTooltip(g.kind, g.id),
        }) then
            table.sort(g.offers, function(a, b)
                local fa, fb = (a.times or 0) >= 1, (b.times or 0) >= 1
                if fa ~= fb then return fa end
                local pa, pb = amountOf(a, g.kind, g.id), amountOf(b, g.kind, g.id)
                if pa ~= pb then return pa < pb end
                return (a.name or "") < (b.name or "")
            end)
            for _, o in ipairs(g.offers) do offerRow(o, o.vendor) end
        end
        Layout.Gap(2)
    end

    if searching or DB.Profile().onlyAffordable or DB.Profile().category ~= "all" then return end

    local unknown = {}
    for _, c in ipairs(Wallet.OwnedCurrencies()) do
        if not groups[c.key] then unknown[#unknown + 1] = c end
    end
    if #unknown == 0 then return end
    for _, c in ipairs(unknown) do c.name = Wallet.Name(c.kind, c.id) or "?" end
    table.sort(unknown, function(a, b) return a.name < b.name end)

    Layout.Gap(6)
    if Layout.Header({
        key = "unknown", label = L["No vendor known yet"], icon = false,
        summary = UI.Colored(UI.GREY, #unknown),
        tooltip = function(tt)
            tt:SetText(L["No vendor known yet"], 1, 1, 1)
            UI.AddLine(tt, L["Currencies you own whose vendors you have not visited since installing Wherewith. "
                .. "Their tooltip often says where to spend them."], UI.GREY, true)
        end,
    }) then
        for _, c in ipairs(unknown) do
            local have = Wallet.Amount(c.kind, c.id)
            Layout.Row({
                icon = Wallet.Icon(c.kind, c.id),
                label = c.name,
                labelColor = UI.QualityColor(Wallet.Quality(c.kind, c.id)),
                right = have and UI.Number(have) or "?",
                tooltip = tokenTooltip(c.kind, c.id, L["Open its vendor once and Wherewith knows the offers."]),
                onClick = function()
                    if IsShiftKeyDown() or Addon.ShiftDown() then
                        local link = Wallet.Link(c.kind, c.id)
                        if link then ChatEdit_InsertLink(link) end
                    end
                end,
            })
        end
    end
end

-- Grouped by vendor -------------------------------------------------------------

local function drawByVendor(list)
    local groups, order = {}, {}
    for _, o in ipairs(list) do
        local key = o.vendorKey
        if not groups[key] then
            groups[key] = { vendor = o.vendor or "?", zone = o.zone or "", journal = o.origin == "journal",
                            vendorKey = o.vendorKey, offers = {}, sample = o }
            order[#order + 1] = key
        end
        local g = groups[key].offers
        g[#g + 1] = o
    end
    table.sort(order, function(a, b)
        local ga, gb = groups[a], groups[b]
        if ga.journal ~= gb.journal then return gb.journal end
        if ga.zone ~= gb.zone then return ga.zone < gb.zone end
        return ga.vendor < gb.vendor
    end)

    for _, key in ipairs(order) do
        local g = groups[key]
        local affordable = 0
        for _, o in ipairs(g.offers) do
            if (o.times or 0) >= 1 then affordable = affordable + 1 end
        end
        local summary = UI.Colored(UI.GREY, g.zone .. "   " .. L["%d/%d affordable"]:format(affordable, #g.offers))
        if Layout.Header({
            key = "v:" .. key, label = g.vendor, icon = false, summary = summary,
            tooltip = function(tt)
                tt:SetText(g.vendor, 1, 1, 1)
                if g.journal then
                    UI.AddLine(tt, L["From the mount journal - no position known"], UI.BLUE)
                else
                    local coords = UI.Coords(g.sample)
                    UI.AddLine(tt, g.zone .. (coords and " (" .. coords .. ")" or ""), UI.GREY)
                    UI.AddLine(tt, L["Right-click: forget this vendor"], UI.GREY)
                end
            end,
            onRightClick = not g.journal and function() Window.ConfirmForgetVendor(g.vendorKey, g.vendor) end or nil,
        }) then
            table.sort(g.offers, byAffordThenName)
            for _, o in ipairs(g.offers) do offerRow(o) end
        end
        Layout.Gap(2)
    end
end

-- Frame ---------------------------------------------------------------------

local function styleToggle(button, active)
    local c = active and UI.GOLD or UI.GREY
    button.text:SetTextColor(c[1], c[2], c[3])
    button.line:SetShown(active)
end

local function createToggle(text, onClick)
    local b = CreateFrame("Button", nil, frame)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetSize(math.max(28, b.text:GetStringWidth() + 10), 18)
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetColorTexture(UI.GOLD[1], UI.GOLD[2], UI.GOLD[3], 0.8)
    b.line:SetHeight(1)
    b.line:SetPoint("BOTTOMLEFT", 4, 0)
    b.line:SetPoint("BOTTOMRIGHT", -4, 0)
    b:SetScript("OnClick", function()
        onClick()
        Window.Refresh()
    end)
    return b
end

local function profileToggle(text, field)
    return createToggle(text, function()
        local p = DB.Profile()
        p[field] = not p[field]
    end)
end

local function groupToggle(text, value)
    return createToggle(text, function() DB.Profile().groupBy = value end)
end

local function create()
    frame = CreateFrame("Frame", "WherewithFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")
    frame:SetScript("OnDragStart", function(self)
        if not DB.Profile().locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left, top = self:GetLeft(), self:GetTop()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        DB.SaveWindowPos("TOPLEFT", "BOTTOMLEFT", left, top)
    end)
    frame:SetScript("OnHide", function() DB.SetWindowShown(false) end)
    local flat = "Interface\\Buttons\\WHITE8X8"
    frame:SetBackdrop({ bgFile = flat, edgeFile = flat, edgeSize = 1 })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(0, 0, 0, 1)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("TOPLEFT", PAD, -5)
    icon:SetTexture("Interface\\AddOns\\Wherewith\\Media\\Wherewith")
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    title:SetText(L["Wherewith"])

    local close = CreateFrame("Button", "WherewithCloseButton", frame, "UIPanelCloseButtonNoScripts")
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() Window.SetShown(false) end)

    local options = CreateFrame("Button", nil, frame)
    options:SetSize(16, 16)
    options:SetPoint("RIGHT", close, "LEFT", -2, 0)
    options:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    options:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    options:SetScript("OnClick", function() Addon.OpenOptions() end)

    frame.search = CreateFrame("EditBox", "WherewithSearchBox", frame, "SearchBoxTemplate")
    frame.search:SetSize(130, 20)
    frame.search:SetPoint("TOPLEFT", PAD + 6, -TITLE_H - 2)
    frame.search:SetAutoFocus(false)
    frame.search:HookScript("OnTextChanged", function() Window.Refresh() end)

    frame.category = CreateFrame("DropdownButton", "WherewithCategoryDropdown", frame, "WowStyle1DropdownTemplate")
    frame.category:SetWidth(130)
    frame.category:SetPoint("LEFT", frame.search, "RIGHT", 8, 0)
    frame.category:SetupMenu(function(_, root)
        local function isSelected(key) return DB.Profile().category == key end
        local function choose(key)
            DB.Profile().category = key
            Window.Refresh()
        end
        root:CreateRadio(L["All"], isSelected, choose, "all")
        for _, c in ipairs(Offers.Categories()) do
            root:CreateRadio(c.name, isSelected, choose, c.key)
        end
    end)

    frame.hideCollected = profileToggle(L["Hide collected"], "hideCollected")
    frame.hideCollected:SetPoint("TOPRIGHT", -PAD, -TITLE_H - 3)
    frame.affordable = profileToggle(L["Affordable"], "onlyAffordable")
    frame.affordable:SetPoint("RIGHT", frame.hideCollected, "LEFT", -2, 0)
    frame.byVendor = groupToggle(L["By vendor"], "vendor")
    frame.byVendor:SetPoint("RIGHT", options, "LEFT", -8, 0)
    frame.byCurrency = groupToggle(L["By currency"], "currency")
    frame.byCurrency:SetPoint("RIGHT", frame.byVendor, "LEFT", 0, 0)

    local scroll = CreateFrame("ScrollFrame", "WherewithScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PAD, -TITLE_H - TOOLBAR_H - 6)
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR_W - PAD + 4, FOOTER_H + 4)
    frame.content = CreateFrame("Frame", nil, scroll)
    frame.content:SetSize(WIDTH - 2 * PAD - SCROLLBAR_W, 1)
    scroll:SetScrollChild(frame.content)
    frame.scroll = scroll

    frame.empty = frame.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.empty:SetPoint("TOPLEFT", 8, -8)
    frame.empty:SetWidth(frame.content:GetWidth() - 16)
    frame.empty:SetJustifyH("LEFT")
    frame.empty:SetSpacing(3)

    frame.footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.footer:SetPoint("BOTTOMLEFT", PAD, 7)
    frame.footer:SetPoint("BOTTOMRIGHT", -PAD, 7)
    frame.footer:SetJustifyH("LEFT")

    tinsert(UISpecialFrames, "WherewithFrame")
    frame:Hide()
end

local function place()
    local pos = DB.WindowPos()
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

function Window.Initialize()
    if frame then return end
    create()
    place()
    if DB.WindowShown() then frame:Show() end
    Window.Refresh()
end

function Window.SetShown(shown)
    DB.SetWindowShown(shown)
    frame:SetShown(shown)
    Window.Refresh()
end

function Window.Toggle()
    Window.SetShown(not frame:IsShown())
end

function Window.ShowSearch(text)
    Window.SetShown(true)
    frame.search:SetText(text or "")
end

local function countVendors()
    local n = 0
    for _ in pairs(DB.Vendors()) do n = n + 1 end
    return n
end

function Window.Refresh()
    if not frame or not frame:IsShown() then return end
    local p = DB.Profile()
    styleToggle(frame.byCurrency, p.groupBy ~= "vendor")
    styleToggle(frame.byVendor, p.groupBy == "vendor")
    styleToggle(frame.affordable, p.onlyAffordable)
    styleToggle(frame.hideCollected, p.hideCollected)
    frame.category:GenerateMenu()

    if p.category ~= "all" then
        local known = false
        for _, c in ipairs(Offers.Categories()) do
            if c.key == p.category then known = true end
        end
        if not known then p.category = "all" end
    end

    local search = frame.search:GetText()
    local searching = search ~= nil and search ~= ""
    local list = Offers.List(search)
    local vendors = countVendors()

    local message
    if vendors == 0 then
        message = L["No vendor offers learned yet."] .. "\n\n"
            .. L["Open any vendor that takes currencies or tokens. Wherewith remembers its offers and where it "
            .. "stands, for all your characters."]
    elseif #list == 0 then
        message = L["Nothing matches the current filters."]
    end
    frame.empty:SetText(message or "")

    Layout.Begin(frame.content)
    if message then Layout.Gap(frame.empty:GetStringHeight() + 20) end
    if p.groupBy == "vendor" then
        drawByVendor(list)
    else
        drawByCurrency(list, searching)
    end
    frame.content:SetHeight(math.max(1, Layout.Height()))

    frame.footer:SetText(L["Vendors known: %d - open a vendor to learn its offers"]:format(vendors))
end

-- Forgetting ------------------------------------------------------------------

StaticPopupDialogs["WHEREWITH_FORGET_VENDOR"] = {
    text = L["Forget the offers of %s?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, key)
        DB.ForgetVendor(key)
        Window.Refresh()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

StaticPopupDialogs["WHEREWITH_FORGET_ALL"] = {
    text = L["Forget all vendors Wherewith has learned (%d), for every character?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        DB.ForgetAllVendors()
        Window.Refresh()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

function Window.ConfirmForgetVendor(key, name)
    StaticPopup_Show("WHEREWITH_FORGET_VENDOR", name, nil, key)
end

function Window.ConfirmForgetAll()
    local n = countVendors()
    if n == 0 then
        Addon.Print(L["No vendors learned yet."])
        return
    end
    StaticPopup_Show("WHEREWITH_FORGET_ALL", n)
end
