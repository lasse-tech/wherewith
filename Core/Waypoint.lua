local _, T = ...

local L = T.L
local Addon = T.Addon

local Waypoint = {}
T.Waypoint = Waypoint

function Waypoint.Possible(offer)
    return offer.map ~= nil and offer.x ~= nil and offer.y ~= nil
end

-- TomTom when it is loaded, the game's own map pin otherwise.
function Waypoint.Set(offer)
    if not Waypoint.Possible(offer) then
        Addon.Print(L["No position known for this vendor."])
        return
    end
    local title = offer.vendor or L["Vendor"]
    local tomtom = _G.TomTom
    if tomtom and tomtom.AddWaypoint then
        tomtom:AddWaypoint(offer.map, offer.x, offer.y, { title = title, from = "Wherewith" })
    elseif C_Map.CanSetUserWaypointOnMap(offer.map) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(offer.map, offer.x, offer.y))
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    else
        Addon.Print(L["The game allows no waypoint on this map."])
        return
    end
    Addon.Print(L["Waypoint set: %s, %s (%.1f, %.1f)"]:format(title, offer.zone or "?", offer.x * 100, offer.y * 100))
end
