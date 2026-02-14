local UI = require("ui")

local Office = {}
Office.__index = Office

-------------------------------------------------------------------------------
-- SCRIPTORIUM LAYOUT
-------------------------------------------------------------------------------
-- Scriptorium is drawn in the center of the screen, 380x195 area
local OFFICE_X = 50
local OFFICE_Y = 45
local OFFICE_W = 380
local OFFICE_H = 195

-- Writing desk positions (x, y) relative to scriptorium origin
local DESK_POSITIONS = {
    {x = 60,  y = 70},
    {x = 160, y = 70},
    {x = 260, y = 70},
    {x = 60,  y = 140},
    {x = 160, y = 140},
    {x = 260, y = 140},
}

-------------------------------------------------------------------------------
-- CREATION
-------------------------------------------------------------------------------
function Office.new()
    local self = setmetatable({}, Office)
    self.staffPositions = {} -- staff index -> desk index
    self.decorations = {}
    self.particles = {}
    self.time = 0
    self.developing = false
    self.devPhase = ""
    self.seasonTimer = 0
    self.season = "spring"
    return self
end

-------------------------------------------------------------------------------
-- UPDATE
-------------------------------------------------------------------------------
function Office:update(dt, staffList, currentProject)
    self.time = self.time + dt
    self.developing = currentProject ~= nil and not currentProject.complete

    -- Assign staff to desk positions
    for i, staff in ipairs(staffList) do
        if not self.staffPositions[i] then
            -- Find empty desk
            for d = 1, #DESK_POSITIONS do
                local taken = false
                for _, sd in pairs(self.staffPositions) do
                    if sd == d then taken = true break end
                end
                if not taken then
                    self.staffPositions[i] = d
                    local pos = DESK_POSITIONS[d]
                    staff.officeX = OFFICE_X + pos.x
                    staff.officeY = OFFICE_Y + pos.y
                    staff.targetX = staff.officeX
                    staff.targetY = staff.officeY
                    break
                end
            end
        else
            local pos = DESK_POSITIONS[self.staffPositions[i]]
            if pos then
                staff.targetX = OFFICE_X + pos.x
                staff.targetY = OFFICE_Y + pos.y
            end
        end

        -- Update staff animation
        if self.developing and not staff.training then
            staff.state = "working"
            staff.animFrame = self.time
        elseif staff.training then
            staff.state = "training"
        else
            -- Idle behavior: occasionally walk around the scriptorium
            staff.walkTimer = (staff.walkTimer or 0) + dt
            if staff.state == "walking" then
                local dx = staff.targetX - staff.officeX
                local dy = staff.targetY - staff.officeY
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist > 2 then
                    staff.officeX = staff.officeX + (dx / dist) * 30 * dt
                    staff.officeY = staff.officeY + (dy / dist) * 30 * dt
                    staff.facing = dx > 0 and 1 or -1
                else
                    staff.state = "idle"
                    staff.walkTimer = 0
                end
            elseif staff.walkTimer > 3 + math.random() * 5 then
                if math.random() < 0.4 then
                    staff.state = "walking"
                    staff.targetX = OFFICE_X + 30 + math.random() * (OFFICE_W - 80)
                    staff.targetY = OFFICE_Y + 50 + math.random() * (OFFICE_H - 80)
                else
                    local deskIdx = self.staffPositions[i]
                    if deskIdx and DESK_POSITIONS[deskIdx] then
                        staff.state = "walking"
                        staff.targetX = OFFICE_X + DESK_POSITIONS[deskIdx].x
                        staff.targetY = OFFICE_Y + DESK_POSITIONS[deskIdx].y
                    end
                end
                staff.walkTimer = 0
            end
        end
        staff.animFrame = self.time + i * 0.7
    end

    -- Work particles
    if self.developing and currentProject then
        currentProject:updateParticles(dt)
        if math.random() < 0.05 then
            table.insert(self.particles, {
                x = OFFICE_X + 30 + math.random() * (OFFICE_W - 60),
                y = OFFICE_Y + 40 + math.random() * (OFFICE_H - 60),
                vy = -0.3 - math.random() * 0.3,
                life = 1 + math.random(),
                maxLife = 2,
                size = 1 + math.random() * 2,
                color = self:getPhaseParticleColor(currentProject.phase),
            })
        end
    end

    -- Update particles
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.y = p.y + p.vy
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end

    -- Season
    self.seasonTimer = self.seasonTimer + dt
