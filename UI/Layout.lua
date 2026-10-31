local _, T = ...
local DB = T.DB
local UI = T.UI

-- Folding headers and rows on a scroll child, drawn from pools.
local Layout = {}
T.Layout = Layout

Layout.INDENT = 16

local HEADER_H, ROW_H = 20, 18
local FOLD_W, ICON = 12, 16
local STATUS_W = 14
local COST_W = 130
local MIDDLE_W = 120

local content, rowPool, headerPool
local y = 0

local function pool(create)
    local items, used = {}, 0
    return {
        acquire = function()
            used = used + 1
            local item = items[used]
            if not item then
                item = create()
                items[used] = item
            end
            item:ClearAllPoints()
            return item
        end,
        releaseAll = function()
            for i = 1, #items do items[i]:Hide() end
            used = 0
        end,
    }
end

local function fontString(parent, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function setColor(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

local function onEnter(self)
    if not DB.Profile().showTooltip or not self.tooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    self.tooltip(GameTooltip)
    GameTooltip:Show()
end

local function onLeave() GameTooltip:Hide() end

local function onClick(self, button)
    if self.onClick then self.onClick(button) end
end

local function createRow()
    local r = CreateFrame("Button", nil, content)
    r:SetHeight(ROW_H)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)

    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ICON, ICON)
    r.icon:SetPoint("LEFT", 0, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    r.status = r:CreateTexture(nil, "ARTWORK")
    r.status:SetSize(STATUS_W, STATUS_W)
    r.status:SetPoint("RIGHT", -2, 0)

    r.right = fontString(r)
    r.right:SetPoint("RIGHT", -STATUS_W - 6, 0)
    r.right:SetWidth(COST_W)
    r.right:SetJustifyH("RIGHT")

    r.middle = fontString(r)
    r.middle:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
    r.middle:SetWidth(MIDDLE_W)

    r.label = fontString(r)
    r.label:SetPoint("LEFT", ICON + 6, 0)

    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", onClick)
    r:SetScript("OnEnter", onEnter)
    r:SetScript("OnLeave", onLeave)
    return r
end

local function createHeader()
    local h = CreateFrame("Button", nil, content)
    h:SetHeight(HEADER_H)
    local bg = h:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.07)
    h.fold = h:CreateTexture(nil, "ARTWORK")
    h.fold:SetSize(FOLD_W, FOLD_W)
    h.fold:SetPoint("LEFT", 2, 0)
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetSize(ICON, ICON)
    h.icon:SetPoint("LEFT", FOLD_W + 6, 0)
    h.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    h.summary = fontString(h)
    h.summary:SetPoint("RIGHT", -4, 0)
    h.summary:SetJustifyH("RIGHT")
    h.label = fontString(h, "GameFontNormal")
    h.label:SetPoint("LEFT", h.icon, "RIGHT", 4, 0)
    h.label:SetPoint("RIGHT", h.summary, "LEFT", -6, 0)
    h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    h:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if self.onRightClick then self.onRightClick() end
            return
        end
        DB.ToggleFold(self.key)
        T.Window.Refresh()
    end)
    h:SetScript("OnEnter", onEnter)
    h:SetScript("OnLeave", onLeave)
    return h
end

function Layout.Begin(parent)
    if not content then
        content = parent
        rowPool = pool(createRow)
        headerPool = pool(createHeader)
    end
    rowPool.releaseAll()
    headerPool.releaseAll()
    y = 0
end

function Layout.Height() return y end
function Layout.Gap(height) y = y + height end

-- spec: key, label, icon, summary, tooltip(tt), onRightClick. Returns whether it is unfolded.
function Layout.Header(spec)
    local h = headerPool.acquire()
    local folded = DB.IsFolded(spec.key)
    h.key = spec.key
    h:SetPoint("TOPLEFT", 0, -y)
    h:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    h.fold:SetTexture(folded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    h.icon:SetTexture(spec.icon or UI.ICON_FALLBACK)
    h.icon:SetShown(spec.icon ~= false)
    h.label:SetText(spec.label or "")
    h.summary:SetText(spec.summary or "")
    h.tooltip = spec.tooltip
    h.onRightClick = spec.onRightClick
    h:Show()
    y = y + HEADER_H + 2
    return not folded
end

-- spec: icon, label, labelColor, middle, right, status, tooltip(tt), onClick(button)
function Layout.Row(spec)
    local r = rowPool.acquire()
    r:SetPoint("TOPLEFT", Layout.INDENT, -y)
    r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    r.icon:SetTexture(spec.icon or UI.ICON_FALLBACK)
    r.icon:SetShown(spec.icon ~= false)
    r.label:SetText(spec.label or "")
    setColor(r.label, spec.labelColor or UI.WHITE)
    r.middle:SetText(spec.middle or "")
    setColor(r.middle, UI.GREY)
    r.middle:SetShown(spec.middle ~= nil)
    r.label:SetPoint("RIGHT", spec.middle and r.middle or r.right, "LEFT", -6, 0)
    r.right:SetText(spec.right or "")
    r.status:SetTexture(spec.status)
    r.status:SetShown(spec.status ~= nil)
    r.tooltip = spec.tooltip
    r.onClick = spec.onClick
    r:Show()
    y = y + ROW_H
end

-- A grey line of text, for empty states.
function Layout.Note(text)
    Layout.Row({ icon = false, label = text, labelColor = UI.GREY })
end
