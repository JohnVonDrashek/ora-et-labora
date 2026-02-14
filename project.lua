local Data = require("data")
local UI = require("ui")

local Project = {}
Project.__index = Project

-- Monastic work phases
Project.PHASES = {"planning", "crafting", "chanting", "scribing", "reviewing"}
Project.PHASE_NAMES = {
    planning    = "Planning",
    crafting    = "Crafting",
    chanting    = "Devotions",
    scribing    = "Scribing",
    reviewing   = "Reviewing",
}
Project.PHASE_WEEKS = {
    planning    = 4,
    crafting    = 5,
    chanting    = 4,
    scribing    = 5,
    reviewing   = 3,
}
Project.PHASE_COLORS = {
    planning    = {0.75, 0.60, 0.20},
    crafting    = {0.80, 0.35, 0.50},
    chanting    = {0.40, 0.60, 0.30},
    scribing    = {0.35, 0.50, 0.70},
    reviewing   = {0.70, 0.50, 0.20},
}

-------------------------------------------------------------------------------
-- CREATION
-------------------------------------------------------------------------------
function Project.new(genre, type_, platform, staff)
    local self = setmetatable({}, Project)
    self.genre = genre        -- {name, stats} - work type
    self.type = type_         -- {name, stats} - subject
    self.platform = platform  -- {name, year, cost, share, ...} - patron
    self.staff = staff        -- list of monk objects assigned
    self.title = ""           -- set by player or auto-generated

    -- Work stats (accumulated during production)
    -- Internal: fun=devotion, creativity=wisdom, graphics=beauty, sound=harmony
    self.stats = {
        fun       = 0,
        creativity= 0,
        graphics  = 0,
        sound     = 0,
    }
    self.bugs = 0
    self.bugsFixed = 0

    -- Phase tracking
    self.phaseIndex = 1
    self.phase = Project.PHASES[1]
    self.phaseWeek = 0
    self.totalWeeks = 0
    self.complete = false
    self.released = false

    -- Bonuses
    self.direction = nil -- "fun", "creativity", "graphics", "sound" or nil (balanced)
    self.hypeBonus = 0
    self.itemBonuses = {fun=0, creativity=0, graphics=0, sound=0, speed=0}

    -- Distribution tracking (after completion)
    self.reviews = nil
    self.reviewAvg = 0
    self.totalSales = 0
    self.weeklySales = 0
    self.salesWeek = 0
    self.totalRevenue = 0
    self.unitPrice = 0
    self.salesActive = false

    -- Quality (calculated at end)
    self.quality = 0
    self.compatibility = 0

    -- Particles during work
    self.particles = {}

    return self
end