end

function Office:getPhaseParticleColor(phase)
    if phase == "planning" then return {0.75, 0.60, 0.20} end  -- gold
    if phase == "crafting" then return {0.80, 0.35, 0.50} end   -- rose
    if phase == "chanting" then return {0.40, 0.60, 0.30} end   -- green
    if phase == "scribing" then return {0.35, 0.50, 0.70} end   -- blue
    if phase == "reviewing" then return {0.70, 0.50, 0.20} end  -- brown
    return {1, 1, 1}
end

function Office:removeStaff(index)
    self.staffPositions[index] = nil
    local newPositions = {}
    for k, v in pairs(self.staffPositions) do
        if k > index then
            newPositions[k - 1] = v
        elseif k < index then
            newPositions[k] = v
        end
    end
    self.staffPositions = newPositions
end

-------------------------------------------------------------------------------
-- DRAWING
-------------------------------------------------------------------------------
function Office:draw(staffList, currentProject, year)
    -- Scriptorium background
    self:drawRoom(year)

    -- Writing desks
    self:drawDesks(staffList)

    -- Staff characters (sorted by Y for depth)
    local sortedStaff = {}
    for i, s in ipairs(staffList) do
        table.insert(sortedStaff, {staff = s, index = i})
    end
    table.sort(sortedStaff, function(a, b) return a.staff.officeY < b.staff.officeY end)

    for _, entry in ipairs(sortedStaff) do
        entry.staff:drawCharacter(entry.staff.officeX, entry.staff.officeY, 1.8, entry.staff.animFrame)
    end

    -- Particles
    for _, p in ipairs(self.particles) do
        local alpha = math.max(0, p.life / p.maxLife)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha * 0.7)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end

    -- Project particles
    if currentProject and not currentProject.complete then
        currentProject:drawParticles()
    end

    -- Decorations overlay
    self:drawDecorations(year)
end

