local UI = require("ui")
local Game = require("game")
local Save = require("save")
local Audio = require("audio")

-------------------------------------------------------------------------------
-- GLOBALS
-------------------------------------------------------------------------------
local BASE_W, BASE_H = 480, 320
local scaleX, scaleY = 1, 1
local state = "menu"  -- menu, nameinput, playing
local game = nil
local nameInput = nil
local menuButtons = {}
local menuTime = 0
local menuParticles = {}
local transition = {active = false, alpha = 0, target = "", callback = nil}

-------------------------------------------------------------------------------
-- LOVE CALLBACKS
-------------------------------------------------------------------------------
function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    math.randomseed(os.time())
    UI.initFonts()
    Audio.init()

    local w, h = love.graphics.getDimensions()
    scaleX = w / BASE_W
    scaleY = h / BASE_H

    setupMenu()
end

function love.resize(w, h)
    scaleX = w / BASE_W
    scaleY = h / BASE_H
end

function love.update(dt)
    dt = math.min(dt, 0.05)

    -- Transition effect
    if transition.active then
        if transition.fading == "out" then
            transition.alpha = transition.alpha + dt * 4
            if transition.alpha >= 1 then
                transition.alpha = 1
                transition.fading = "in"
                if transition.callback then transition.callback() end
            end
        elseif transition.fading == "in" then
            transition.alpha = transition.alpha - dt * 4
            if transition.alpha <= 0 then
                transition.alpha = 0
                transition.active = false
            end
        end
    end

    if state == "menu" then
        updateMenu(dt)
    elseif state == "nameinput" then
        if nameInput then nameInput:update(dt) end
        UI.updateToasts(dt)
    elseif state == "playing" then
        game:update(dt)
        if game.wantsRestart then
            game.wantsRestart = false
            doTransition(function()
                state = "nameinput"
                game = nil
                nameInput = UI.TextInput.new(140, 160, 200, 28, {
                    placeholder = "Monastery name...",
                    default = "",
                    maxLen = 18,
                })
            end)
        end
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.scale(scaleX, scaleY)

    if state == "menu" then
        drawMenu()
    elseif state == "nameinput" then
        drawNameInput()
    elseif state == "playing" then
        game:draw()
    end

    -- Transition overlay
    if transition.active then
        love.graphics.setColor(0, 0, 0, transition.alpha)
        love.graphics.rectangle("fill", 0, 0, BASE_W, BASE_H)
    end

    love.graphics.pop()
end

function love.mousepressed(x, y, button)
    if transition.active then return end
    local mx = x / scaleX
    local my = y / scaleY

    if state == "menu" then
        menuMousepressed(mx, my, button)
    elseif state == "nameinput" then
        nameInputMousepressed(mx, my, button)
    elseif state == "playing" then
        game:mousepressed(mx, my, button)
    end
end

function love.mousereleased(x, y, button)
    if state == "playing" and game then
        local mx = x / scaleX
        local my = y / scaleY
        game:mousereleased(mx, my, button)
    end
    for _, b in ipairs(menuButtons) do b:release() end
end

function love.wheelmoved(x, y)
    if state == "playing" and game then
        game:wheelmoved(x, y)
    end
end

function love.keypressed(key)
    if transition.active then return end

    if state == "nameinput" then
        if nameInput then nameInput:keypressed(key) end
        if key == "return" or key == "kpenter" then
            local name = nameInput:getText()
            if #name == 0 then name = "Sancta Maria" end
            doTransition(function() startGame(name) end)
        elseif key == "escape" then
            doTransition(function() state = "menu"; setupMenu() end)
        end
    elseif state == "playing" then
        game:keypressed(key)
    elseif state == "menu" then
        if key == "return" or key == "kpenter" then
            goToNameInput()
        end
    end
end

function love.textinput(text)
    if state == "nameinput" then
        if nameInput then nameInput:textinput(text) end
    elseif state == "playing" then
        game:textinput(text)
    end
end

-------------------------------------------------------------------------------
-- TRANSITIONS
-------------------------------------------------------------------------------
function doTransition(callback)
    transition.active = true
    transition.alpha = 0
    transition.fading = "out"
    transition.callback = callback
