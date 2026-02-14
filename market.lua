local Data = require("data")
local UI = require("ui")

local Market = {}

-------------------------------------------------------------------------------
-- ABBEY ARCHIVES
-------------------------------------------------------------------------------
Market.hallOfFame = {}

function Market.addToHallOfFame(project)
    table.insert(Market.hallOfFame, {
        title = project:getTitle(),
        genre = project.genre.name,
        type = project.type.name,
        platform = project.platform.name,
        quality = project.quality,
        reviewAvg = project.reviewAvg,
        totalSales = project.totalSales,
        totalRevenue = project.totalRevenue,
        year = 0, -- set by caller
        reviews = project.reviews,
    })
    -- Sort by quality
    table.sort(Market.hallOfFame, function(a, b) return a.quality > b.quality end)
end

-------------------------------------------------------------------------------
-- CHURCH HONORS
-------------------------------------------------------------------------------
function Market.checkAwards(year, releasedThisYear)
    local awards = {}

    if #releasedThisYear == 0 then return awards end

    -- Sort by quality
    local sorted = {}
    for _, p in ipairs(releasedThisYear) do
        table.insert(sorted, p)
    end
    table.sort(sorted, function(a, b) return a.quality > b.quality end)

    -- Work of the Year
    if sorted[1] and sorted[1].quality >= 60 then
        table.insert(awards, {
            name = "Work of the Year",
            game = sorted[1]:getTitle(),
            prize = 100000,
            fans = 50000,
        })
    end

    -- Most Beautiful
    local bestGfx = sorted[1]
    for _, p in ipairs(sorted) do
        if p.stats.graphics > bestGfx.stats.graphics then bestGfx = p end
    end
    if bestGfx.stats.graphics > 200 then
        table.insert(awards, {
            name = "Most Beautiful",
            game = bestGfx:getTitle(),
            prize = 30000,
            fans = 15000,
        })
    end

    -- Finest Harmony
    local bestSnd = sorted[1]
    for _, p in ipairs(sorted) do
        if p.stats.sound > bestSnd.stats.sound then bestSnd = p end
    end
    if bestSnd.stats.sound > 200 then
        table.insert(awards, {
            name = "Finest Harmony",
            game = bestSnd:getTitle(),
            prize = 30000,
            fans = 15000,
        })
    end

    -- Greatest Wisdom
    local bestCre = sorted[1]
    for _, p in ipairs(sorted) do
        if p.stats.creativity > bestCre.stats.creativity then bestCre = p end
    end
    if bestCre.stats.creativity > 200 then
        table.insert(awards, {
            name = "Greatest Wisdom",
            game = bestCre:getTitle(),
            prize = 30000,
            fans = 15000,
        })
    end

    -- Most Influential
    local bestSell = sorted[1]
    for _, p in ipairs(sorted) do
        if p.totalSales > bestSell.totalSales then bestSell = p end
    end
    if bestSell.totalSales > 10000 then
        table.insert(awards, {
            name = "Most Influential",
            game = bestSell:getTitle(),
            prize = 50000,
            fans = 25000,
        })
    end

    return awards
end

-------------------------------------------------------------------------------
-- PATRON MANAGEMENT
-------------------------------------------------------------------------------
function Market.getAvailablePlatforms(year, unlockedPlatforms)
    local available = {}
    for _, p in ipairs(Data.platforms) do
        if year >= p.year and year <= p.maxYear then
            -- Check if already unlocked or if it's free (Local Parish)
            local unlocked = (p.cost == 0)
            for _, up in ipairs(unlockedPlatforms or {}) do
                if up == p.name then unlocked = true break end
            end
            local entry = {
                name = p.name,
                cost = p.cost,
                share = p.share,
                color = p.color,
                unlocked = unlocked,
                year = p.year,
                maxYear = p.maxYear,
            }
            table.insert(available, entry)
        end
    end
    return available
end

function Market.getNewPlatforms(year)
    local newPlatforms = {}
    for _, p in ipairs(Data.platforms) do
        if p.year == year then
            table.insert(newPlatforms, p)
        end
    end
    return newPlatforms
end

function Market.getRetiringPlatforms(year)
    local retiring = {}
    for _, p in ipairs(Data.platforms) do
        if p.maxYear == year then
            table.insert(retiring, p)
        end
    end
    return retiring
end

-------------------------------------------------------------------------------
-- WORK TYPE DEMAND
-------------------------------------------------------------------------------
Market.currentTrend = nil
Market.trendTimer = 0

function Market.updateTrend(year)
    Market.trendTimer = Market.trendTimer - 1
    if Market.trendTimer <= 0 then
        if math.random() < 0.3 then
            local genres = Data.genres
            Market.currentTrend = genres[math.random(#genres)].name
            Market.trendTimer = math.random(8, 16)
        else
            Market.currentTrend = nil
            Market.trendTimer = math.random(4, 8)
        end
    end
end

function Market.getTrendBonus(genreName)
    if Market.currentTrend and Market.currentTrend == genreName then
        return 1.3
    end
    return 1.0
end

-------------------------------------------------------------------------------
-- SALES BOOST EVENTS
-------------------------------------------------------------------------------
Market.salesBoost = 1.0
Market.salesBoostTimer = 0

function Market.updateSalesBoost()
    if Market.salesBoostTimer > 0 then
        Market.salesBoostTimer = Market.salesBoostTimer - 1
        if Market.salesBoostTimer <= 0 then
            Market.salesBoost = 1.0
        end
    end
end

function Market.setSalesBoost(amount, duration)
    Market.salesBoost = amount
    Market.salesBoostTimer = duration
end

return Market