function Office:drawRoom(year)
    -- Stone floor
    love.graphics.setColor(0.68, 0.63, 0.55)
    love.graphics.rectangle("fill", OFFICE_X, OFFICE_Y, OFFICE_W, OFFICE_H, 4, 4)

    -- Stone tile pattern
    love.graphics.setColor(0.62, 0.57, 0.49, 0.3)
    for i = 0, OFFICE_H, 20 do
        love.graphics.line(OFFICE_X, OFFICE_Y + i, OFFICE_X + OFFICE_W, OFFICE_Y + i)
    end
    for i = 0, OFFICE_W, 20 do
        local offset = (math.floor(i / 20) % 2) * 10
        for j = offset, OFFICE_H, 40 do
            love.graphics.line(OFFICE_X + i, OFFICE_Y + j, OFFICE_X + i, OFFICE_Y + math.min(j + 20, OFFICE_H))
        end
    end

    -- Stone walls
    love.graphics.setColor(0.78, 0.72, 0.62)
    love.graphics.rectangle("fill", OFFICE_X, OFFICE_Y - 20, OFFICE_W, 25)
    love.graphics.setColor(0.60, 0.52, 0.40)
    love.graphics.rectangle("fill", OFFICE_X, OFFICE_Y + 2, OFFICE_W, 3)

    -- Wall detail (stone line)
    love.graphics.setColor(0.65, 0.58, 0.48)
    love.graphics.line(OFFICE_X, OFFICE_Y - 20, OFFICE_X + OFFICE_W, OFFICE_Y - 20)

    -- Arched window on wall (stained glass)
    local season = self:getSeason(year)
    -- Sky color based on season
    local skyR, skyG, skyB = 0.55, 0.70, 0.85
    if season == "winter" then
        skyR, skyG, skyB = 0.75, 0.78, 0.85
    elseif season == "autumn" then
        skyR, skyG, skyB = 0.80, 0.65, 0.45
    elseif season == "summer" then
        skyR, skyG, skyB = 0.50, 0.72, 0.92
    end

    -- Left arched window
    love.graphics.setColor(skyR, skyG, skyB)
    love.graphics.rectangle("fill", OFFICE_X + 100, OFFICE_Y - 18, 40, 16)
    -- Arch top
    love.graphics.circle("fill", OFFICE_X + 120, OFFICE_Y - 18, 20, 20)
    -- Stained glass cross pattern
    love.graphics.setColor(0.45, 0.35, 0.25)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", OFFICE_X + 100, OFFICE_Y - 18, 40, 18)
    love.graphics.line(OFFICE_X + 120, OFFICE_Y - 18, OFFICE_X + 120, OFFICE_Y)
    love.graphics.line(OFFICE_X + 100, OFFICE_Y - 10, OFFICE_X + 140, OFFICE_Y - 10)
    -- Stained glass color hints
    love.graphics.setColor(0.85, 0.30, 0.25, 0.2)
    love.graphics.rectangle("fill", OFFICE_X + 101, OFFICE_Y - 17, 19, 7)
    love.graphics.setColor(0.25, 0.45, 0.75, 0.2)
    love.graphics.rectangle("fill", OFFICE_X + 121, OFFICE_Y - 17, 19, 7)
    love.graphics.setColor(0.70, 0.60, 0.15, 0.2)
    love.graphics.rectangle("fill", OFFICE_X + 101, OFFICE_Y - 9, 19, 7)
    love.graphics.setColor(0.25, 0.60, 0.30, 0.2)
    love.graphics.rectangle("fill", OFFICE_X + 121, OFFICE_Y - 9, 19, 7)

    -- Right arched window
    love.graphics.setColor(skyR, skyG, skyB)
    love.graphics.rectangle("fill", OFFICE_X + 240, OFFICE_Y - 18, 40, 16)
    love.graphics.circle("fill", OFFICE_X + 260, OFFICE_Y - 18, 20, 20)
    love.graphics.setColor(0.45, 0.35, 0.25)
    love.graphics.rectangle("line", OFFICE_X + 240, OFFICE_Y - 18, 40, 18)
    love.graphics.line(OFFICE_X + 260, OFFICE_Y - 18, OFFICE_X + 260, OFFICE_Y)
    love.graphics.line(OFFICE_X + 240, OFFICE_Y - 10, OFFICE_X + 280, OFFICE_Y - 10)
    -- Stained glass color hints
    love.graphics.setColor(0.70, 0.25, 0.55, 0.2)
    love.graphics.rectangle("fill", OFFICE_X + 241, OFFICE_Y - 17, 19, 7)
    love.graphics.setColor(0.25, 0.60, 0.30, 0.2)
    love.graphics.rectangle("fill", OFFICE_X + 261, OFFICE_Y - 17, 19, 7)
    love.graphics.setColor(0.25, 0.45, 0.75, 0.2)
    love.graphics.rectangle("fill", OFFICE_X + 241, OFFICE_Y - 9, 19, 7)
    love.graphics.setColor(0.85, 0.70, 0.15, 0.2)
    love.graphics.rectangle("fill", OFFICE_X + 261, OFFICE_Y - 9, 19, 7)

    love.graphics.setLineWidth(1)

    -- Border
    love.graphics.setColor(0.45, 0.38, 0.28)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", OFFICE_X, OFFICE_Y - 20, OFFICE_W, OFFICE_H + 20, 4, 4)
    love.graphics.setLineWidth(1)
end

function Office:getSeason(year)
    local weekInYear = (self.time * 2) % 52
    if weekInYear < 13 then return "spring"
    elseif weekInYear < 26 then return "summer"
    elseif weekInYear < 39 then return "autumn"
    else return "winter" end
end

