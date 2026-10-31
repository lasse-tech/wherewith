local ADDON, T = ...

local function skinWindow(S)
    local window = _G.WherewithFrame
    if not window or window.__elvuiSkinned then return end
    window:StripTextures()
    window:SetTemplate("Transparent")
    if _G.WherewithCloseButton then S:HandleCloseButton(_G.WherewithCloseButton) end
    local bar = _G.WherewithScrollFrame and _G.WherewithScrollFrame.ScrollBar
    if bar and S.HandleScrollBar then S:HandleScrollBar(bar) end
    if _G.WherewithSearchBox and S.HandleEditBox then S:HandleEditBox(_G.WherewithSearchBox) end
    window.__elvuiSkinned = true
end

function T.SkinElvUI()
    if T.ApplyElvUISkin then return T.ApplyElvUISkin() end
    if not _G.ElvUI then return end
    if not T.DB.Profile().elvuiSkin then return end

    local ok, E = pcall(function() return unpack(_G.ElvUI) end)
    if not ok or not E then return end
    local S = E:GetModule("Skins", true)
    if not S then return end

    local function skin()
        if not E.private or not E.private.skins or not E.private.skins.misc
           or not E.private.skins.misc.enable then
            return
        end
        skinWindow(S)
    end

    T.ApplyElvUISkin = skin

    local EP = LibStub("LibElvUIPlugin-1.0", true)
    if EP then
        EP:RegisterPlugin(ADDON, skin)
    else
        skin()
    end
end
