local Save = {}

local SAVE_FILE = "oraetlabora_save.dat"

-------------------------------------------------------------------------------
-- SERIALIZATION (simple Lua table serializer)
-------------------------------------------------------------------------------
local function serialize(val, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)
    local t = type(val)

    if t == "nil" then
        return "nil"
    elseif t == "boolean" then
        return tostring(val)
    elseif t == "number" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "table" then
        local parts = {}
        local isArray = #val > 0
        table.insert(parts, "{\n")
        if isArray then
            for i, v in ipairs(val) do
                table.insert(parts, pad .. "  " .. serialize(v, indent + 1) .. ",\n")
            end
        else
            for k, v in pairs(val) do
                if type(k) == "string" then
                    table.insert(parts, pad .. "  [" .. string.format("%q", k) .. "] = " .. serialize(v, indent + 1) .. ",\n")
                elseif type(k) == "number" then
                    table.insert(parts, pad .. "  [" .. k .. "] = " .. serialize(v, indent + 1) .. ",\n")
                end
            end
        end
        table.insert(parts, pad .. "}")
        return table.concat(parts)
    end
    return "nil"
end

local function deserialize(str)
    local fn, err = load("return " .. str)
    if fn then
        local ok, result = pcall(fn)
        if ok then return result end
    end
    return nil
end

-------------------------------------------------------------------------------
-- SAVE GAME STATE
-------------------------------------------------------------------------------
function Save.saveGame(game)
    local data = {}

    -- Monastery
    data.companyName = game.companyName
    data.money = game.money
    data.fans = game.fans
    data.totalRevenue = game.totalRevenue

    -- Time
    data.year = game.year
    data.week = game.week

    -- Brothers & Sisters
    data.staff = {}
    for _, s in ipairs(game.staff) do
        table.insert(data.staff, {
            name = s.name,
            job = s.job,
            stats = {
                program = s.stats.program,
                scenario = s.stats.scenario,
                graphics = s.stats.graphics,
                sound = s.stats.sound,
            },
            speed = s.speed,
            salary = s.salary,
            level = s.level,
            exp = s.exp,
            energy = s.energy,
            motivation = s.motivation,
            appearance = s.appearance,
        })
    end

    -- Unlocked platforms
    data.unlockedPlatforms = game.unlockedPlatforms

    -- Available work types/subjects (store names)
    data.genreNames = {}
    for _, g in ipairs(game.availableGenres) do
        table.insert(data.genreNames, g.name)
    end
    data.typeNames = {}
    for _, t in ipairs(game.availableTypes) do
        table.insert(data.typeNames, t.name)
    end
    data.researchedGenres = game.researchedGenres
    data.researchedTypes = game.researchedTypes

    -- Inventory
    data.inventory = game.inventory

    -- Stats
    data.gamesReleased = game.gamesReleased
    data.contractsCompleted = game.contractsCompleted
    data.awardsWon = game.awardsWon

    -- Abbey Archives
    local Market = require("market")
    data.hallOfFame = Market.hallOfFame

    local str = serialize(data)
    local success, message = love.filesystem.write(SAVE_FILE, str)
    return success, message
end

-------------------------------------------------------------------------------
-- LOAD GAME STATE
-------------------------------------------------------------------------------
function Save.loadGame()
    if not love.filesystem.getInfo(SAVE_FILE) then
        return nil, "No save file found"
    end

    local contents, err = love.filesystem.read(SAVE_FILE)
    if not contents then
        return nil, "Failed to read save file"
    end

    local data = deserialize(contents)
    if not data then
        return nil, "Failed to parse save data"
    end

    return data
end

-------------------------------------------------------------------------------
-- APPLY LOADED DATA TO GAME
-------------------------------------------------------------------------------
function Save.applyToGame(game, data)
    local Data = require("data")
    local Staff = require("staff")
    local Market = require("market")

    game.companyName = data.companyName
    game.money = data.money
    game.fans = data.fans
    game.totalRevenue = data.totalRevenue or 0
    game.year = data.year
    game.week = data.week

    -- Restore staff
    game.staff = {}
    for _, sd in ipairs(data.staff or {}) do
        local s = Staff.new(sd)
        s.exp = sd.exp or 0
        s.energy = sd.energy or 100
        s.motivation = sd.motivation or 100
        table.insert(game.staff, s)
    end

    -- Patrons
    game.unlockedPlatforms = data.unlockedPlatforms or {"Local Parish"}

    -- Work Types & Subjects - rebuild from names
    game.availableGenres = {}
    local allGenres = {}
    for _, g in ipairs(Data.genres) do allGenres[g.name] = g end
    for _, rg in ipairs(Data.researchGenres) do allGenres[rg.name] = rg end
    for _, name in ipairs(data.genreNames or {}) do
        if allGenres[name] then
            table.insert(game.availableGenres, allGenres[name])
        end
    end
    if #game.availableGenres == 0 then
        for _, g in ipairs(Data.genres) do
            table.insert(game.availableGenres, g)
        end
    end

    game.availableTypes = {}
    local allTypes = {}
    for _, t in ipairs(Data.types) do allTypes[t.name] = t end
    for _, rt in ipairs(Data.researchTypes) do allTypes[rt.name] = rt end
    for _, name in ipairs(data.typeNames or {}) do
        if allTypes[name] then
            table.insert(game.availableTypes, allTypes[name])
        end
    end
    if #game.availableTypes == 0 then
        for _, t in ipairs(Data.types) do
            table.insert(game.availableTypes, t)
        end
    end

    game.researchedGenres = data.researchedGenres or {}
    game.researchedTypes = data.researchedTypes or {}
    game.inventory = data.inventory or {}
    game.gamesReleased = data.gamesReleased or 0
    game.contractsCompleted = data.contractsCompleted or 0
    game.awardsWon = data.awardsWon or {}

    -- Abbey Archives
    Market.hallOfFame = data.hallOfFame or {}

    -- Refresh recruit pool
    game:refreshHirePool()
end

-------------------------------------------------------------------------------
-- CHECK IF SAVE EXISTS
-------------------------------------------------------------------------------
function Save.hasSave()
    return love.filesystem.getInfo(SAVE_FILE) ~= nil
end

function Save.deleteSave()
    love.filesystem.remove(SAVE_FILE)
end

return Save