end

-------------------------------------------------------------------------------
-- MENU STATE
-------------------------------------------------------------------------------
function setupMenu()
    local centerX = BASE_W / 2
    local btnW = 160
    local btnH = 36
    local hasSave = Save.hasSave()

    menuButtons = {}

    table.insert(menuButtons, UI.Button.new("New Game", centerX - btnW/2, 170, btnW, btnH, function()
        goToNameInput()
    end, {
        color = {0.45, 0.35, 0.20},
        hoverColor = {0.55, 0.42, 0.25},
        pressColor = {0.38, 0.28, 0.15},
        textColor = {1, 0.95, 0.80},
        fontSize = "medium",
        radius = 8,
    }))

    if hasSave then
        table.insert(menuButtons, UI.Button.new("Continue", centerX - btnW/2, 212, btnW, btnH, function()
            doTransition(function() loadAndStart() end)
        end, {
            color = {0.35, 0.30, 0.45},
            hoverColor = {0.42, 0.35, 0.55},
            pressColor = {0.28, 0.22, 0.38},
            textColor = {1, 0.95, 0.80},
            fontSize = "medium",
            radius = 8,
        }))
    end

    local aboutY = hasSave and 254 or 212
    table.insert(menuButtons, UI.Button.new("About", centerX - btnW/2, aboutY, btnW, btnH, function()
        UI.addToast("Ora et Labora - Made with LOVE2D", 3, UI.colors.accent)
        UI.addToast("A monastery management simulator", 3, UI.colors.textLight)
    end, {
        color = UI.colors.button,
        hoverColor = UI.colors.buttonHover,
        pressColor = UI.colors.buttonPress,
        fontSize = "medium",
        radius = 8,
    }))
end

function menuMousepressed(mx, my, button)
    if button ~= 1 then return end
    for _, b in ipairs(menuButtons) do
        if b:click(mx, my) then return end
    end
end

function goToNameInput()
    doTransition(function()
        state = "nameinput"
        nameInput = UI.TextInput.new(140, 160, 200, 28, {
            placeholder = "Monastery name...",
            default = "",
            maxLen = 18,
        })
    end)
end

function updateMenu(dt)
    menuTime = menuTime + dt
    local mx, my = love.mouse.getPosition()
    mx = mx / scaleX
    my = my / scaleY
    for _, b in ipairs(menuButtons) do b:update(mx, my) end
    UI.updateToasts(dt)

    -- Background particles (gentle motes of light / dust in sunbeam)
    if math.random() < 0.10 then
        table.insert(menuParticles, {
            x = math.random() * BASE_W,
            y = BASE_H + 5,
            vx = (math.random() - 0.5) * 10,
            vy = -8 - math.random() * 15,
            life = 4 + math.random() * 4,
            maxLife = 8,
            size = 1 + math.random() * 2,
            color = {
                0.85 + math.random() * 0.15,
                0.75 + math.random() * 0.20,
                0.40 + math.random() * 0.30,
            },
        })
    end
    for i = #menuParticles, 1, -1 do
        local p = menuParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(menuParticles, i)
        end
    end
end

