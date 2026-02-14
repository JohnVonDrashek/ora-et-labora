local Data = require("data")
local UI = require("ui")
local Staff = require("staff")
local Project = require("project")
local Market = require("market")
local Office = require("office")
local Audio = require("audio")

local Game = {}
Game.__index = Game

local WEEK_DURATION = 1.5 -- seconds per week at 1x speed
local MAX_STAFF = 6
local MAX_YEAR = 20
local STARTING_MONEY = 50000
local STARTING_FANS = 0

-------------------------------------------------------------------------------
-- CREATION
-------------------------------------------------------------------------------
function Game.new(companyName)
    local self = setmetatable({}, Game)

    -- Monastery
    self.companyName = companyName or "New Abbey"
    self.money = STARTING_MONEY
    self.fans = STARTING_FANS  -- renown
    self.totalRevenue = 0

    -- Time
    self.year = 1
    self.week = 1
    self.weekTimer = WEEK_DURATION
    self.speed = 1
    self.paused = false

    -- Brothers & sisters
    self.staff = {}
    self.hirePool = {}
    self:refreshHirePool()

    -- Add 2 starter monks
    local starters = {}
    for _, s in ipairs(Data.staffPool) do
        if s.level == 1 then table.insert(starters, s) end
    end
    for i = 1, math.min(2, #starters) do
        local idx = math.random(#starters)
        table.insert(self.staff, Staff.createFromPool(starters[idx]))
        table.remove(starters, idx)
    end

    -- Works (projects)
    self.currentProject = nil
    self.releasedGames = {}
    self.releasedThisYear = {}
    self.gamesReleased = 0

    -- Commissions (contracts)
    self.currentContract = nil
    self.contractsCompleted = 0

    -- Provisions (inventory)
    self.inventory = {}

    -- Studies (research)
    self.availableGenres = {}
    for _, g in ipairs(Data.genres) do
        table.insert(self.availableGenres, g)
    end
    self.availableTypes = {}
    for _, t in ipairs(Data.types) do
        table.insert(self.availableTypes, t)
    end
    self.researchedGenres = {}
    self.researchedTypes = {}

    -- Patrons (platforms)
    self.unlockedPlatforms = {"Local Parish"}

    -- Events
    self.activeEvents = {}
    self.eventCooldown = 0

    -- Honors history
    self.awardsWon = {}

    -- UI State
    self.dialog = nil
    self.subDialog = nil
    self.buttons = {}
    self.selectedStaff = {}
    self.devStep = 0
    self.devGenre = nil
    self.devType = nil
    self.devPlatform = nil
    self.gameNameInput = nil

    -- Speed buttons
    self.speedButtons = {
        UI.Button.new("||", 404, 2, 17, 16, function() self.paused = not self.paused end, {fontSize="tiny"}),
        UI.Button.new(">",  423, 2, 17, 16, function() self.speed = 1; self.paused = false end, {fontSize="tiny"}),
        UI.Button.new(">>", 442, 2, 17, 16, function() self.speed = 2; self.paused = false end, {fontSize="tiny"}),
        UI.Button.new(">>>",461, 2, 17, 16, function() self.speed = 3; self.paused = false end, {fontSize="tiny"}),
    }

    -- Confetti particles
    self.confetti = {}

    -- Money float texts
    self.moneyFloats = {}

    -- Action buttons (bottom bar)
    local btnY = 252
    local btnW = 72
    local btnH = 26
    local btnSpacing = 4
    local startX = 14
    self.actionButtons = {
        UI.Button.new("Create", startX, btnY, btnW, btnH, function() self:startDevelopment() end, {fontSize="small"}),
        UI.Button.new("Commission", startX + (btnW+btnSpacing), btnY, btnW, btnH, function() self:openContractDialog() end, {fontSize="small"}),
        UI.Button.new("Brothers", startX + 2*(btnW+btnSpacing), btnY, btnW, btnH, function() self:openStaffDialog() end, {fontSize="small"}),
        UI.Button.new("Studies", startX + 3*(btnW+btnSpacing), btnY, btnW, btnH, function() self:openResearchDialog() end, {fontSize="small"}),
        UI.Button.new("Provisions", startX + 4*(btnW+btnSpacing), btnY, btnW, btnH, function() self:openItemDialog() end, {fontSize="small"}),
        UI.Button.new("Archives", startX + 5*(btnW+btnSpacing), btnY, 52, btnH, function() self:openHallOfFame() end, {fontSize="small"}),
    }

    -- Scriptorium
    self.office = Office.new()

    -- Game over
    self.gameOver = false

    -- Patron announcement queue
    self.platformAnnouncements = {}

    return self
end

-------------------------------------------------------------------------------
-- MAIN UPDATE LOOP
-------------------------------------------------------------------------------
function Game:update(dt)
    if self.gameOver then return end

    -- Update UI
    local mx, my = self:getMousePos()
    for _, b in ipairs(self.speedButtons) do b:update(mx, my) end
    for _, b in ipairs(self.actionButtons) do b:update(mx, my) end

    if self.dialog then
        self.dialog:update(dt, mx, my)
        if not self.dialog:isOpen() then
            self.dialog = nil
        end
    end
    if self.subDialog then
        self.subDialog:update(dt, mx, my)
        if not self.subDialog:isOpen() then
            self.subDialog = nil
        end
    end

    UI.updateToasts(dt)

    -- Time progression
    if not self.paused and not self.dialog and not self.subDialog then
        self.weekTimer = self.weekTimer - dt * self.speed
        if self.weekTimer <= 0 then
            self:advanceWeek()
            self.weekTimer = WEEK_DURATION
        end
    end

    -- Confetti & money floats
    self:updateConfetti(dt)
    self:updateMoneyFloats(dt)

    -- Scriptorium animation
    self.office:update(dt, self.staff, self.currentProject)

    -- Name input
    if self.gameNameInput then
        self.gameNameInput:update(dt)
    end
end

function Game:getMousePos()
    local mx, my = love.mouse.getPosition()
    local w, h = love.graphics.getDimensions()
    mx = mx / (w / 480)
    my = my / (h / 320)
    return mx, my
end

-------------------------------------------------------------------------------
-- WEEK ADVANCEMENT
-------------------------------------------------------------------------------
function Game:advanceWeek()
    self.week = self.week + 1

    -- Monthly upkeep payment
    if self.week % 4 == 0 then
        local totalSalary = 0
        for _, s in ipairs(self.staff) do
            totalSalary = totalSalary + s.salary
        end
        if totalSalary > 0 then
            self.money = self.money - totalSalary
            self:addMoneyFloat(-totalSalary)
        end
    end

    -- New year
    if self.week > 52 then
        self.week = 1
        self:yearEnd()
        self.year = self.year + 1

        if self.year > MAX_YEAR then
            self:triggerGameOver()
            return
        end

        -- Check for new patron arrivals
        self:checkNewPlatforms()
    end

    -- Advance current work
    if self.currentProject and not self.currentProject.complete then
        self.currentProject:advanceWeek()
        -- Check for divine inspiration event
        if self.currentProject.boostEvent then
            local ev = self.currentProject.boostEvent
            Audio.play("levelup")
            UI.addToast(ev.staffName .. " received divine inspiration! +" .. ev.amount .. " " .. ev.stat, 3, UI.colors.gold)
        end
        if self.currentProject.complete then
            self:onProjectComplete()
        end
    end

    -- Advance commission
    if self.currentContract then
        self.currentContract.weeksLeft = self.currentContract.weeksLeft - 1
        if self.currentContract.weeksLeft <= 0 then
            self:onContractComplete()
        end
    end

    -- Update distribution for completed works
    local weekRevenue = 0
    for _, work in ipairs(self.releasedGames) do
        weekRevenue = weekRevenue + work:updateSales()
    end
    if weekRevenue > 0 then
        weekRevenue = math.floor(weekRevenue * Market.salesBoost)
        self.money = self.money + weekRevenue
        self.totalRevenue = self.totalRevenue + weekRevenue
        if self.week % 4 == 0 then
            self:addMoneyFloat(weekRevenue * 4)
        end
    end

    -- Staff weekly updates
    for _, s in ipairs(self.staff) do
        local isWorking = self.currentProject ~= nil and not self.currentProject.complete
        local trained, trainingName, leveledUp = s:weeklyUpdate(isWorking)
        if trained then
            Audio.play("success")
            UI.addToast(s.name .. " completed " .. trainingName .. "!", 3, UI.colors.success)
        end
        if leveledUp then
            Audio.play("levelup")
            UI.addToast(s.name .. " advanced to Lv." .. s.level .. "!", 3, UI.colors.gold)
        end
    end

    -- Market updates
    Market.updateSalesBoost()
    if self.week % 4 == 0 then
        Market.updateTrend(self.year)
    end

    -- Random events
    self:checkRandomEvents()

    -- Event cooldown
    if self.eventCooldown > 0 then
        self.eventCooldown = self.eventCooldown - 1
    end

    -- Check bankruptcy
    if self.money < -100000 then
        self:triggerGameOver()
    end
end

-------------------------------------------------------------------------------
-- YEAR END
-------------------------------------------------------------------------------
function Game:yearEnd()
    -- Honor ceremony
    if #self.releasedThisYear > 0 then
        local awards = Market.checkAwards(self.year, self.releasedThisYear)
        if #awards > 0 then
            self.paused = true
            self:spawnConfetti(60)
            Audio.play("fanfare")
            self:openAwardDialog(awards)
            for _, award in ipairs(awards) do
                self.money = self.money + award.prize
                self.fans = self.fans + award.fans
                table.insert(self.awardsWon, {
                    name = award.name,
                    game = award.game,
                    year = self.year,
                })
            end
        end
    end

    self.releasedThisYear = {}

    -- Auto-save at year end
    local Save = require("save")
    Save.saveGame(self)

    -- Refresh candidates
    self:refreshHirePool()

    -- Patron retirement check
    local retiring = Market.getRetiringPlatforms(self.year)
    for _, p in ipairs(retiring) do
        UI.addToast(p.name .. " has withdrawn patronage!", 4, UI.colors.warning)
    end
end

-------------------------------------------------------------------------------
-- WORK CREATION (Development)
-------------------------------------------------------------------------------
function Game:startDevelopment()
    if self.currentProject then
        UI.addToast("Already working on a creation!", 2, UI.colors.danger)
        return
    end
    if self.currentContract then
        UI.addToast("Finish the commission first!", 2, UI.colors.danger)
        return
    end
    if #self.staff == 0 then
        UI.addToast("Recruit some brothers first!", 2, UI.colors.danger)
        return
    end
    self.devStep = 1
    self:openGenreDialog()
end

function Game:openGenreDialog()
    local items = {}
    for _, g in ipairs(self.availableGenres) do
        table.insert(items, g)
    end

    local list = UI.ScrollList.new(30, 48, 420, 212, 28, items, {
        renderItem = function(item, x, y, w, h, selected)
            love.graphics.setColor(UI.colors.text)
            UI.setFont("normal")
            love.graphics.print(item.name, x + 8, y + 5)
            love.graphics.setColor(UI.colors.textLight)
            UI.setFont("tiny")
            local info = string.format("Dev:%.1f Wis:%.1f Bty:%.1f Har:%.1f",
                item.stats.fun, item.stats.creativity, item.stats.graphics, item.stats.sound)
            love.graphics.print(info, x + 8, y + 18)
        end,
    })

    self.dialog = UI.Dialog.new("Choose Work Type", 20, 15, 440, 290)
    self.dialog.scrollList = list
    self.dialog:addButton("Next", function()
        local selected = list:getSelected()
        if selected then
            self.devGenre = selected
            self.dialog:close()
            self.devStep = 2
            self:openTypeDialog()
        end
    end, {color = UI.colors.accent, textColor = UI.colors.textWhite, width = 70})
    self.dialog:addButton("Cancel", function()
        self.dialog:close()
        self.devStep = 0
    end, {width = 70})
end

function Game:openTypeDialog()
    local items = {}
    for _, t in ipairs(self.availableTypes) do
        local compat = Data.getCompatibility(self.devGenre.name, t.name)
        table.insert(items, {typeData = t, compat = compat, name = t.name})
    end
    table.sort(items, function(a, b) return a.compat > b.compat end)

    local list = UI.ScrollList.new(30, 48, 420, 212, 28, items, {
        renderItem = function(item, x, y, w, h, selected)
            love.graphics.setColor(UI.colors.text)
            UI.setFont("normal")
            love.graphics.print(item.name, x + 8, y + 5)
            -- Compatibility stars
            local starColors = {UI.colors.danger, UI.colors.warning, UI.colors.textLight, UI.colors.success, UI.colors.gold}
            local color = starColors[item.compat] or UI.colors.textLight
            love.graphics.setColor(color)
            UI.setFont("tiny")
            local stars = string.rep("*", item.compat)
            love.graphics.print("Match: " .. stars, x + 8, y + 18)
        end,
    })

    self.dialog = UI.Dialog.new("Choose Subject (" .. self.devGenre.name .. ")", 20, 15, 440, 290)
    self.dialog.scrollList = list
    self.dialog:addButton("Next", function()
        local selected = list:getSelected()
        if selected then
            self.devType = selected.typeData
            self.dialog:close()
            self.devStep = 3
            self:openPlatformDialog()
        end
    end, {color = UI.colors.accent, textColor = UI.colors.textWhite, width = 70})
    self.dialog:addButton("Back", function()
        self.dialog:close()
        self.devStep = 1
        self:openGenreDialog()
    end, {width = 70})
end

function Game:openPlatformDialog()
    local platforms = Market.getAvailablePlatforms(self.year, self.unlockedPlatforms)

    local list = UI.ScrollList.new(30, 48, 420, 212, 34, platforms, {
        renderItem = function(item, x, y, w, h, selected)
            love.graphics.setColor(item.color or UI.colors.text)
            UI.setFont("normal")
            love.graphics.print(item.name, x + 8, y + 2)
            love.graphics.setColor(UI.colors.textLight)
            UI.setFont("tiny")
            if item.unlocked then
                love.graphics.print("Influence: " .. math.floor(item.share * 100) .. "%  Patron secured", x + 8, y + 17)
            else
                love.graphics.setColor(UI.colors.danger)
                love.graphics.print("Tithe: " .. UI.formatMoney(item.cost), x + 8, y + 17)
            end
        end,
    })

    self.dialog = UI.Dialog.new("Choose Patron", 20, 15, 440, 290)
    self.dialog.scrollList = list
    self.dialog:addButton("Next", function()
        local selected = list:getSelected()
        if selected then
            if not selected.unlocked then
                if self.money >= selected.cost then
                    self.money = self.money - selected.cost
                    table.insert(self.unlockedPlatforms, selected.name)
                    selected.unlocked = true
                    UI.addToast("Secured patronage of " .. selected.name .. "!", 2, UI.colors.success)
                else
                    UI.addToast("Not enough gold for the tithe!", 2, UI.colors.danger)
                    return
                end
            end
            self.devPlatform = selected
            self.dialog:close()
            self.devStep = 4
            self:openNameDialog()
        end
    end, {color = UI.colors.accent, textColor = UI.colors.textWhite, width = 70})
    self.dialog:addButton("Back", function()
        self.dialog:close()
        self.devStep = 2
        self:openTypeDialog()
    end, {width = 70})
end

function Game:openNameDialog()
    local dlgX, dlgY, dlgW, dlgH = 20, 10, 440, 300
    self.gameNameInput = UI.TextInput.new(dlgX + 20, dlgY + 60, dlgW - 40, 26, {
        placeholder = "Name your work...",
        default = self.devGenre.name .. " " .. self.devType.name,
        maxLen = 24,
    })

    local staffCheckboxes = {}
    for i, s in ipairs(self.staff) do
        if not s.training then
            table.insert(staffCheckboxes, {staff = s, index = i, selected = i <= 4})
        end
    end

    local directions = {"balanced", "fun", "creativity", "graphics", "sound"}
    local dirLabels = {balanced="Balanced", fun="Devotion", creativity="Wisdom", graphics="Beauty", sound="Harmony"}
    local dirColors = {
        balanced   = UI.colors.textLight,
        fun        = {0.75, 0.6, 0.2},
        creativity = {0.3, 0.5, 0.7},
        graphics   = {0.8, 0.3, 0.5},
        sound      = {0.4, 0.6, 0.3},
    }
    local selectedDir = "balanced"

    self.dialog = UI.Dialog.new("Name Your Work", dlgX, dlgY, dlgW, dlgH)
    self.dialog.content = ""
    self.dialog.staffCheckboxes = staffCheckboxes
    self.dialog.selectedDir = selectedDir
    local cbX = dlgX + 20
    local cbStartY = dlgY + 138
    self.dialog.customDraw = function(dlg)
        -- Title label
        love.graphics.setColor(UI.colors.text)
        UI.setFont("small")
        love.graphics.print("Work Title:", dlgX + 20, dlgY + 44)

        -- Draw name input
        self.gameNameInput:draw()

        -- Work type/subject/patron summary
        love.graphics.setColor(UI.colors.textLight)
        UI.setFont("tiny")
        love.graphics.print(self.devGenre.name .. " x " .. self.devType.name .. " | " .. self.devPlatform.name, dlgX + 20, dlgY + 92)

        -- Direction choice
        love.graphics.setColor(UI.colors.text)
        UI.setFont("small")
        love.graphics.print("Focus:", cbX, dlgY + 106)
        local dirBtnW = 48
        for i, dir in ipairs(directions) do
            local dx = cbX + (i-1) * (dirBtnW + 2)
            local dy = dlgY + 120
            local isSelected = dlg.selectedDir == dir
            if isSelected then
                love.graphics.setColor(dirColors[dir])
                love.graphics.rectangle("fill", dx, dy, dirBtnW, 14, 3, 3)
                love.graphics.setColor(1, 1, 1)
            else
                love.graphics.setColor(UI.colors.panelDark)
                love.graphics.rectangle("fill", dx, dy, dirBtnW, 14, 3, 3)
                love.graphics.setColor(UI.colors.textLight)
            end
            UI.setFont("tiny")
            love.graphics.printf(dirLabels[dir], dx, dy + 2, dirBtnW, "center")
        end

        -- Staff assignment
        love.graphics.setColor(UI.colors.text)
        UI.setFont("small")
        love.graphics.print("Assign Brothers:", cbX, cbStartY - 14)

        for i, sc in ipairs(dlg.staffCheckboxes) do
            local y = cbStartY + (i-1) * 18
            love.graphics.setColor(UI.colors.panelBorder)
            love.graphics.rectangle("line", cbX, y, 12, 12, 2, 2)
            if sc.selected then
                love.graphics.setColor(UI.colors.accent)
                love.graphics.rectangle("fill", cbX + 2, y + 2, 8, 8, 1, 1)
            end
            love.graphics.setColor(UI.colors.text)
            UI.setFont("tiny")
            love.graphics.print(sc.staff.name, cbX + 18, y + 1)
            love.graphics.setColor(UI.colors.textLight)
            love.graphics.print(sc.staff.job .. " Lv." .. sc.staff.level, cbX + 80, y + 1)
            love.graphics.print(string.format("F:%d W:%d B:%d H:%d",
                math.floor(sc.staff.stats.program), math.floor(sc.staff.stats.scenario),
                math.floor(sc.staff.stats.graphics), math.floor(sc.staff.stats.sound)),
                cbX + 155, y + 1)
        end
    end
    self.dialog.customClick = function(dlg, mx, my)
        -- Direction buttons
        local dirBtnW = 48
        for i, dir in ipairs(directions) do
            local dx = cbX + (i-1) * (dirBtnW + 2)
            local dy = dlgY + 120
            if mx >= dx and mx <= dx + dirBtnW and my >= dy and my <= dy + 14 then
                dlg.selectedDir = dir
                return true
            end
        end
        -- Staff checkboxes
        for i, sc in ipairs(dlg.staffCheckboxes) do
            local y = cbStartY + (i-1) * 18
            if mx >= cbX and mx <= cbX + 12 and my >= y and my <= y + 12 then
                sc.selected = not sc.selected
                return true
            end
        end
        return false
    end

    self.dialog:addButton("Begin Work", function()
        local assignedStaff = {}
        for _, sc in ipairs(self.dialog.staffCheckboxes) do
            if sc.selected then
                table.insert(assignedStaff, sc.staff)
            end
        end
        if #assignedStaff == 0 then
            UI.addToast("Assign at least one brother!", 2, UI.colors.danger)
            return
        end
        local platformData = nil
        for _, p in ipairs(Data.platforms) do
            if p.name == self.devPlatform.name then platformData = p break end
        end
        self.currentProject = Project.new(self.devGenre, self.devType, platformData or self.devPlatform, assignedStaff)
        self.currentProject.title = self.gameNameInput:getText()
        self.currentProject.direction = self.dialog.selectedDir ~= "balanced" and self.dialog.selectedDir or nil
        self.gameNameInput = nil
        self.dialog:close()
        self.devStep = 0
        Audio.play("start")
        UI.addToast("Work begun: " .. self.currentProject:getTitle(), 3, UI.colors.accent)
    end, {color = UI.colors.success, textColor = UI.colors.textWhite, width = 80})
    self.dialog:addButton("Back", function()
        self.gameNameInput = nil
        self.dialog:close()
        self.devStep = 3
        self:openPlatformDialog()
    end, {width = 60})
end

function Game:onProjectComplete()
    self.paused = true
    local project = self.currentProject

    -- Generate evaluations
    project:generateReviews()

    -- Start distribution
    local platShare = project.platform.share or 0.3
    local trendBonus = Market.getTrendBonus(project.genre.name)
    project:startSales(self.fans, platShare * trendBonus)

    -- Add to lists
    table.insert(self.releasedGames, project)
    table.insert(self.releasedThisYear, project)
    self.gamesReleased = self.gamesReleased + 1
    Market.addToHallOfFame(project)
    Market.hallOfFame[#Market.hallOfFame].year = self.year

    -- Renown gain from good work
    local fanGain = math.floor(project.reviewAvg * project.reviewAvg * 100)
    self.fans = self.fans + fanGain

    -- Staff exp bonus
    for _, s in ipairs(project.staff) do
        s:addExp(20 + project.quality)
    end

    -- Confetti and sound for great evaluations
    if project.reviewAvg >= 8 then
        self:spawnConfetti(40)
        Audio.play("fanfare")
    elseif project.reviewAvg >= 6 then
        self:spawnConfetti(15)
        Audio.play("success")
    else
        Audio.play("review")
    end

    -- Show evaluation dialog
    self:openReviewDialog(project)

    self.currentProject = nil
end

function Game:openReviewDialog(project)
    self.dialog = UI.Dialog.new("Work Complete!", 20, 10, 440, 300, {closeable = false})
    self.dialog.content = ""
    self.dialog.project = project
    self.dialog.customDraw = function(dlg)
        local px = 32
        local py = 42

        love.graphics.setColor(UI.colors.text)
        UI.setFont("medium")
        love.graphics.printf(project:getTitle(), px, py, 416, "center")
        py = py + 22

        love.graphics.setColor(UI.colors.textLight)
        UI.setFont("small")
        love.graphics.printf(project.genre.name .. " x " .. project.type.name .. " | " .. project.platform.name, px, py, 416, "center")
        py = py + 18

        -- Compatibility
        local compat = project.compatibility
        local compatText = ({"Poor","OK","Good","Great","Perfect!"})[compat] or "OK"
        love.graphics.setColor(UI.colors.text)
        UI.setFont("small")
        love.graphics.print("Affinity: " .. compatText .. " (" .. string.rep("*", compat) .. ")", px + 10, py)
        py = py + 16

        -- Stats bars
        local statsDisplay = project:getStatsDisplay()
        for _, stat in ipairs(statsDisplay) do
            love.graphics.setColor(UI.colors.textLight)
            UI.setFont("tiny")
            love.graphics.print(stat.name, px + 10, py + 1)
            UI.drawProgressBar(px + 70, py + 2, 220, 10, math.min(1, stat.value / 500), stat.color)
            love.graphics.setColor(UI.colors.text)
            love.graphics.print(tostring(stat.value), px + 296, py + 1)
            py = py + 14
        end
        py = py + 4

        -- Evaluations
        love.graphics.setColor(UI.colors.text)
        UI.setFont("small")
        love.graphics.print("Evaluations:", px + 10, py)
        py = py + 16

        for _, review in ipairs(project.reviews) do
            love.graphics.setColor(UI.colors.textLight)
            UI.setFont("tiny")
            love.graphics.print(review.name, px + 14, py)
            local scoreColor = UI.colors.danger
            if review.score >= 8 then scoreColor = UI.colors.success
            elseif review.score >= 6 then scoreColor = UI.colors.accent
            elseif review.score >= 4 then scoreColor = UI.colors.warning end
            love.graphics.setColor(scoreColor)
            UI.setFont("normal")
            love.graphics.print(tostring(review.score), px + 340, py - 1)
            love.graphics.setColor(UI.colors.textLight)
            UI.setFont("tiny")
            love.graphics.print("/10", px + 355, py + 2)
            py = py + 14
        end
        py = py + 4

        -- Average
        local avgColor = UI.colors.danger
        if project.reviewAvg >= 8 then avgColor = UI.colors.success
        elseif project.reviewAvg >= 6 then avgColor = UI.colors.accent
        elseif project.reviewAvg >= 4 then avgColor = UI.colors.warning end
        love.graphics.setColor(avgColor)
        UI.setFont("medium")
        love.graphics.printf(string.format("Average: %.1f / 10", project.reviewAvg), px, py, 416, "center")
    end

    self.dialog:addButton("OK", function()
        self.dialog:close()
        self.paused = false
    end, {color = UI.colors.accent, textColor = UI.colors.textWhite, width = 80})
end

-------------------------------------------------------------------------------
-- COMMISSION WORK (Contracts)
-------------------------------------------------------------------------------
function Game:openContractDialog()
    if self.currentContract then
        UI.addToast("Already on a commission!", 2, UI.colors.warning)
        return
    end
    if self.currentProject then
        UI.addToast("Finish the current work first!", 2, UI.colors.warning)
        return
    end

    -- Available commissions based on staff count
    local available = {}
    for _, c in ipairs(Data.contracts) do
        if #self.staff >= c.minStaff then
            table.insert(available, c)
        end
    end

    if #available == 0 then
        UI.addToast("Recruit more brothers for commissions!", 2, UI.colors.warning)
        return
    end

    -- Pick 3 random commissions
    local offers = {}
    local pool = {unpack(available)}
    for i = 1, math.min(3, #pool) do
        local idx = math.random(#pool)
        table.insert(offers, pool[idx])
        table.remove(pool, idx)
    end

    local list = UI.ScrollList.new(30, 48, 420, 212, 34, offers, {
        renderItem = function(item, x, y, w, h, selected)
            love.graphics.setColor(UI.colors.text)
            UI.setFont("normal")
            love.graphics.print(item.name, x + 8, y + 2)
            love.graphics.setColor(UI.colors.money)
            UI.setFont("tiny")
            love.graphics.print(UI.formatMoney(item.pay) .. " | " .. item.weeks .. " weeks", x + 8, y + 18)
        end,
    })

    self.dialog = UI.Dialog.new("Commissions", 20, 15, 440, 290)
    self.dialog.scrollList = list
    self.dialog:addButton("Accept", function()
        local selected = list:getSelected()
        if selected then
            self.currentContract = {
                name = selected.name,
                pay = selected.pay,
                weeksLeft = selected.weeks,
                totalWeeks = selected.weeks,
            }
            self.dialog:close()
            UI.addToast("Commission accepted: " .. selected.name, 2, UI.colors.accent)
            for _, s in ipairs(self.staff) do
                if not s.training then s.state = "working" end
            end
        end
    end, {color = UI.colors.success, textColor = UI.colors.textWhite, width = 80})
    self.dialog:addButton("Cancel", function() self.dialog:close() end, {width = 70})
end

function Game:onContractComplete()
    local pay = self.currentContract.pay
    self.money = self.money + pay
    self.contractsCompleted = self.contractsCompleted + 1
    Audio.play("money")
    UI.addToast("Commission complete! +" .. UI.formatMoney(pay), 3, UI.colors.success)
    for _, s in ipairs(self.staff) do
        if s.state == "working" then s.state = "idle" end
    end
    self.currentContract = nil
end

-------------------------------------------------------------------------------
-- BROTHERS MANAGEMENT (Staff)
-------------------------------------------------------------------------------
function Game:openStaffDialog()
    local items = {}
    for i, s in ipairs(self.staff) do
        table.insert(items, {staff = s, index = i})
    end

    local list = UI.ScrollList.new(30, 48, 420, 212, 54, items, {
        renderItem = function(item, x, y, w, h, selected)
            item.staff:drawStatCard(x, y, w, selected)
        end,
    })

    self.dialog = UI.Dialog.new("Brothers (" .. #self.staff .. "/" .. MAX_STAFF .. ")", 20, 15, 440, 290)
    self.dialog.scrollList = list
    self.dialog:addButton("Recruit", function()
        self.dialog:close()
        self:openHireDialog()
    end, {color = UI.colors.success, textColor = UI.colors.textWhite, width = 60})
    self.dialog:addButton("Form", function()
        local selected = list:getSelected()
        if selected then
            self.dialog:close()
            self:openTrainDialog(selected.staff)
        else
            UI.addToast("Select a brother first!", 2, UI.colors.warning)
        end
    end, {color = UI.colors.accent, textColor = UI.colors.textWhite, width = 50})
    self.dialog:addButton("Release", function()
        local selected = list:getSelected()
        if selected and not self.currentProject then
            local idx = selected.index
            table.remove(self.staff, idx)
            self.office:removeStaff(idx)
            UI.addToast(selected.staff.name .. " has left the monastery.", 2, UI.colors.warning)
            local newItems = {}
            for i, s in ipairs(self.staff) do
                table.insert(newItems, {staff = s, index = i})
            end
            list:setItems(newItems)
            self.dialog.title = "Brothers (" .. #self.staff .. "/" .. MAX_STAFF .. ")"
        elseif self.currentProject then
            UI.addToast("Cannot release during work!", 2, UI.colors.danger)
        end
    end, {color = UI.colors.danger, textColor = UI.colors.textWhite, width = 55})
    self.dialog:addButton("Close", function() self.dialog:close() end, {width = 50})
end

function Game:openHireDialog()
    if #self.staff >= MAX_STAFF then
        UI.addToast("Scriptorium is full! (" .. MAX_STAFF .. " max)", 2, UI.colors.danger)
        self:openStaffDialog()
        return
    end

    local list = UI.ScrollList.new(30, 48, 420, 212, 54, self.hirePool, {
        renderItem = function(item, x, y, w, h, selected)
            love.graphics.setColor(UI.colors.text)
            UI.setFont("normal")
            love.graphics.print(item.name .. " - " .. item.job, x + 8, y + 2)
            love.graphics.setColor(UI.colors.textLight)
            UI.setFont("tiny")
            love.graphics.print("Lv." .. item.level .. " | Upkeep: " .. UI.formatMoney(item.salary) .. "/mo", x + 8, y + 17)
            -- Mini stat bars
            local stats = {
                {"F", item.stats.program},
                {"W", item.stats.scenario},
                {"B", item.stats.graphics},
                {"H", item.stats.sound},
            }
            for j, stat in ipairs(stats) do
                local sx = x + 8 + (j-1) * 95
                love.graphics.setColor(UI.colors.textLight)
                love.graphics.print(stat[1] .. ":", sx, y + 32)
                UI.drawProgressBar(sx + 12, y + 34, 65, 6, math.min(1, stat[2] / 100))
            end
        end,
    })

    self.dialog = UI.Dialog.new("Recruit Brothers", 20, 15, 440, 290)
    self.dialog.scrollList = list
    self.dialog:addButton("Recruit", function()
        local selected, idx = list:getSelected()
        if selected then
            if self.money >= selected.salary then
                local newStaff = Staff.createFromPool(selected)
                table.insert(self.staff, newStaff)
                table.remove(self.hirePool, idx)
                list:setItems(self.hirePool)
                UI.addToast(selected.name .. " has joined the monastery!", 2, UI.colors.success)
                if #self.staff >= MAX_STAFF then
                    self.dialog:close()
                end
            else
                UI.addToast("Not enough gold!", 2, UI.colors.danger)
            end
        end
    end, {color = UI.colors.success, textColor = UI.colors.textWhite, width = 70})
    self.dialog:addButton("Back", function()
        self.dialog:close()
        self:openStaffDialog()
    end, {width = 70})
end

function Game:openTrainDialog(staffMember)
    if staffMember.training then
        UI.addToast(staffMember.name .. " is already in formation!", 2, UI.colors.warning)
        self:openStaffDialog()
        return
    end

    local items = {}
    for _, t in ipairs(Data.training) do
        table.insert(items, t)
    end

    local list = UI.ScrollList.new(30, 48, 420, 212, 30, items, {
        renderItem = function(item, x, y, w, h, selected)
            love.graphics.setColor(UI.colors.text)
            UI.setFont("normal")
            love.graphics.print(item.name, x + 8, y + 2)
            love.graphics.setColor(UI.colors.textLight)
            UI.setFont("tiny")
            local statName = item.stat == "all" and "All Stats" or
                            item.stat == "random" and "Random Stat" or
                            item.stat:sub(1,1):upper() .. item.stat:sub(2)
            love.graphics.print(UI.formatMoney(item.cost) .. " | " .. item.weeks .. "w | +" .. item.amount .. " " .. statName, x + 8, y + 17)
        end,
    })

    self.dialog = UI.Dialog.new("Formation: " .. staffMember.name, 20, 15, 440, 290)
    self.dialog.scrollList = list
    self.dialog:addButton("Begin", function()
        local selected = list:getSelected()
        if selected then
            if self.money >= selected.cost then
                self.money = self.money - selected.cost
                staffMember:startTraining(selected)
                UI.addToast(staffMember.name .. " began " .. selected.name, 2, UI.colors.accent)
                self.dialog:close()
            else
                UI.addToast("Not enough gold!", 2, UI.colors.danger)
            end
        end
    end, {color = UI.colors.accent, textColor = UI.colors.textWhite, width = 70})
    self.dialog:addButton("Back", function()
        self.dialog:close()
        self:openStaffDialog()
    end, {width = 70})
end

function Game:refreshHirePool()
    self.hirePool = {}
    local pool = {}
    for _, s in ipairs(Data.staffPool) do
        local employed = false
        for _, es in ipairs(self.staff) do
            if es.name == s.name then employed = true break end
        end
        if not employed then
            table.insert(pool, s)
        end
    end
    for i = 1, math.min(5, #pool) do
        local idx = math.random(#pool)
        table.insert(self.hirePool, pool[idx])
        table.remove(pool, idx)
    end
end

-------------------------------------------------------------------------------
-- STUDIES (Research)
-------------------------------------------------------------------------------
function Game:openResearchDialog()
    local items = {}

    -- Research work types
    for _, rg in ipairs(Data.researchGenres) do
        if self.year >= rg.yearReq then
            local unlocked = false
            for _, name in ipairs(self.researchedGenres) do
                if name == rg.name then unlocked = true break end
            end
            if not unlocked then
                table.insert(items, {data = rg, isGenre = true, name = rg.name, cost = rg.cost, type = "Work Type"})
            end
        end
    end
    -- Research subjects
    for _, rt in ipairs(Data.researchTypes) do
        if self.year >= rt.yearReq then
            local unlocked = false
            for _, name in ipairs(self.researchedTypes) do
                if name == rt.name then unlocked = true break end
            end
            if not unlocked then
                table.insert(items, {data = rt, isGenre = false, name = rt.name, cost = rt.cost, type = "Subject"})
            end
        end
    end

    if #items == 0 then
        UI.addToast("No studies available right now.", 2, UI.colors.textLight)
        return
    end

    local list = UI.ScrollList.new(30, 48, 420, 212, 30, items, {
        renderItem = function(item, x, y, w, h, selected)
            love.graphics.setColor(UI.colors.text)
            UI.setFont("normal")
            love.graphics.print("[" .. item.type .. "] " .. item.name, x + 8, y + 2)
            love.graphics.setColor(UI.colors.textLight)
            UI.setFont("tiny")
            love.graphics.print("Cost: " .. UI.formatMoney(item.cost), x + 8, y + 17)
        end,
    })

    self.dialog = UI.Dialog.new("Studies", 20, 15, 440, 290)
    self.dialog.scrollList = list
    self.dialog:addButton("Study", function()
        local selected = list:getSelected()
        if selected then
            if self.money >= selected.cost then
                self.money = self.money - selected.cost
                if selected.isGenre then
                    table.insert(self.researchedGenres, selected.name)
                    table.insert(self.availableGenres, selected.data)
                    UI.addToast("Learned work type: " .. selected.name .. "!", 3, UI.colors.success)
                else
                    table.insert(self.researchedTypes, selected.name)
                    table.insert(self.availableTypes, selected.data)
                    UI.addToast("Learned subject: " .. selected.name .. "!", 3, UI.colors.success)
                end
                local newItems = {}
                for _, item in ipairs(list.items) do
                    if item.name ~= selected.name then
                        table.insert(newItems, item)
                    end
                end
                list:setItems(newItems)
            else
                UI.addToast("Not enough gold!", 2, UI.colors.danger)
            end
        end
    end, {color = UI.colors.accent, textColor = UI.colors.textWhite, width = 80})
    self.dialog:addButton("Close", function() self.dialog:close() end, {width = 70})
end

-------------------------------------------------------------------------------
-- PROVISIONS (Items)
-------------------------------------------------------------------------------
function Game:openItemDialog()
    local items = {}
    for _, item in ipairs(Data.items) do
        local count = self.inventory[item.name] or 0
        table.insert(items, {data = item, count = count, name = item.name})
    end

    local list = UI.ScrollList.new(30, 48, 420, 212, 28, items, {
        renderItem = function(item, x, y, w, h, selected)
            love.graphics.setColor(UI.colors.text)
            UI.setFont("normal")
            love.graphics.print(item.name, x + 8, y + 2)
            love.graphics.setColor(UI.colors.textLight)
            UI.setFont("tiny")
            love.graphics.print(item.data.desc .. " | " .. UI.formatMoney(item.data.cost), x + 8, y + 16)
            if item.count > 0 then
                love.graphics.setColor(UI.colors.success)
                love.graphics.print("x" .. item.count, x + w - 25, y + 8)
            end
        end,
    })

    self.dialog = UI.Dialog.new("Provisions", 20, 15, 440, 290)
    self.dialog.scrollList = list
    self.dialog:addButton("Buy", function()
        local selected = list:getSelected()
        if selected then
            if self.money >= selected.data.cost then
                self.money = self.money - selected.data.cost
                self.inventory[selected.name] = (self.inventory[selected.name] or 0) + 1
                selected.count = self.inventory[selected.name]
                UI.addToast("Acquired " .. selected.name, 2, UI.colors.success)
            else
                UI.addToast("Not enough gold!", 2, UI.colors.danger)
            end
        end
    end, {color = UI.colors.success, textColor = UI.colors.textWhite, width = 55})
    self.dialog:addButton("Use", function()
        local selected = list:getSelected()
        if selected and selected.count > 0 then
            if self.currentProject and not self.currentProject.complete then
                self.inventory[selected.name] = self.inventory[selected.name] - 1
                selected.count = self.inventory[selected.name]
                self.currentProject:applyItem(selected.data)
                UI.addToast("Applied " .. selected.name .. "!", 2, UI.colors.accent)
            elseif selected.data.effect == "fans" then
                self.inventory[selected.name] = self.inventory[selected.name] - 1
                selected.count = self.inventory[selected.name]
                self.fans = self.fans + selected.data.amount
                UI.addToast("+" .. UI.formatNumber(selected.data.amount) .. " renown!", 2, UI.colors.accent)
            else
                UI.addToast("Begin a work to use this provision!", 2, UI.colors.warning)
            end
        elseif selected then
            UI.addToast("You don't have any!", 2, UI.colors.danger)
        end
    end, {color = UI.colors.accent, textColor = UI.colors.textWhite, width = 50})
    self.dialog:addButton("Close", function() self.dialog:close() end, {width = 55})
end

-------------------------------------------------------------------------------
-- ABBEY ARCHIVES (Hall of Fame)
-------------------------------------------------------------------------------
function Game:openHallOfFame()
    if #Market.hallOfFame == 0 then
        UI.addToast("No works completed yet!", 2, UI.colors.textLight)
        return
    end

    local list = UI.ScrollList.new(30, 48, 420, 212, 38, Market.hallOfFame, {
        renderItem = function(item, x, y, w, h, selected)
            love.graphics.setColor(UI.colors.text)
            UI.setFont("normal")
            love.graphics.print(item.title, x + 8, y + 2)
            love.graphics.setColor(UI.colors.textLight)
            UI.setFont("tiny")
            love.graphics.print(item.genre .. " x " .. item.type .. " | " .. item.platform, x + 8, y + 17)
            local scoreColor = UI.colors.danger
            if item.reviewAvg >= 8 then scoreColor = UI.colors.success
            elseif item.reviewAvg >= 6 then scoreColor = UI.colors.accent
            elseif item.reviewAvg >= 4 then scoreColor = UI.colors.warning end
            love.graphics.setColor(scoreColor)
            love.graphics.print(string.format("%.1f/10", item.reviewAvg), x + w - 80, y + 4)
            love.graphics.setColor(UI.colors.money)
            love.graphics.print(UI.formatMoney(item.totalRevenue), x + w - 80, y + 17)
            love.graphics.setColor(UI.colors.textLight)
            love.graphics.print("Y" .. item.year, x + w - 30, y + 17)
        end,
    })

    self.dialog = UI.Dialog.new("Abbey Archives", 20, 15, 440, 290)
    self.dialog.scrollList = list
    self.dialog:addButton("Close", function() self.dialog:close() end, {width = 80})
end

-------------------------------------------------------------------------------
-- HONORS (Awards)
-------------------------------------------------------------------------------
function Game:openAwardDialog(awards)
    self.dialog = UI.Dialog.new("Church Honors - Year " .. self.year, 20, 10, 440, 300, {closeable = false})
    self.dialog.awards = awards
    self.dialog.customDraw = function(dlg)
        local py = 48
        for i, award in ipairs(dlg.awards) do
            local medalColor = UI.colors.gold
            if i == 2 then medalColor = UI.colors.silver
            elseif i >= 3 then medalColor = UI.colors.bronze end

            UI.drawStar(38, py + 12, 10, 5, medalColor)

            love.graphics.setColor(UI.colors.text)
            UI.setFont("medium")
            love.graphics.print(award.name, 54, py)
            py = py + 20

            love.graphics.setColor(UI.colors.textLight)
            UI.setFont("small")
            love.graphics.print(award.game, 54, py)
            py = py + 16

            love.graphics.setColor(UI.colors.money)
            UI.setFont("tiny")
            love.graphics.print("Bounty: " .. UI.formatMoney(award.prize) .. " | +" .. UI.formatNumber(award.fans) .. " renown", 54, py)
            py = py + 22
        end
    end
    self.dialog:addButton("Deo Gratias!", function()
        self.dialog:close()
        self.paused = false
    end, {color = UI.colors.gold, textColor = UI.colors.text, width = 100})
end

-------------------------------------------------------------------------------
-- PATRON EVENTS (Platforms)
-------------------------------------------------------------------------------
function Game:checkNewPlatforms()
    local newPlatforms = Market.getNewPlatforms(self.year)
    for _, p in ipairs(newPlatforms) do
        if p.cost > 0 then
            Audio.play("platform")
            UI.addToast("New patron: " .. p.name .. "!", 4, UI.colors.accent)
        end
    end
end

-------------------------------------------------------------------------------
-- RANDOM EVENTS
-------------------------------------------------------------------------------
function Game:checkRandomEvents()
    if self.eventCooldown > 0 then return end
    if math.random() > 0.03 then return end

    local event = Data.events[math.random(#Data.events)]
    self.eventCooldown = 8

    if event.type == "market" then
        Market.setSalesBoost(event.amount, event.duration)
        UI.addToast(event.desc, 4, event.amount > 1 and UI.colors.success or UI.colors.danger)
    elseif event.type == "fans" then
        self.fans = self.fans + event.amount
        UI.addToast(event.desc .. " +" .. UI.formatNumber(event.amount), 3, UI.colors.success)
    elseif event.type == "staff" and #self.staff > 0 then
        local s = self.staff[math.random(#self.staff)]
        s.motivation = math.min(100, s.motivation + 30)
        s.boosted = true
        s.boostTimer = event.duration or 4
        local desc = event.desc:gsub("%%s", s.name)
        UI.addToast(s.name .. " is filled with zeal!", 3, UI.colors.success)
    elseif event.type == "project" and self.currentProject and not self.currentProject.complete then
        self.currentProject.bugs = self.currentProject.bugs + event.amount
        UI.addToast(event.desc, 3, UI.colors.danger)
    elseif event.type == "trend" then
        local genre = Data.genres[math.random(#Data.genres)]
        Market.currentTrend = genre.name
        Market.trendTimer = event.duration
        local desc = event.desc:gsub("%%s", genre.name)
        UI.addToast(genre.name .. " works are in high demand!", 4, UI.colors.accent)
    end
end

-------------------------------------------------------------------------------
-- GAME OVER
-------------------------------------------------------------------------------
function Game:triggerGameOver()
    self.gameOver = true
    self.paused = true

    self.dialog = UI.Dialog.new("The Chapter Closes", 20, 10, 440, 300, {closeable = false})
    self.dialog.customDraw = function(dlg)
        local px = 32
        local py = 42

        love.graphics.setColor(UI.colors.text)
        UI.setFont("medium")
        love.graphics.printf(self.companyName, px, py, 416, "center")
        py = py + 24

        UI.setFont("small")
        love.graphics.setColor(UI.colors.textLight)
        love.graphics.printf("Final Chronicle - " .. (self.year > MAX_YEAR and MAX_YEAR or self.year) .. " Years", px, py, 416, "center")
        py = py + 24

        local stats = {
            {"Works Completed", tostring(self.gamesReleased)},
            {"Commissions Done", tostring(self.contractsCompleted)},
            {"Honors Received", tostring(#self.awardsWon)},
            {"Total Offerings", UI.formatMoney(self.totalRevenue)},
            {"Treasury", UI.formatMoney(self.money)},
            {"Renown", UI.formatNumber(self.fans)},
            {"Brothers", tostring(#self.staff)},
        }

        for _, stat in ipairs(stats) do
            love.graphics.setColor(UI.colors.text)
            UI.setFont("normal")
            love.graphics.print(stat[1], px + 20, py)
            love.graphics.setColor(UI.colors.accent)
            love.graphics.printf(stat[2], px, py, 416, "right")
            py = py + 18
        end

        py = py + 10
        if #Market.hallOfFame > 0 then
            local best = Market.hallOfFame[1]
            love.graphics.setColor(UI.colors.gold)
            UI.setFont("small")
            love.graphics.printf("Finest Work: " .. best.title .. " (" .. string.format("%.1f", best.reviewAvg) .. "/10)", px, py, 416, "center")
        end
    end

    self.dialog:addButton("New Game", function()
        self.dialog:close()
        self.wantsRestart = true
    end, {color = UI.colors.accent, textColor = UI.colors.textWhite, width = 100})
end

-------------------------------------------------------------------------------
-- CONFETTI
-------------------------------------------------------------------------------
function Game:spawnConfetti(count)
    for i = 1, (count or 30) do
        table.insert(self.confetti, {
            x = math.random(50, 430),
            y = math.random(-20, 20),
            vx = (math.random() - 0.5) * 100,
            vy = 30 + math.random() * 80,
            rot = math.random() * math.pi * 2,
            rotSpeed = (math.random() - 0.5) * 10,
            size = 2 + math.random() * 4,
            life = 3 + math.random() * 2,
            maxLife = 5,
            color = {
                0.2 + math.random() * 0.8,
                0.2 + math.random() * 0.8,
                0.2 + math.random() * 0.8,
            },
        })
    end
end

function Game:updateConfetti(dt)
    for i = #self.confetti, 1, -1 do
        local c = self.confetti[i]
        c.x = c.x + c.vx * dt
        c.y = c.y + c.vy * dt
        c.rot = c.rot + c.rotSpeed * dt
        c.vy = c.vy + 20 * dt
        c.vx = c.vx * 0.99
        c.life = c.life - dt
        if c.life <= 0 or c.y > 340 then
            table.remove(self.confetti, i)
        end
    end
end

function Game:drawConfetti()
    for _, c in ipairs(self.confetti) do
        local alpha = math.min(1, c.life / (c.maxLife * 0.3))
        love.graphics.setColor(c.color[1], c.color[2], c.color[3], alpha)
        love.graphics.push()
        love.graphics.translate(c.x, c.y)
        love.graphics.rotate(c.rot)
        love.graphics.rectangle("fill", -c.size/2, -c.size/4, c.size, c.size/2)
        love.graphics.pop()
    end
end

-------------------------------------------------------------------------------
-- MONEY FLOATS
-------------------------------------------------------------------------------
function Game:addMoneyFloat(amount)
    table.insert(self.moneyFloats, {
        text = (amount >= 0 and "+" or "") .. UI.formatMoney(amount),
        x = 130 + math.random(-10, 10),
        y = 4,
        vy = -0.8,
        life = 1.5,
        maxLife = 1.5,
        color = amount >= 0 and UI.colors.success or UI.colors.danger,
    })
end

function Game:updateMoneyFloats(dt)
    for i = #self.moneyFloats, 1, -1 do
        local f = self.moneyFloats[i]
        f.y = f.y + f.vy
        f.life = f.life - dt
        if f.life <= 0 then
            table.remove(self.moneyFloats, i)
        end
    end
end

function Game:drawMoneyFloats()
    UI.setFont("tiny")
    for _, f in ipairs(self.moneyFloats) do
        local alpha = math.max(0, f.life / f.maxLife)
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], alpha)
        love.graphics.print(f.text, f.x, f.y)
    end
end

-------------------------------------------------------------------------------
-- MAIN DRAW
-------------------------------------------------------------------------------
function Game:draw()
    -- Background
    love.graphics.setColor(UI.colors.bg)
    love.graphics.rectangle("fill", 0, 0, 480, 320)

    -- Top bar
    self:drawTopBar()
    self:drawMoneyFloats()

    -- Scriptorium area
    self.office:draw(self.staff, self.currentProject, self.year)

    -- Bottom bar
    self:drawBottomBar()

    -- Current work overlay info
    if self.currentProject and not self.currentProject.complete then
        self:drawProjectStatus()
    elseif self.currentContract then
        self:drawContractStatus()
    end

    -- Dialogs (with custom draw support)
    if self.dialog and self.dialog:isOpen() then
        self.dialog:draw()
        if self.dialog.customDraw then
            self.dialog.customDraw(self.dialog)
        end
    end
    if self.subDialog and self.subDialog:isOpen() then
        self.subDialog:draw()
    end

    -- Confetti
    self:drawConfetti()

    -- Toasts
    UI.drawToasts()
end

function Game:drawTopBar()
    -- Bar background (dark parchment)
    love.graphics.setColor(0.35, 0.28, 0.20)
    love.graphics.rectangle("fill", 0, 0, 480, 22)
    love.graphics.setColor(0.45, 0.38, 0.28)
    love.graphics.rectangle("fill", 0, 20, 480, 2)

    -- Monastery name
    love.graphics.setColor(1, 1, 1)
    UI.setFont("small")
    love.graphics.print(self.companyName, 6, 4)

    -- Treasury
    love.graphics.setColor(0.85, 0.75, 0.20)
    UI.setFont("small")
    local moneyStr = UI.formatMoney(self.money)
    love.graphics.print(moneyStr, 130, 4)

    -- Renown
    love.graphics.setColor(1, 0.85, 0.3)
    love.graphics.print("Renown: " .. UI.formatNumber(self.fans), 215, 4)

    -- Date
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Y" .. self.year .. " W" .. string.format("%02d", self.week), 330, 4)

    -- Speed indicator
    local speedText = self.paused and "||" or string.rep(">", self.speed)
    love.graphics.setColor(1, 1, 0.5)
    love.graphics.print(speedText, 400, 4)

    -- Speed buttons
    for _, b in ipairs(self.speedButtons) do b:draw() end

    -- Trend indicator (popular devotion)
    if Market.currentTrend then
        love.graphics.setColor(1, 0.6, 0.2)
        UI.setFont("tiny")
        love.graphics.print("In demand: " .. Market.currentTrend, 6, 24)
    end
end

function Game:drawBottomBar()
    -- Bar background
    love.graphics.setColor(0.35, 0.28, 0.20)
    love.graphics.rectangle("fill", 0, 245, 480, 75)
    love.graphics.setColor(0.45, 0.38, 0.28)
    love.graphics.rectangle("fill", 0, 245, 480, 2)

    -- Action buttons
    for _, b in ipairs(self.actionButtons) do b:draw() end

    -- Status text at bottom
    love.graphics.setColor(0.8, 0.75, 0.65)
    UI.setFont("tiny")
    local statusText = "Brothers: " .. #self.staff .. "/" .. MAX_STAFF
    statusText = statusText .. " | Works: " .. self.gamesReleased
    statusText = statusText .. " | Honors: " .. #self.awardsWon
    love.graphics.print(statusText, 14, 283)

    -- Active distributions
    local activeSales = 0
    for _, g in ipairs(self.releasedGames) do
        if g.salesActive then activeSales = activeSales + 1 end
    end
    if activeSales > 0 then
        love.graphics.setColor(0.85, 0.75, 0.20)
        love.graphics.print(activeSales .. " work(s) circulating", 14, 295)
    end

    -- Weekly revenue
    local weekRev = 0
    for _, g in ipairs(self.releasedGames) do
        if g.salesActive then weekRev = weekRev + g.weeklySales * g.unitPrice end
    end
    if weekRev > 0 then
        love.graphics.setColor(0.85, 0.75, 0.20)
        love.graphics.print("Offerings: " .. UI.formatMoney(weekRev) .. "/wk", 160, 295)
    end
end

function Game:drawProjectStatus()
    local p = self.currentProject
    local x, y, w = 350, 30, 128

    UI.drawPanel(x, y, w, 110, {
        title = "Work",
        bgColor = {UI.colors.panel[1], UI.colors.panel[2], UI.colors.panel[3], 0.95},
        radius = 4,
    })

    local cy = y + 32
    love.graphics.setColor(UI.colors.text)
    UI.setFont("tiny")
    love.graphics.printf(p:getTitle(), x + 4, cy, w - 8, "center")
    cy = cy + 11

    -- Phase with color
    love.graphics.setColor(p:getPhaseColor())
    UI.setFont("tiny")
    love.graphics.printf(p:getPhaseName(), x + 4, cy, w - 8, "center")
    cy = cy + 11

    -- Progress bar
    UI.drawProgressBar(x + 6, cy, w - 12, 10, p:getProgress(), p:getPhaseColor())
    cy = cy + 14

    -- Week count
    love.graphics.setColor(UI.colors.textLight)
    UI.setFont("tiny")
    love.graphics.printf("Week " .. p.totalWeeks, x + 4, cy, w - 8, "center")
    cy = cy + 11

    -- Direction indicator
    if p.direction then
        local dirNames = {fun="Devotion", creativity="Wisdom", graphics="Beauty", sound="Harmony"}
        local dirColors = {fun={0.75,0.6,0.2}, creativity={0.3,0.5,0.7}, graphics={0.8,0.3,0.5}, sound={0.4,0.6,0.3}}
        love.graphics.setColor(dirColors[p.direction] or UI.colors.textLight)
        love.graphics.printf("Focus: " .. (dirNames[p.direction] or p.direction), x + 4, cy, w - 8, "center")
    end

    -- Mini stat preview
    cy = cy + 10
    local statNames = {"D", "W", "B", "H"}
    local statKeys = {"fun", "creativity", "graphics", "sound"}
    local statColors = {{0.75,0.6,0.2}, {0.3,0.5,0.7}, {0.8,0.3,0.5}, {0.4,0.6,0.3}}
    local barW = (w - 16) / 4 - 2
    for i = 1, 4 do
        local bx = x + 4 + (i-1) * (barW + 2)
        love.graphics.setColor(UI.colors.textLight)
        love.graphics.print(statNames[i], bx + barW/2 - 2, cy)
        UI.drawProgressBar(bx, cy + 9, barW, 4, math.min(1, p.stats[statKeys[i]] / 300), statColors[i])
    end
end

function Game:drawContractStatus()
    local c = self.currentContract
    local x, y, w = 355, 45, 120

    UI.drawPanel(x, y, w, 65, {
        title = "Commission",
        bgColor = {UI.colors.panel[1], UI.colors.panel[2], UI.colors.panel[3], 0.9},
        radius = 4,
    })

    local cy = y + 32
    love.graphics.setColor(UI.colors.text)
    UI.setFont("tiny")
    love.graphics.printf(c.name, x + 4, cy, w - 8, "center")
    cy = cy + 12

    UI.drawProgressBar(x + 6, cy, w - 12, 10,
        1 - (c.weeksLeft / c.totalWeeks), UI.colors.success)
    cy = cy + 14

    love.graphics.setColor(UI.colors.money)
    UI.setFont("tiny")
    love.graphics.printf(UI.formatMoney(c.pay), x + 4, cy, w - 8, "center")
end

-------------------------------------------------------------------------------
-- INPUT HANDLING
-------------------------------------------------------------------------------
function Game:mousepressed(x, y, button)
    if button ~= 1 then return end

    if self.subDialog and self.subDialog:isOpen() then
        self.subDialog:click(x, y)
        return
    end
    if self.dialog and self.dialog:isOpen() then
        if self.dialog.customClick then
            if self.dialog.customClick(self.dialog, x, y) then return end
        end
        self.dialog:click(x, y)
        return
    end

    for _, b in ipairs(self.speedButtons) do
        if b:click(x, y) then return end
    end

    for _, b in ipairs(self.actionButtons) do
        if b:click(x, y) then return end
    end
end

function Game:mousereleased(x, y, button)
    for _, b in ipairs(self.speedButtons) do b:release() end
    for _, b in ipairs(self.actionButtons) do b:release() end
    if self.dialog then
        for _, b in ipairs(self.dialog.buttons or {}) do
            if b.btn then b.btn:release() end
        end
    end
end

function Game:wheelmoved(x, y)
    if self.subDialog and self.subDialog:isOpen() then
        self.subDialog:wheelmoved(x, y)
        return
    end
    if self.dialog and self.dialog:isOpen() then
        self.dialog:wheelmoved(x, y)
        return
    end
end

function Game:keypressed(key)
    if self.gameNameInput then
        self.gameNameInput:keypressed(key)
        return
    end
    if key == "space" then
        self.paused = not self.paused
    elseif key == "1" then
        self.speed = 1; self.paused = false
    elseif key == "2" then
        self.speed = 2; self.paused = false
    elseif key == "3" then
        self.speed = 3; self.paused = false
    elseif key == "escape" then
        if self.subDialog and self.subDialog:isOpen() then
            self.subDialog:close()
        elseif self.dialog and self.dialog:isOpen() then
            self.dialog:close()
        end
    elseif key == "s" then
        if not self.dialog then
            local Save = require("save")
            local ok, err = Save.saveGame(self)
            if ok then
                UI.addToast("Progress saved!", 2, UI.colors.success)
            else
                UI.addToast("Save failed: " .. tostring(err), 2, UI.colors.danger)
            end
        end
    end
end

function Game:textinput(text)
    if self.gameNameInput then
        self.gameNameInput:textinput(text)
    end
end

return Game
