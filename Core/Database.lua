local _, T = ...

T.dbDefaults = {
    profile = {
        groupBy       = "currency",  -- currency | vendor
        onlyOwned     = true,
        onlyAffordable = false,
        hideCollected = true,
        category      = "all",       -- all | currency | class:<id> | misc:<subclass id>
        showJournal   = true,
        showTooltip   = true,
        currencyTooltip = true,
        locked        = false,
        elvuiSkin     = true,
        minimap       = { hide = false },
        window        = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0, shown = false },
    },
    char = {
        fold = { unknown = true },
    },
}

local SCHEMA = 1

local DB = {}
T.DB = DB

local function copyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            copyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function DB.Initialize()
    local sv = _G.WherewithDB
    if type(sv) ~= "table" then
        sv = {}
        _G.WherewithDB = sv
    end
    sv.schema = SCHEMA

    local charKey = (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")

    sv.profileKeys = sv.profileKeys or {}
    local profileKey = sv.profileKeys[charKey] or "Default"
    sv.profileKeys[charKey] = profileKey

    sv.profiles = sv.profiles or {}
    sv.profiles[profileKey] = sv.profiles[profileKey] or {}
    sv.char = sv.char or {}
    sv.char[charKey] = sv.char[charKey] or {}
    -- Account-wide: what one character learns at a vendor holds for all of them.
    sv.vendors = sv.vendors or {}

    local db = { profile = sv.profiles[profileKey], char = sv.char[charKey], vendors = sv.vendors }
    copyDefaults(db.profile, T.dbDefaults.profile)
    copyDefaults(db.char, T.dbDefaults.char)

    T.Addon.db = db
    return db
end

function DB.Profile() return T.Addon.db.profile end
function DB.Char()    return T.Addon.db.char end
function DB.Vendors() return T.Addon.db.vendors end

function DB.IsFolded(key) return DB.Char().fold[key] == true end
function DB.ToggleFold(key)
    local fold = DB.Char().fold
    fold[key] = not fold[key]
end

function DB.WindowPos() return DB.Profile().window end
function DB.WindowShown() return DB.Profile().window.shown == true end
function DB.SetWindowShown(shown) DB.Profile().window.shown = shown and true or false end
function DB.SaveWindowPos(point, relPoint, x, y)
    local w = DB.Profile().window
    w.point, w.relPoint, w.x, w.y = point, relPoint, x, y
end

function DB.ForgetVendor(npcID)
    DB.Vendors()[npcID] = nil
end

function DB.ForgetAllVendors()
    wipe(DB.Vendors())
end