function drawMenu()
    -- Background gradient (deep warm tones)
    for i = 0, BASE_H, 2 do
        local t = i / BASE_H
        love.graphics.setColor(
            0.18 + t * 0.12,
            0.12 + t * 0.08,
            0.08 + t * 0.06
        )
        love.graphics.rectangle("fill", 0, i, BASE_W, 2)
    end

    -- Background particles (golden dust motes)
    for _, p in ipairs(menuParticles) do
        local alpha = math.max(0, (p.life / p.maxLife) * 0.3)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end

    -- Title shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    UI.setFont("title")
    love.graphics.printf("Ora et Labora", 2, 42, BASE_W, "center")

    -- Title with bob
    local titleBob = math.sin(menuTime * 1.5) * 3
    love.graphics.setColor(0.90, 0.78, 0.35)
    love.graphics.printf("Ora et Labora", 0, 38 + titleBob, BASE_W, "center")

    -- Subtitle
    love.graphics.setColor(0.75, 0.65, 0.50)
    UI.setFont("small")
    love.graphics.printf("Guide your monastery to glory", 0, 78 + titleBob, BASE_W, "center")

    -- Version / credit
    love.graphics.setColor(0.5, 0.42, 0.32)
    UI.setFont("tiny")
    love.graphics.printf("Made with LOVE2D | Pray and Work", 0, 98, BASE_W, "center")

    -- Decorative monastic icons
    drawMenuDecorations()

    -- Buttons
    for _, b in ipairs(menuButtons) do b:draw() end

    -- Toasts
    UI.drawToasts()

    -- Footer
    love.graphics.setColor(0.45, 0.38, 0.28)
    UI.setFont("tiny")
    love.graphics.printf("[Space] Pause | [1/2/3] Speed | [Esc] Close | [S] Save", 0, BASE_H - 14, BASE_W, "center")
end

function drawMenuDecorations()
    local t = menuTime

    -- Floating book (left)
    local cx, cy = 70 + math.sin(t * 0.7) * 12, 140 + math.cos(t * 0.5) * 8
    love.graphics.setColor(0.50, 0.35, 0.20, 0.6)
    love.graphics.rectangle("fill", cx - 12, cy - 8, 24, 16, 2, 2)
    -- Book spine
    love.graphics.setColor(0.65, 0.50, 0.25, 0.6)
    love.graphics.rectangle("fill", cx - 12, cy - 8, 3, 16)
    -- Pages
    love.graphics.setColor(0.90, 0.85, 0.72, 0.5)
    love.graphics.rectangle("fill", cx - 8, cy - 6, 18, 12)
    -- Text lines
    love.graphics.setColor(0.40, 0.35, 0.25, 0.3)
    for line = 0, 2 do
        love.graphics.line(cx - 6, cy - 4 + line * 4, cx + 6, cy - 4 + line * 4)
    end

    -- Floating quill (right)
    cx, cy = 410 + math.cos(t * 0.6) * 12, 140 + math.sin(t * 0.8) * 8
    -- Feather shaft
    love.graphics.setColor(0.88, 0.85, 0.75, 0.6)
    love.graphics.line(cx - 8, cy + 8, cx + 8, cy - 8)
    -- Feather barbs
    love.graphics.setColor(0.82, 0.78, 0.65, 0.5)
    love.graphics.line(cx + 4, cy - 4, cx + 10, cy - 8)
    love.graphics.line(cx + 2, cy - 2, cx + 8, cy - 6)
    -- Nib
    love.graphics.setColor(0.30, 0.25, 0.20, 0.6)
    love.graphics.line(cx - 8, cy + 8, cx - 10, cy + 12)

    -- Cross (center top)
    local crossX = 240 + math.sin(t * 0.8) * 5
    local crossY = 118 + math.cos(t * 1.0) * 3
    love.graphics.setColor(0.85, 0.70, 0.20, 0.4)
    love.graphics.rectangle("fill", crossX - 1, crossY - 6, 3, 12)
    love.graphics.rectangle("fill", crossX - 4, crossY - 3, 9, 3)

    -- Candle (left area)
    cx, cy = 140 + math.sin(t * 0.4) * 15, 128 + math.cos(t * 0.3) * 4
    love.graphics.setColor(0.88, 0.82, 0.55, 0.5)
    love.graphics.rectangle("fill", cx - 2, cy - 5, 4, 10)
    -- Flame
    local flicker = 0.5 + 0.2 * math.sin(t * 6)
    love.graphics.setColor(1, 0.80, 0.20, flicker)
    love.graphics.circle("fill", cx, cy - 7, 3)
    love.graphics.setColor(1, 0.60, 0.10, flicker * 0.5)
    love.graphics.circle("fill", cx, cy - 8, 2)

    -- Scroll (right area)
    cx, cy = 340 + math.cos(t * 0.5) * 12, 128 + math.sin(t * 0.7) * 4
    love.graphics.setColor(0.88, 0.82, 0.65, 0.5)
    love.graphics.rectangle("fill", cx - 10, cy - 6, 20, 12, 1, 1)
    -- Scroll rolls
    love.graphics.setColor(0.82, 0.75, 0.55, 0.5)
    love.graphics.circle("fill", cx - 10, cy, 3)
    love.graphics.circle("fill", cx + 10, cy, 3)

    -- Small stars / sparkles
    local sx, sy = 55 + math.sin(t * 1.2) * 5, 70 + math.cos(t * 0.9) * 5
    UI.drawStar(sx, sy, 6, 3, {0.85, 0.70, 0.20, 0.4})
    sx, sy = 425 + math.cos(t * 1.1) * 5, 75 + math.sin(t * 1.3) * 5
    UI.drawStar(sx, sy, 5, 2.5, {0.85, 0.70, 0.20, 0.3})