function Office:drawDesks(staffList)
    for d = 1, #DESK_POSITIONS do
        local pos = DESK_POSITIONS[d]
        local dx = OFFICE_X + pos.x
        local dy = OFFICE_Y + pos.y

        -- Writing desk surface (dark oak)
        love.graphics.setColor(0.50, 0.35, 0.20)
        love.graphics.rectangle("fill", dx - 22, dy - 5, 44, 18, 2, 2)

        -- Desk front panel
        love.graphics.setColor(0.42, 0.30, 0.18)
        love.graphics.rectangle("fill", dx - 22, dy + 10, 44, 6, 0, 0, 2, 2)

        -- Desk legs
        love.graphics.setColor(0.38, 0.26, 0.15)
        love.graphics.rectangle("fill", dx - 20, dy + 14, 3, 5)
        love.graphics.rectangle("fill", dx + 17, dy + 14, 3, 5)

        -- Check if desk has occupant
        local hasOccupant = false
        for _, sd in pairs(self.staffPositions) do
            if sd == d then hasOccupant = true break end
        end

        if hasOccupant then
            -- Candle on desk
            love.graphics.setColor(0.90, 0.85, 0.60) -- wax
            love.graphics.rectangle("fill", dx - 10, dy - 16, 3, 10)
            -- Candle flame
            local flicker = 0.8 + 0.2 * math.sin(self.time * 8 + d * 2.1)
            love.graphics.setColor(1, 0.85, 0.2, flicker)
            love.graphics.circle("fill", dx - 8.5, dy - 18, 2.5)
            love.graphics.setColor(1, 0.60, 0.1, flicker * 0.5)
            love.graphics.circle("fill", dx - 8.5, dy - 19, 1.5)

            -- Candle glow when working
            if self.developing then
                local glow = 0.15 + 0.1 * math.sin(self.time * 3 + d)
                love.graphics.setColor(1, 0.85, 0.3, glow)
                love.graphics.circle("fill", dx - 8.5, dy - 16, 12)
            end

            -- Quill and inkwell
            love.graphics.setColor(0.15, 0.12, 0.10) -- inkwell
            love.graphics.rectangle("fill", dx + 5, dy - 8, 6, 6, 1, 1)
            love.graphics.setColor(0.10, 0.10, 0.30) -- ink
            love.graphics.rectangle("fill", dx + 6, dy - 7, 4, 3)
            -- Quill feather
            love.graphics.setColor(0.90, 0.88, 0.82)
            love.graphics.line(dx + 8, dy - 8, dx + 14, dy - 18)
            love.graphics.line(dx + 14, dy - 18, dx + 16, dy - 20)
            love.graphics.setColor(0.80, 0.78, 0.70)
            love.graphics.line(dx + 14, dy - 18, dx + 12, dy - 16)

            -- Manuscript/parchment on desk
            love.graphics.setColor(0.92, 0.87, 0.72)
            love.graphics.rectangle("fill", dx - 6, dy - 3, 14, 10, 1, 1)
            -- Text lines on parchment
            love.graphics.setColor(0.30, 0.25, 0.18, 0.4)
            for line = 0, 3 do
                love.graphics.line(dx - 4, dy - 1 + line * 2.5, dx + 4 + math.random(-2, 2), dy - 1 + line * 2.5)
            end
        end
    end
end