-------------------------------------------------------------------------------
-- WORK ADVANCEMENT
-------------------------------------------------------------------------------
function Project:advanceWeek()
    if self.complete then return end

    self.phaseWeek = self.phaseWeek + 1
    self.totalWeeks = self.totalWeeks + 1
    local maxWeeks = Project.PHASE_WEEKS[self.phase]
    local speedMul = 1 + (self.itemBonuses.speed / 100)

    -- Monk contributions this week
    for _, s in ipairs(self.staff) do
        if not s.training then
            local contrib = s:getContribution(self.phase)
            self.stats.fun        = self.stats.fun + (contrib.fun or 0)
            self.stats.creativity = self.stats.creativity + (contrib.creativity or 0)
            self.stats.graphics   = self.stats.graphics + (contrib.graphics or 0)
            self.stats.sound      = self.stats.sound + (contrib.sound or 0)

            -- Error fixing in review phase
            if self.phase == "reviewing" and contrib.bugFix then
                self.bugsFixed = self.bugsFixed + contrib.bugFix
            end

            -- Errors accumulate during non-review phases
            if self.phase ~= "reviewing" then
                self.bugs = self.bugs + s:getBugRate() * 0.3
            end

            -- Monks gain experience during work
            s:addExp(3 + s.level)
            s.state = "working"

            -- Spawn particle
            if math.random() < 0.3 then
                self:spawnParticle(contrib)
            end
        end
    end

    -- Apply item bonuses to stats this week
    self.stats.fun        = self.stats.fun + self.itemBonuses.fun * 0.1
    self.stats.creativity = self.stats.creativity + self.itemBonuses.creativity * 0.1
    self.stats.graphics   = self.stats.graphics + self.itemBonuses.graphics * 0.1
    self.stats.sound      = self.stats.sound + self.itemBonuses.sound * 0.1

    -- Apply direction focus multiplier
    if self.direction then
        local dirMul = 1.15
        if self.direction == "fun" then
            self.stats.fun = self.stats.fun * (1 + (dirMul - 1) * 0.1)
        elseif self.direction == "creativity" then
            self.stats.creativity = self.stats.creativity * (1 + (dirMul - 1) * 0.1)
        elseif self.direction == "graphics" then
            self.stats.graphics = self.stats.graphics * (1 + (dirMul - 1) * 0.1)
        elseif self.direction == "sound" then
            self.stats.sound = self.stats.sound * (1 + (dirMul - 1) * 0.1)
        end
    end

    -- Random "divine inspiration" event (10% chance per week)
    self.boostEvent = nil
    if math.random() < 0.10 and #self.staff > 0 then
        local activeStaff = {}
        for _, s in ipairs(self.staff) do
            if not s.training then table.insert(activeStaff, s) end
        end
        if #activeStaff > 0 then
            local boostedStaff = activeStaff[math.random(#activeStaff)]
            local boostAmount = (boostedStaff:getTotalStats() / 4) * 0.5
            local statNames = {"fun", "creativity", "graphics", "sound"}
            local boostedStat = statNames[math.random(#statNames)]
            self.stats[boostedStat] = self.stats[boostedStat] + boostAmount
            self.boostEvent = {
                staffName = boostedStaff.name,
                stat = boostedStat,
                amount = math.floor(boostAmount),
            }
            for j = 1, 5 do
                self:spawnParticle({fun = boostAmount, creativity = 0, graphics = 0, sound = 0})
            end
        end
    end

    -- Advance phase if time is up
    if self.phaseWeek >= math.ceil(maxWeeks / speedMul) then
        self:nextPhase()
    end
end

function Project:nextPhase()
    self.phaseIndex = self.phaseIndex + 1
    self.phaseWeek = 0
    if self.phaseIndex > #Project.PHASES then
        self:finalize()
    else
        self.phase = Project.PHASES[self.phaseIndex]
    end
end

function Project:finalize()
    self.complete = true
    self.phase = "complete"

    -- Apply work type/subject stat multipliers
    self.stats.fun        = self.stats.fun * self.genre.stats.fun * self.type.stats.fun
    self.stats.creativity = self.stats.creativity * self.genre.stats.creativity * self.type.stats.creativity
    self.stats.graphics   = self.stats.graphics * self.genre.stats.graphics * self.type.stats.graphics
    self.stats.sound      = self.stats.sound * self.genre.stats.sound * self.type.stats.sound

    -- Compatibility bonus
    self.compatibility = Data.getCompatibility(self.genre.name, self.type.name)
    local compatMul = 0.6 + (self.compatibility * 0.15)
    self.stats.fun        = self.stats.fun * compatMul
    self.stats.creativity = self.stats.creativity * compatMul
    self.stats.graphics   = self.stats.graphics * compatMul
    self.stats.sound      = self.stats.sound * compatMul

    -- Error penalty
    local effectiveBugs = math.max(0, self.bugs - self.bugsFixed)
    local bugPenalty = 1 - math.min(0.4, effectiveBugs / 200)
    self.stats.fun = self.stats.fun * bugPenalty
    self.stats.creativity = self.stats.creativity * bugPenalty

    -- Calculate overall quality (0-100)
    local rawQuality = (self.stats.fun + self.stats.creativity + self.stats.graphics + self.stats.sound) / 4
    self.quality = math.min(100, math.floor(rawQuality / 5))

    -- Set monks to idle
    for _, s in ipairs(self.staff) do
        s.state = "idle"
    end
end

function Project:spawnParticle(contrib)
    local maxVal = math.max(contrib.fun or 0, contrib.creativity or 0, contrib.graphics or 0, contrib.sound or 0)
    local color
    if maxVal == (contrib.fun or 0) then
        color = {0.75, 0.6, 0.2}   -- gold (devotion)
    elseif maxVal == (contrib.creativity or 0) then
        color = {0.3, 0.5, 0.7}    -- blue (wisdom)
    elseif maxVal == (contrib.graphics or 0) then
        color = {0.8, 0.3, 0.5}    -- rose (beauty)
    else
        color = {0.4, 0.6, 0.3}    -- green (harmony)
    end
    table.insert(self.particles, {
        x = math.random(80, 380),
        y = math.random(100, 220),
        vy = -0.5,
        life = 1.5,
        maxLife = 1.5,
        text = "+" .. math.floor(maxVal),
        color = color,
    })
end

function Project:updateParticles(dt)
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.y = p.y + p.vy
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end
end

function Project:drawParticles()
    UI.setFont("tiny")
    for _, p in ipairs(self.particles) do
        local alpha = math.max(0, p.life / p.maxLife)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.print(p.text, p.x, p.y)
    end
end

-------------------------------------------------------------------------------
-- DISTRIBUTION (Sales)
-------------------------------------------------------------------------------
function Project:generateReviews()
    self.reviews = {}
    for i = 1, 4 do
        local base = self.quality / 10
        local variance = (math.random() - 0.5) * 2
        local compatBonus = (self.compatibility - 2) * 0.3
        local score = math.floor(math.max(1, math.min(10, base + variance + compatBonus)) + 0.5)
        table.insert(self.reviews, {
            name = Data.reviewerNames[i],
            score = score,
        })
    end
    local total = 0
    for _, r in ipairs(self.reviews) do total = total + r.score end
    self.reviewAvg = total / 4
end

function Project:startSales(fans, platformShare)
    self.released = true
    self.salesActive = true
    self.salesWeek = 0

    self.unitPrice = math.floor(30 + self.quality * 0.2)
    local reviewMul = (self.reviewAvg / 5) ^ 1.5
    local baseSales = 300 + fans / 25
    local platMul = 0.5 + (platformShare or 0.2)
    local hypeMul = 1 + (self.hypeBonus / 100)

    self.weeklySales = math.floor(baseSales * reviewMul * platMul * hypeMul * (0.8 + math.random() * 0.4))
end

function Project:updateSales()
    if not self.salesActive then return 0 end

    self.salesWeek = self.salesWeek + 1
    local decay
    if self.salesWeek <= 4 then
        decay = 1.0
    elseif self.salesWeek <= 8 then
        decay = 0.92
    elseif self.salesWeek <= 16 then
        decay = 0.85
    elseif self.salesWeek <= 26 then
        decay = 0.75
    else
        decay = 0.60
    end

    if self.reviewAvg >= 9 then
        decay = decay * 1.2
    elseif self.reviewAvg >= 8 then
        decay = decay * 1.1
    end

    self.weeklySales = math.floor(self.weeklySales * decay)
    if self.weeklySales < 5 then
        self.weeklySales = 0
        self.salesActive = false
    end

    local revenue = self.weeklySales * self.unitPrice
    self.totalSales = self.totalSales + self.weeklySales
    self.totalRevenue = self.totalRevenue + revenue
    return revenue
end

-------------------------------------------------------------------------------
-- QUERIES
-------------------------------------------------------------------------------
function Project:getProgress()
    if self.complete then return 1 end
    local totalPhaseWeeks = 0
    local completedWeeks = 0
    for i, phase in ipairs(Project.PHASES) do
        local pw = Project.PHASE_WEEKS[phase]
        totalPhaseWeeks = totalPhaseWeeks + pw
        if i < self.phaseIndex then
            completedWeeks = completedWeeks + pw
        elseif i == self.phaseIndex then
            completedWeeks = completedWeeks + self.phaseWeek
        end
    end
    return completedWeeks / totalPhaseWeeks
end

function Project:getPhaseName()
    return Project.PHASE_NAMES[self.phase] or self.phase
end

function Project:getPhaseColor()
    return Project.PHASE_COLORS[self.phase] or {0.5, 0.5, 0.5}
end

function Project:getTitle()
    if self.title and #self.title > 0 then
        return self.title
    end
    return self.genre.name .. " " .. self.type.name
end

function Project:getStatsDisplay()
    return {
        {name = "Devotion",  value = math.floor(self.stats.fun),        color = {0.75, 0.6, 0.2}},
        {name = "Wisdom",    value = math.floor(self.stats.creativity), color = {0.3, 0.5, 0.7}},
        {name = "Beauty",    value = math.floor(self.stats.graphics),   color = {0.8, 0.3, 0.5}},
        {name = "Harmony",   value = math.floor(self.stats.sound),      color = {0.4, 0.6, 0.3}},
    }
end

function Project:getCostEstimate()
    local staffCost = 0
    for _, s in ipairs(self.staff) do
        staffCost = staffCost + s.salary
    end
    return math.floor(staffCost * 5 + (self.platform.cost or 0))
end

function Project:applyItem(item)
    if item.effect == "speed" then
        self.itemBonuses.speed = self.itemBonuses.speed + item.amount
    elseif item.effect == "program" then
        self.stats.fun = self.stats.fun + item.amount * 0.5
        self.stats.creativity = self.stats.creativity + item.amount * 0.3
    elseif item.effect == "graphics" then
        self.stats.graphics = self.stats.graphics + item.amount
    elseif item.effect == "sound" then
        self.stats.sound = self.stats.sound + item.amount
    elseif item.effect == "scenario" then
        self.stats.fun = self.stats.fun + item.amount * 0.3
        self.stats.creativity = self.stats.creativity + item.amount * 0.5
    elseif item.effect == "bugs" then
        self.bugsFixed = self.bugsFixed + math.abs(item.amount)
    elseif item.effect == "hype" then
        self.hypeBonus = self.hypeBonus + item.amount
    end
end

return Project
