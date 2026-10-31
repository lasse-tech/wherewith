local ADDON, T = ...
local L = T.L
local DB = T.DB

local category, layout

local ABOUT_TEMPLATE = "WherewithAboutTemplate"
local ABOUT_FONT = "GameFontHighlight"
local ABOUT_BOTTOM_PAD = 8

-- The game font has no heart glyph.
local CHIP_TEXT = "Made with <3 in Europe"
local CHIP_GAP = 6
local CHIP_HEIGHT = 18
local CHIP_PAD_X = 8

WherewithAboutMixin = {}

function WherewithAboutMixin:Init(initializer)
    self.Text:SetText(initializer:GetData().text)

    local chip = self.Chip
    chip.Label:SetText(CHIP_TEXT)
    chip:ClearAllPoints()
    chip:SetPoint("TOPLEFT", self.Text, "BOTTOMLEFT", 0, -CHIP_GAP)
    chip:SetSize(math.ceil(chip.Label:GetStringWidth()) + 2 * CHIP_PAD_X, CHIP_HEIGHT)
end

local function metadata(field)
    local value = C_AddOns.GetAddOnMetadata(ADDON, field)
    return value ~= "" and value or nil
end

local function aboutText()
    local lines = {}

    local author = metadata("Author")
    if author then lines[#lines + 1] = L["Author: %s"]:format(author) end

    local website = metadata("X-Website")
    if website then lines[#lines + 1] = L["More: %s"]:format((website:gsub("^%a+://", ""))) end

    local version = metadata("Version")
    if version then lines[#lines + 1] = L["Version: %s"]:format(version) end

    local copyright = metadata("X-Copyright")
    if copyright then lines[#lines + 1] = "\194\169 " .. copyright end

    local license = metadata("X-License")
    if license then lines[#lines + 1] = L["License: %s"]:format(license) end

    lines[#lines + 1] = L["Data: learned from the vendors you visit, and the mount journal"]

    return table.concat(lines, "\n")
end

local measure

local function textHeight(text)
    if not measure then
        measure = CreateFrame("Frame"):CreateFontString(nil, "ARTWORK", ABOUT_FONT)
        measure:SetJustifyH("LEFT")
        measure:Hide()
    end
    measure:SetText(text)
    return measure:GetStringHeight()
end

local function addAbout()
    local text = aboutText()
    if text == "" then return end

    local initializer = Settings.CreateElementInitializer(ABOUT_TEMPLATE, { text = text })
    local extent = math.ceil(textHeight(text)) + CHIP_GAP + CHIP_HEIGHT + ABOUT_BOTTOM_PAD
    -- The settings list sizes rows by GetExtent().
    initializer.GetExtent = function() return extent end
    layout:AddInitializer(initializer)
end

local function refresh()
    T.Addon.Refresh()
end

local function profileSetting(variableKey, variableType, name, default)
    return Settings.RegisterAddOnSetting(category, ADDON .. "_" .. variableKey, variableKey,
        DB.Profile(), variableType, name, default)
end

function T.SetupOptions()
    if category then return end

    category, layout = Settings.RegisterVerticalLayoutCategory(L["Wherewith"])

    addAbout()

    do
        local setting = profileSetting("groupBy", Settings.VarType.String, L["Group by"], "currency")
        setting:SetValueChangedCallback(refresh)
        Settings.CreateDropdown(category, setting, function()
            local container = Settings.CreateControlTextContainer()
            container:Add("currency", L["By currency"])
            container:Add("vendor", L["By vendor"])
            return container:GetData()
        end, L["List the offers under the currency they cost, or under the vendor who sells them."])
    end

    local toggles = {
        { "onlyOwned", L["Only what I can pay with"], true,
          L["Hide offers that cost a currency or item you have none of."] },
        { "onlyAffordable", L["Only affordable"], false,
          L["Hide offers you cannot buy right now."] },
        { "hideCollected", L["Hide collected"], true,
          L["Hide mounts, pets, toys, appearances and recipes you already have."] },
        { "showJournal", L["Mounts from the journal"], true,
          L["Also list currency mounts the mount journal names, before you have visited their vendor."] },
        { "showTooltip", L["Show tooltips"], true,
          L["Show the item, vendor, position and price when hovering a row."] },
        { "currencyTooltip", L["Extend currency tooltips"], true,
          L["Add the known vendors and offers to the tooltip of a currency or token."] },
        { "locked", L["Lock window"], false,
          L["Keep the window from being dragged."] },
    }
    for _, t in ipairs(toggles) do
        local setting = profileSetting(t[1], Settings.VarType.Boolean, t[2], t[3])
        setting:SetValueChangedCallback(refresh)
        Settings.CreateCheckbox(category, setting, t[4])
    end

    do
        local proxy = { showMinimap = not DB.Profile().minimap.hide }
        local setting = Settings.RegisterAddOnSetting(category, ADDON .. "_showMinimap", "showMinimap",
            proxy, Settings.VarType.Boolean, L["Show minimap button"], true)
        setting:SetValueChangedCallback(function(_, value)
            DB.Profile().minimap.hide = not value
            local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
            if not LDBIcon then return end
            if value then LDBIcon:Show(ADDON) else LDBIcon:Hide(ADDON) end
        end)
        Settings.CreateCheckbox(category, setting)
    end

    do
        local setting = profileSetting("elvuiSkin", Settings.VarType.Boolean,
            L["Allow ElvUI to skin this addon"], true)
        Settings.CreateCheckbox(category, setting, L["Requires a /reload to take effect."])
    end

    Settings.RegisterAddOnCategory(category)
end

function T.OpenOptions()
    Settings.OpenToCategory(category:GetID())
end