end

-------------------------------------------------------------------------------
-- NAME INPUT STATE
-------------------------------------------------------------------------------
function nameInputMousepressed(mx, my, button)
    if button ~= 1 then return end
    if mx >= 170 and mx <= 310 and my >= 200 and my <= 232 then
        local name = nameInput:getText()
        if #name == 0 then name = "Sancta Maria" end
        doTransition(function() startGame(name) end)
    end
    if mx >= 170 and mx <= 310 and my >= 240 and my <= 268 then
        doTransition(function() state = "menu"; setupMenu() end)
    end
end

function drawNameInput()
    -- Background
    for i = 0, BASE_H, 2 do
        local t = i / BASE_H
        love.graphics.setColor(
            0.18 + t * 0.12,
            0.12 + t * 0.08,
            0.08 + t * 0.06
        )
        love.graphics.rectangle("fill", 0, i, BASE_W, 2)
    end

    -- Panel
    UI.drawPanel(100, 80, 280, 200, {
        title = "Found a Monastery",
        shadow = true,
        radius = 10,
    })

    -- Instructions
    love.graphics.setColor(UI.colors.text)
    UI.setFont("normal")
    love.graphics.printf("Name your monastery:", 100, 120, 280, "center")

    -- Name input
    if nameInput then nameInput:draw() end

    -- Start button
    local mx, my = love.mouse.getPosition()
    mx = mx / scaleX
    my = my / scaleY

    local startHover = mx >= 170 and mx <= 310 and my >= 200 and my <= 232
    love.graphics.setColor(startHover and {0.55, 0.42, 0.25} or {0.45, 0.35, 0.20})
    love.graphics.rectangle("fill", 170, 200, 140, 32, 6, 6)
    love.graphics.setColor(1, 0.95, 0.80)
    UI.setFont("medium")
    love.graphics.printf("Begin!", 170, 206, 140, "center")

    -- Back button
    local backHover = mx >= 170 and mx <= 310 and my >= 240 and my <= 268
    love.graphics.setColor(backHover and UI.colors.buttonHover or UI.colors.button)
    love.graphics.rectangle("fill", 170, 242, 140, 28, 6, 6)
    love.graphics.setColor(UI.colors.text)
    UI.setFont("normal")
    love.graphics.printf("Back", 170, 248, 140, "center")

    -- Toasts
    UI.drawToasts()

    -- Hint
    love.graphics.setColor(0.5, 0.42, 0.32)
    UI.setFont("tiny")
    love.graphics.printf("Press Enter to begin", 0, BASE_H - 20, BASE_W, "center")
end

-------------------------------------------------------------------------------
-- GAME START / LOAD
-------------------------------------------------------------------------------
function startGame(companyName)
    game = Game.new(companyName)
    state = "playing"
    Audio.play("start")
end

function loadAndStart()
    local data, err = Save.loadGame()
    if data then
        game = Game.new(data.companyName or "Loaded Abbey")
        Save.applyToGame(game, data)
        state = "playing"
        UI.addToast("Progress restored!", 2, UI.colors.success)
    else
        UI.addToast("Failed to load: " .. (err or "unknown error"), 3, UI.colors.danger)
        state = "menu"
        setupMenu()
    end
end