function Office:drawDecorations(year)
    -- Library shelves on left wall
    love.graphics.setColor(0.45, 0.30, 0.18)
    love.graphics.rectangle("fill", OFFICE_X + 8, OFFICE_Y + 8, 25, 50, 2, 2)
    -- Books/manuscripts
    local bookColors = {{0.70,0.15,0.10}, {0.12,0.35,0.55}, {0.50,0.40,0.10}, {0.55,0.20,0.35}, {0.20,0.45,0.25}}
    for i = 0, 4 do
        love.graphics.setColor(bookColors[i+1])
        love.graphics.rectangle("fill", OFFICE_X + 10 + i * 4, OFFICE_Y + 10, 3, 14)
    end
    for i = 0, 3 do
        love.graphics.setColor(bookColors[(i+2) % 5 + 1])
        love.graphics.rectangle("fill", OFFICE_X + 10 + i * 5, OFFICE_Y + 30, 4, 12)
    end
    -- Shelves
    love.graphics.setColor(0.40, 0.28, 0.15)
    love.graphics.rectangle("fill", OFFICE_X + 8, OFFICE_Y + 25, 25, 2)
    love.graphics.rectangle("fill", OFFICE_X + 8, OFFICE_Y + 43, 25, 2)

    -- Crucifix on wall (replaces whiteboard)
    local cx = OFFICE_X + 55
    local cy = OFFICE_Y - 10
    love.graphics.setColor(0.50, 0.35, 0.20) -- dark wood cross
    love.graphics.rectangle("fill", cx - 1, cy - 8, 3, 16) -- vertical beam
    love.graphics.rectangle("fill", cx - 5, cy - 4, 11, 3)  -- horizontal beam
    -- Christ figure (tiny)
    love.graphics.setColor(0.85, 0.75, 0.60)
    love.graphics.circle("fill", cx + 0.5, cy - 3, 1.5) -- head
    love.graphics.rectangle("fill", cx - 0.5, cy - 1, 2, 4) -- body

    -- Herb garden visible through right side (potted herbs)
    local hx = OFFICE_X + OFFICE_W - 38
    local hy = OFFICE_Y + OFFICE_H - 35
    -- Clay pot
    love.graphics.setColor(0.65, 0.40, 0.25)
    love.graphics.rectangle("fill", hx, hy + 15, 18, 14, 2, 2)
    love.graphics.setColor(0.58, 0.35, 0.20)
    love.graphics.rectangle("fill", hx - 1, hy + 13, 20, 4, 1, 1)
    -- Herbs
    love.graphics.setColor(0.25, 0.55, 0.20)
    love.graphics.circle("fill", hx + 5, hy + 8, 6)
    love.graphics.circle("fill", hx + 13, hy + 6, 5)
    love.graphics.setColor(0.20, 0.50, 0.15)
    love.graphics.circle("fill", hx + 9, hy + 4, 7)
    -- Small flowers
    love.graphics.setColor(0.85, 0.75, 0.20, 0.7)
    love.graphics.circle("fill", hx + 7, hy + 2, 1.5)
    love.graphics.circle("fill", hx + 12, hy + 3, 1.5)

    -- Reliquary / honor cross on wall (instead of award trophy)
    if year and year > 2 then
        local rx = OFFICE_X + OFFICE_W - 55
        local ry = OFFICE_Y - 14
        love.graphics.setColor(0.85, 0.70, 0.15)
        love.graphics.rectangle("fill", rx, ry, 2, 10)    -- vertical
        love.graphics.rectangle("fill", rx - 3, ry + 2, 8, 2) -- horizontal
        love.graphics.circle("fill", rx + 1, ry + 1, 1.5) -- top ornament
    end

    -- Hourglass on wall (replaces clock)
    local hgx = OFFICE_X + OFFICE_W - 25
    local hgy = OFFICE_Y - 14
    -- Frame
    love.graphics.setColor(0.50, 0.38, 0.25)
    love.graphics.rectangle("fill", hgx - 4, hgy, 8, 2)   -- top bar
    love.graphics.rectangle("fill", hgx - 4, hgy + 12, 8, 2) -- bottom bar
    -- Glass bulbs
    love.graphics.setColor(0.85, 0.82, 0.75, 0.6)
    love.graphics.polygon("fill", hgx - 3, hgy + 2, hgx + 3, hgy + 2, hgx, hgy + 7)   -- top
    love.graphics.polygon("fill", hgx - 3, hgy + 12, hgx + 3, hgy + 12, hgx, hgy + 7)  -- bottom
    -- Sand
    local sandProgress = (self.time * 0.1) % 1
    love.graphics.setColor(0.85, 0.75, 0.45)
    -- Top sand (decreasing)
    local topSandH = (1 - sandProgress) * 3
    if topSandH > 0.5 then
        love.graphics.rectangle("fill", hgx - 2, hgy + 3, 4, topSandH)
    end
    -- Bottom sand (increasing)
    local botSandH = sandProgress * 3
    if botSandH > 0.5 then
        love.graphics.rectangle("fill", hgx - 2, hgy + 12 - botSandH, 4, botSandH)
    end
    -- Falling stream
    love.graphics.setColor(0.85, 0.75, 0.45, 0.5)
    love.graphics.line(hgx, hgy + 6, hgx, hgy + 8)

    -- Candle sconce on right wall
    local scx = OFFICE_X + OFFICE_W - 15
    local scy = OFFICE_Y + 15
    love.graphics.setColor(0.45, 0.38, 0.28) -- bracket
    love.graphics.rectangle("fill", scx, scy, 3, 8)
    love.graphics.rectangle("fill", scx - 2, scy + 6, 7, 3)
    love.graphics.setColor(0.90, 0.85, 0.60) -- candle
    love.graphics.rectangle("fill", scx, scy - 6, 3, 8)
    -- Flame
    local flicker = 0.8 + 0.2 * math.sin(self.time * 6)
    love.graphics.setColor(1, 0.80, 0.2, flicker)
    love.graphics.circle("fill", scx + 1.5, scy - 8, 2)
    love.graphics.setColor(1, 0.55, 0.1, flicker * 0.4)
    love.graphics.circle("fill", scx + 1.5, scy - 8, 4)
end

return Office
