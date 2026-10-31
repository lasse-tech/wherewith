local ADDON, T = ...

local L = T.L
local DB = T.DB

_G.BINDING_CATEGORY_WHEREWITH    = L["Wherewith"]
_G.BINDING_NAME_WHEREWITH_TOGGLE = L["Toggle Wherewith"]

local Wherewith = T.Addon

local ICON = "Interface\\AddOns\\Wherewith\\Media\\Wherewith"

function Wherewith.OnInitialize()
    DB.Initialize()

    T.SetupOptions()

    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDB then
        Wherewith.launcher = LDB:NewDataObject(ADDON, {
            type = "launcher",
            text = L["Wherewith"],
            icon = ICON,
            OnClick = function(_, button)
                if button == "RightButton" then
                    Wherewith.OpenOptions()
                else
                    T.Window.Toggle()
                end
            end,
            OnTooltipShow = function(tt)
                tt:AddLine(L["Wherewith"])
                tt:AddLine("|cffffff00" .. L["Click"] .. "|r " .. L["Show or hide the window"], 1, 1, 1)
                tt:AddLine("|cffffff00" .. L["Right-Click"] .. "|r " .. L["Options"], 1, 1, 1)
            end,
        })
        if LDBIcon then
            LDBIcon:Register(ADDON, Wherewith.launcher, DB.Profile().minimap)
        end
    end

    Wherewith.RegisterChatCommand("ww", "HandleSlash")
    Wherewith.RegisterChatCommand("wherewith", "HandleSlash")
end

function Wherewith.OnEnable()
    T.Merchant.Initialize()
    T.Offers.Initialize()
    T.Tooltip.Initialize()
    T.Window.Initialize()
    T.SkinElvUI()

    Wherewith.RegisterEvent("CURRENCY_DISPLAY_UPDATE", function(_, currencyID)
        if not currencyID then return end
        T.Wallet.Invalidate()
        T.Journal.Invalidate()
        Wherewith.Refresh()
    end)
    local refresh = function() Wherewith.Refresh() end
    for _, event in ipairs({
        "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_ENABLED",
    }) do
        Wherewith.RegisterEvent(event, refresh)
    end
end

local function countVendors()
    local vendors, offers = 0, 0
    for _, v in pairs(DB.Vendors()) do
        vendors = vendors + 1
        offers = offers + #(v.offers or {})
    end
    return vendors, offers
end

function Wherewith.HandleSlash(input)
    input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local command = input:match("^(%S*)"):lower()
    if command == "config" or command == "options" then
        Wherewith.OpenOptions()
    elseif command == "stats" then
        Wherewith.Print(L["Vendors known: %d, offers: %d"]:format(countVendors()))
    elseif command == "debug" then
        T.Merchant.Dump()
    elseif command == "forget" then
        T.Window.ConfirmForgetAll()
    elseif command == "help" then
        Wherewith.Print("/ww, /ww <" .. L["search"] .. ">, /ww stats, /ww forget, /ww config")
    elseif command == "" then
        T.Window.Toggle()
    else
        T.Window.ShowSearch(input)
    end
end

function Wherewith.OpenOptions()
    T.OpenOptions()
end

local refreshPending = false
function Wherewith.Refresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.3, function()
        refreshPending = false
        T.Window.Refresh()
    end)
end

function Wherewith_Binding()
    T.Window.Toggle()
end

function Wherewith_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then
        Wherewith.OpenOptions()
    else
        T.Window.Toggle()
    end
end
