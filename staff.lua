local Data = require("data")
local UI = require("ui")

local Staff = {}
Staff.__index = Staff

-------------------------------------------------------------------------------
-- CREATION
-------------------------------------------------------------------------------
function Staff.new(data)
    local self = setmetatable({}, Staff)
    self.name = data.name
    self.job = data.job
    self.stats = {
        program  = data.stats.program  or 10,
        scenario = data.stats.scenario or 10,
        graphics = data.stats.graphics or 10,
        sound    = data.stats.sound    or 10,
    }
    self.speed = data.speed or 20
    self.salary = data.salary or 2000
    self.level = data.level or 1
    self.exp = 0
    self.energy = 100
    self.motivation = 100
    self.training = nil -- {type, weeksLeft}
    self.boosted = false
    self.boostTimer = 0

    -- Appearance (random if not provided)
    self.appearance = data.appearance or Staff.randomAppearance()

    -- Position in scriptorium
    self.officeX = 0
    self.officeY = 0
    self.targetX = 0
    self.targetY = 0
    self.walkTimer = 0
    self.animFrame = 0
    self.state = "idle" -- idle, working, walking, training
    self.facing = 1 -- 1=right, -1=left

    return self
end

function Staff.randomAppearance()
    return {
        hairColor  = Data.hairColors[math.random(#Data.hairColors)],
        skinColor  = Data.skinColors[math.random(#Data.skinColors)],
        shirtColor = Data.shirtColors[math.random(#Data.shirtColors)],
        pantsColor = Data.pantsColors[math.random(#Data.pantsColors)],
        hairStyle  = math.random(0, 4),
        gender     = math.random(0, 1), -- 0=brother, 1=sister
    }
end

function Staff.createFromPool(poolEntry)
    local data = {
        name = poolEntry.name,
        job = poolEntry.job,
        stats = {
            program  = poolEntry.stats.program,
            scenario = poolEntry.stats.scenario,
            graphics = poolEntry.stats.graphics,
            sound    = poolEntry.stats.sound,
        },
        speed = poolEntry.speed,
        salary = poolEntry.salary,
        level = poolEntry.level,
    }
    return Staff.new(data)
end

-------------------------------------------------------------------------------
-- STAT METHODS
-- Internal names: program=faith, scenario=wisdom, graphics=beauty, sound=harmony
-------------------------------------------------------------------------------
function Staff:getTotalStats()
    return self.stats.program + self.stats.scenario + self.stats.graphics + self.stats.sound
end

function Staff:getContribution(phase)
    local bonus = Data.jobBonuses[self.job] or {program=1,scenario=1,graphics=1,sound=1}
    local motivMul = 0.5 + (self.motivation / 200)
    local speedMul = self.speed / 50

    if phase == "planning" then
        return {
            fun       = (self.stats.scenario * bonus.scenario * 0.4 + self.stats.program * bonus.program * 0.2) * motivMul * speedMul,
            creativity= (self.stats.scenario * bonus.scenario * 0.5 + self.stats.graphics * bonus.graphics * 0.2) * motivMul * speedMul,
            graphics  = 0,
            sound     = 0,
        }
    elseif phase == "crafting" then
        return {
            fun       = self.stats.graphics * bonus.graphics * 0.1 * motivMul * speedMul,
            creativity= self.stats.graphics * bonus.graphics * 0.2 * motivMul * speedMul,
            graphics  = self.stats.graphics * bonus.graphics * 0.8 * motivMul * speedMul,
            sound     = 0,
        }
    elseif phase == "chanting" then
        return {
            fun       = self.stats.sound * bonus.sound * 0.1 * motivMul * speedMul,
            creativity= self.stats.sound * bonus.sound * 0.1 * motivMul * speedMul,
            graphics  = 0,
            sound     = self.stats.sound * bonus.sound * 0.8 * motivMul * speedMul,
        }
    elseif phase == "scribing" then
        return {
            fun       = self.stats.program * bonus.program * 0.3 * motivMul * speedMul,
            creativity= self.stats.program * bonus.program * 0.1 * motivMul * speedMul,
            graphics  = self.stats.program * bonus.program * 0.1 * motivMul * speedMul,
            sound     = self.stats.program * bonus.program * 0.1 * motivMul * speedMul,
        }
    elseif phase == "reviewing" then
        return {
            fun       = 0,
            creativity= 0,
            graphics  = 0,
            sound     = 0,
            bugFix    = self.stats.program * bonus.program * 0.5 * motivMul * speedMul,
        }
    end
    return {fun=0, creativity=0, graphics=0, sound=0}
end

function Staff:getBugRate()
    local base = 10
    local reduction = self.stats.program / 20
    return math.max(1, base - reduction)
end

-------------------------------------------------------------------------------
-- EXPERIENCE & LEVELING
-------------------------------------------------------------------------------
function Staff:addExp(amount)
    self.exp = self.exp + amount
    local threshold = Data.expThresholds[self.level] or (self.level * 10000)
    if self.exp >= threshold then
        self:levelUp()
        return true
    end
    return false
end

function Staff:getExpProgress()
    local threshold = Data.expThresholds[self.level] or (self.level * 10000)
    return self.exp / threshold
end

function Staff:levelUp()
    self.level = self.level + 1
    self.exp = 0
    local boost = 3 + self.level
    local bonus = Data.jobBonuses[self.job] or {program=1,scenario=1,graphics=1,sound=1}
    self.stats.program  = self.stats.program  + math.floor(boost * bonus.program)
    self.stats.scenario = self.stats.scenario + math.floor(boost * bonus.scenario)
    self.stats.graphics = self.stats.graphics + math.floor(boost * bonus.graphics)
    self.stats.sound    = self.stats.sound    + math.floor(boost * bonus.sound)
    self.speed = self.speed + math.random(1, 3)
    self.salary = math.floor(self.salary * 1.15)
end

-------------------------------------------------------------------------------
-- FORMATION (Training)
-------------------------------------------------------------------------------
function Staff:startTraining(trainingData)
    self.training = {
        name = trainingData.name,
        stat = trainingData.stat,
        amount = trainingData.amount,
        weeksLeft = trainingData.weeks,
    }
    self.state = "training"
end

function Staff:updateTraining()
    if not self.training then return false end
    self.training.weeksLeft = self.training.weeksLeft - 1
    if self.training.weeksLeft <= 0 then
        if self.training.stat == "all" then
            self.stats.program  = self.stats.program  + self.training.amount
            self.stats.scenario = self.stats.scenario + self.training.amount
            self.stats.graphics = self.stats.graphics + self.training.amount
            self.stats.sound    = self.stats.sound    + self.training.amount
        elseif self.training.stat == "random" then
            local stats = {"program", "scenario", "graphics", "sound"}
            local chosen = stats[math.random(#stats)]
            self.stats[chosen] = self.stats[chosen] + self.training.amount
        elseif self.training.stat == "speed" then
            self.speed = self.speed + self.training.amount
        else
            self.stats[self.training.stat] = (self.stats[self.training.stat] or 0) + self.training.amount
        end
        local name = self.training.name
        self.training = nil
        self.state = "idle"
        return true, name
    end
    return false
end

-------------------------------------------------------------------------------
-- WEEKLY UPDATE
-------------------------------------------------------------------------------
function Staff:weeklyUpdate(isWorking)
    if not isWorking then
        self.energy = math.min(100, self.energy + 10)
        self.motivation = math.min(100, self.motivation + 5)
    else
        self.energy = math.max(0, self.energy - 5)
        if self.energy < 20 then
            self.motivation = math.max(0, self.motivation - 10)
        end
    end

    if self.boosted then
        self.boostTimer = self.boostTimer - 1
        if self.boostTimer <= 0 then
            self.boosted = false
        end
    end

    local leveledUp = false
    if isWorking then
        leveledUp = self:addExp(5 + self.level)
    end

    local trained, trainingName = false, nil
    if self.training then
        trained, trainingName = self:updateTraining()
    end
    return trained, trainingName, leveledUp
end

-------------------------------------------------------------------------------
-- DRAWING (monk/nun character in scriptorium)
-------------------------------------------------------------------------------
function Staff:drawCharacter(x, y, scale, animOffset)
    local s = scale or 2
    local a = self.appearance
    animOffset = animOffset or 0

    local bob = 0
    if self.state == "walking" then
        bob = math.sin(animOffset * 8) * 2
    end

    local dir = self.facing

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.ellipse("fill", x, y + 10*s, 5*s, 2*s)

    -- Robe (long monastic habit - goes from shoulders to feet)
    love.graphics.setColor(a.shirtColor)
    love.graphics.rectangle("fill", x - 4*s, y - 3*s + bob, 8*s, 13*s, s, s)

    -- Robe bottom flutter when walking
    if self.state == "walking" then
        local flutter = math.sin(animOffset * 10) * 0.5
        love.graphics.rectangle("fill", x - 4.5*s, y + 8*s + bob, 9*s, 2*s, s, s)
    end

    -- Cord/belt at waist
    love.graphics.setColor(a.pantsColor)
    love.graphics.rectangle("fill", x - 4*s, y + 1*s + bob, 8*s, 1.5*s)
    -- Hanging cord
    love.graphics.rectangle("fill", x - 1*s, y + 2.5*s + bob, 1.5*s, 4*s)

    -- Sleeves / Arms
    love.graphics.setColor(a.shirtColor)
    if self.state == "working" then
        -- Arms forward (writing/crafting)
        love.graphics.rectangle("fill", x - 5.5*s, y - 1*s + bob, 2.5*s, 5*s, s*0.5, s*0.5)
        love.graphics.rectangle("fill", x + 3*s, y - 1*s + bob, 2.5*s, 5*s, s*0.5, s*0.5)
        -- Hands
        love.graphics.setColor(a.skinColor)
        love.graphics.rectangle("fill", x - 5*s, y + 3*s + bob, 1.5*s, 1.5*s)
        love.graphics.rectangle("fill", x + 3.5*s, y + 3*s + bob, 1.5*s, 1.5*s)
    else
        love.graphics.rectangle("fill", x - 5.5*s, y - 2*s + bob, 2.5*s, 6*s, s*0.5, s*0.5)
        love.graphics.rectangle("fill", x + 3*s, y - 2*s + bob, 2.5*s, 6*s, s*0.5, s*0.5)
        -- Hands
        love.graphics.setColor(a.skinColor)
        love.graphics.rectangle("fill", x - 5*s, y + 3*s + bob, 1.5*s, 1.5*s)
        love.graphics.rectangle("fill", x + 3.5*s, y + 3*s + bob, 1.5*s, 1.5*s)
    end

    -- Hood/cowl on shoulders
    love.graphics.setColor(a.shirtColor[1]*0.85, a.shirtColor[2]*0.85, a.shirtColor[3]*0.85)
    love.graphics.rectangle("fill", x - 4.5*s, y - 4*s + bob, 9*s, 2.5*s, s, s)

    -- Head
    love.graphics.setColor(a.skinColor)
    love.graphics.rectangle("fill", x - 3*s, y - 9*s + bob, 6*s, 6*s, s, s)

    -- Tonsure hair (monastic hairstyle)
    love.graphics.setColor(a.hairColor)
    if a.hairStyle == 0 then
        -- Classic tonsure: ring of hair around bald crown
        love.graphics.rectangle("fill", x - 3.5*s, y - 7*s + bob, 7*s, 2*s)
        love.graphics.rectangle("fill", x - 3.5*s, y - 9*s + bob, 1.5*s, 3*s)
        love.graphics.rectangle("fill", x + 2*s, y - 9*s + bob, 1.5*s, 3*s)
        -- Bald top (skin showing)
        love.graphics.setColor(a.skinColor)
        love.graphics.rectangle("fill", x - 1.5*s, y - 10*s + bob, 3*s, 2.5*s, s, s)
    elseif a.hairStyle == 1 then
        -- Celtic tonsure: front of head shaved
        love.graphics.rectangle("fill", x - 3*s, y - 9*s + bob, 6*s, 2*s)
        love.graphics.rectangle("fill", x - 3*s, y - 8*s + bob, 6*s, 4*s)
        love.graphics.setColor(a.skinColor)
        love.graphics.rectangle("fill", x - 2*s, y - 10*s + bob, 4*s, 3*s, s, s)
    elseif a.hairStyle == 2 then
        -- Full tonsure with thin crown ring
        love.graphics.rectangle("fill", x - 3*s, y - 7.5*s + bob, 6*s, 1.5*s)
        love.graphics.rectangle("fill", x - 3*s, y - 9*s + bob, 1*s, 3*s)
        love.graphics.rectangle("fill", x + 2*s, y - 9*s + bob, 1*s, 3*s)
    elseif a.hairStyle == 3 then
        -- Nearly bald (elderly monk)
        love.graphics.rectangle("fill", x - 3*s, y - 7*s + bob, 6*s, 1*s)
        love.graphics.rectangle("fill", x - 3*s, y - 8*s + bob, 1*s, 2*s)
        love.graphics.rectangle("fill", x + 2*s, y - 8*s + bob, 1*s, 2*s)
    elseif a.hairStyle == 4 then
        -- Nun's wimple/veil (for sisters)
        love.graphics.setColor(0.9, 0.88, 0.82) -- white veil
        love.graphics.rectangle("fill", x - 4*s, y - 10*s + bob, 8*s, 4*s, s, s)
        love.graphics.rectangle("fill", x - 4*s, y - 7*s + bob, 2*s, 5*s)
        love.graphics.rectangle("fill", x + 2*s, y - 7*s + bob, 2*s, 5*s)
        -- Band
        love.graphics.setColor(a.shirtColor)
        love.graphics.rectangle("fill", x - 4*s, y - 7*s + bob, 8*s, 1*s)
    end

    -- Eyes
    love.graphics.setColor(0.1, 0.1, 0.1)
    if self.state == "training" then
        -- Closed eyes (praying/studying)
        love.graphics.rectangle("fill", x - 2*s, y - 6*s + bob, 1.5*s, 0.5*s)
        love.graphics.rectangle("fill", x + 0.5*s, y - 6*s + bob, 1.5*s, 0.5*s)
    else
        love.graphics.rectangle("fill", x - 2*s, y - 7*s + bob, 1.2*s, 1.2*s)
        love.graphics.rectangle("fill", x + 0.8*s, y - 7*s + bob, 1.2*s, 1.2*s)
    end

    -- Mouth
    if self.motivation > 70 then
        love.graphics.setColor(0.7, 0.35, 0.3)
        love.graphics.rectangle("fill", x - 1*s, y - 4.5*s + bob, 2*s, 0.8*s)
    elseif self.motivation < 30 then
        love.graphics.setColor(0.5, 0.3, 0.3)
        love.graphics.rectangle("fill", x - 1*s, y - 4*s + bob, 2*s, 0.5*s)
    end

    -- Prayer bubble when working
    if self.state == "working" and math.sin(animOffset * 3) > 0.7 then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("fill", x + 4*s, y - 12*s, 1.5*s)
        love.graphics.circle("fill", x + 6*s, y - 14*s, 2*s)
        love.graphics.ellipse("fill", x + 8*s, y - 17*s, 4*s, 3*s)
        love.graphics.setColor(UI.colors.text)
        UI.setFont("tiny")
        local thoughts = {"+", "~", "*", "#", "!"}
        love.graphics.print(thoughts[math.floor(animOffset) % #thoughts + 1], x + 6.5*s, y - 18.5*s)
    end

    -- Formation indicator
    if self.state == "training" then
        love.graphics.setColor(UI.colors.accent)
        UI.setFont("tiny")
        love.graphics.print("STUDY", x - 5*s, y - 14*s)
    end

    -- Cross for level 3+
    if self.level >= 3 then
        love.graphics.setColor(UI.colors.gold)
        love.graphics.rectangle("fill", x + 3*s, y - 11*s + bob, 1*s, 3*s)
        love.graphics.rectangle("fill", x + 2.5*s, y - 10*s + bob, 2*s, 1*s)
    end
end

-------------------------------------------------------------------------------
-- DRAW STAT BARS (for UI panels)
-------------------------------------------------------------------------------
function Staff:drawStatCard(x, y, w, selected)
    local h = 52
    if selected then
        love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], 0.15)
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    end

    -- Name and vocation
    love.graphics.setColor(UI.colors.text)
    UI.setFont("normal")
    love.graphics.print(self.name, x + 40, y + 2)
    love.graphics.setColor(UI.colors.textLight)
    UI.setFont("tiny")
    love.graphics.print("Lv." .. self.level .. " " .. self.job, x + 40, y + 17)
    love.graphics.print("Upkeep: " .. UI.formatMoney(self.salary) .. "/mo", x + 40, y + 28)

    -- Mini character
    self:drawCharacter(x + 18, y + 36, 1.2, love.timer.getTime())

    -- Stat bars (Faith/Wisdom/Beauty/Harmony)
    local barX = x + 140
    local barW = w - 155
    local stats = {
        {"FTH", self.stats.program,  {0.7, 0.55, 0.2}},
        {"WIS", self.stats.scenario, {0.3, 0.5, 0.7}},
        {"BTY", self.stats.graphics, {0.8, 0.3, 0.5}},
        {"HAR", self.stats.sound,    {0.4, 0.6, 0.3}},
    }
    for i, stat in ipairs(stats) do
        local sy = y + 2 + (i-1) * 12
        love.graphics.setColor(UI.colors.textLight)
        UI.setFont("tiny")
        love.graphics.print(stat[1], barX, sy)
        UI.drawProgressBar(barX + 24, sy + 2, barW - 50, 7, math.min(1, stat[2] / 150), stat[3])
        love.graphics.setColor(UI.colors.text)
        love.graphics.print(tostring(math.floor(stat[2])), barX + barW - 22, sy)
    end

    -- Formation status
    if self.training then
        love.graphics.setColor(UI.colors.warning)
        UI.setFont("tiny")
        love.graphics.print("Formation: " .. self.training.name .. " (" .. self.training.weeksLeft .. "w)", x + 40, y + 40)
    end
end

return Staff
