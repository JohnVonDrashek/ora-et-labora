local UI = {}

-------------------------------------------------------------------------------
-- COLORS
-------------------------------------------------------------------------------
UI.colors = {
    bg          = {240/255, 230/255, 214/255},
    panel       = {255/255, 248/255, 232/255},
    panelDark   = {230/255, 218/255, 198/255},
    panelBorder = {140/255, 115/255, 85/255},
    text        = {74/255, 55/255, 40/255},
    textLight   = {130/255, 110/255, 85/255},
    textWhite   = {1, 1, 1},
    accent      = {74/255, 144/255, 217/255},
    accentDark  = {50/255, 110/255, 180/255},
    success     = {92/255, 184/255, 92/255},
    danger      = {217/255, 83/255, 79/255},
    warning     = {240/255, 173/255, 78/255},
    button      = {230/255, 215/255, 190/255},
    buttonHover = {215/255, 198/255, 170/255},
    buttonPress = {200/255, 182/255, 155/255},
    gold        = {218/255, 165/255, 32/255},
    silver      = {192/255, 192/255, 192/255},
    bronze      = {205/255, 127/255, 50/255},
    overlay     = {0, 0, 0, 0.4},
    barBg       = {180/255, 170/255, 155/255},
    money       = {185/255, 155/255, 40/255},
    expBar      = {100/255, 180/255, 255/255},
}

UI.fonts = {}
UI.toasts = {}
UI.activeDialogs = {} -- stack of dialogs

-------------------------------------------------------------------------------
-- FONT MANAGEMENT
-------------------------------------------------------------------------------
function UI.initFonts()
    UI.fonts.small  = love.graphics.newFont(11)
    UI.fonts.normal = love.graphics.newFont(13)
    UI.fonts.medium = love.graphics.newFont(16)
    UI.fonts.large  = love.graphics.newFont(22)
    UI.fonts.title  = love.graphics.newFont(32)
    UI.fonts.tiny   = love.graphics.newFont(9)
end

function UI.setFont(name)
    love.graphics.setFont(UI.fonts[name] or UI.fonts.normal)
end

-------------------------------------------------------------------------------
-- DRAWING HELPERS
-------------------------------------------------------------------------------
function UI.drawPanel(x, y, w, h, opts)
    opts = opts or {}
    local r = opts.radius or 6
    local borderW = opts.borderWidth or 2
    local bgColor = opts.bgColor or UI.colors.panel
    local borderColor = opts.borderColor or UI.colors.panelBorder

    -- Shadow
    if opts.shadow then
        love.graphics.setColor(0, 0, 0, 0.15)
        love.graphics.rectangle("fill", x+3, y+3, w, h, r, r)
    end

    -- Background
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h, r, r)

    -- Border
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(borderW)
    love.graphics.rectangle("line", x, y, w, h, r, r)

    -- Title bar
    if opts.title then
        love.graphics.setColor(borderColor)
        love.graphics.rectangle("fill", x, y, w, 28, r, r)
        love.graphics.rectangle("fill", x, y+14, w, 14)
        love.graphics.setColor(UI.colors.textWhite)
        UI.setFont("normal")
        love.graphics.printf(opts.title, x, y+6, w, "center")
    end

    love.graphics.setLineWidth(1)
end

function UI.drawProgressBar(x, y, w, h, progress, color, bgColor)
    progress = math.max(0, math.min(1, progress))
    love.graphics.setColor(bgColor or UI.colors.barBg)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)
    if progress > 0 then
        love.graphics.setColor(color or UI.colors.accent)
        love.graphics.rectangle("fill", x, y, w * progress, h, 3, 3)
    end
    love.graphics.setColor(UI.colors.panelBorder)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 3, 3)
end

function UI.drawStar(cx, cy, outerR, innerR, color)
    love.graphics.setColor(color or UI.colors.gold)
    local vertices = {}
    for i = 0, 9 do
        local angle = (i * math.pi / 5) - math.pi / 2
        local r = (i % 2 == 0) and outerR or innerR
        table.insert(vertices, cx + math.cos(angle) * r)
        table.insert(vertices, cy + math.sin(angle) * r)
    end
    love.graphics.polygon("fill", vertices)
end

-------------------------------------------------------------------------------
-- BUTTON CLASS
-------------------------------------------------------------------------------
UI.Button = {}
UI.Button.__index = UI.Button

function UI.Button.new(text, x, y, w, h, callback, opts)
    opts = opts or {}
    local self = setmetatable({}, UI.Button)
    self.text = text
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.callback = callback
    self.hovered = false
    self.pressed = false
    self.enabled = opts.enabled ~= false
    self.color = opts.color or UI.colors.button
    self.hoverColor = opts.hoverColor or UI.colors.buttonHover
    self.pressColor = opts.pressColor or UI.colors.buttonPress
    self.textColor = opts.textColor or UI.colors.text
    self.fontSize = opts.fontSize or "normal"
    self.icon = opts.icon
    self.visible = opts.visible ~= false
    self.radius = opts.radius or 5
    return self
end

function UI.Button:update(mx, my)
    if not self.visible or not self.enabled then
        self.hovered = false
        return
    end
    self.hovered = mx >= self.x and mx <= self.x + self.w
                and my >= self.y and my <= self.y + self.h
end

function UI.Button:draw()
    if not self.visible then return end
    local color = self.color
    if not self.enabled then
        color = UI.colors.panelDark
    elseif self.pressed then
        color = self.pressColor
    elseif self.hovered then
        color = self.hoverColor
    end

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.1)
    love.graphics.rectangle("fill", self.x+1, self.y+2, self.w, self.h, self.radius, self.radius)

    love.graphics.setColor(color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, self.radius, self.radius)
    love.graphics.setColor(UI.colors.panelBorder)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, self.radius, self.radius)

    local textColor = self.enabled and self.textColor or UI.colors.textLight
    love.graphics.setColor(textColor)
    UI.setFont(self.fontSize)
    local textY = self.y + (self.h - UI.fonts[self.fontSize]:getHeight()) / 2
    if self.icon then
        love.graphics.printf(self.icon .. " " .. self.text, self.x + 8, textY, self.w - 16, "center")
    else
        love.graphics.printf(self.text, self.x, textY, self.w, "center")
    end
    love.graphics.setLineWidth(1)
end

function UI.Button:click(mx, my)
    if not self.visible or not self.enabled then return false end
    if mx >= self.x and mx <= self.x + self.w and my >= self.y and my <= self.y + self.h then
        self.pressed = true
        -- Play click sound
        local ok, Audio = pcall(require, "audio")
        if ok and Audio.play then Audio.play("click") end
        if self.callback then self.callback() end
        return true
    end
    return false
end

function UI.Button:release()
    self.pressed = false
end

-------------------------------------------------------------------------------
-- SCROLL LIST CLASS
-------------------------------------------------------------------------------
UI.ScrollList = {}
UI.ScrollList.__index = UI.ScrollList

function UI.ScrollList.new(x, y, w, h, itemHeight, items, opts)
    opts = opts or {}
    local self = setmetatable({}, UI.ScrollList)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.itemHeight = itemHeight or 30
    self.items = items or {}
    self.scroll = 0
    self.selected = opts.selected or 0
    self.hovered = -1
    self.onSelect = opts.onSelect
    self.renderItem = opts.renderItem
    self.maxScroll = 0
    self.scrollBarDragging = false
    self.visible = true
    return self
end

function UI.ScrollList:setItems(items)
    self.items = items
    self.scroll = 0
    self.selected = 0
    self:updateMaxScroll()
end

function UI.ScrollList:updateMaxScroll()
    local totalHeight = #self.items * self.itemHeight
    self.maxScroll = math.max(0, totalHeight - self.h)
end

function UI.ScrollList:update(mx, my)
    if not self.visible then return end
    self:updateMaxScroll()
    self.hovered = -1
    if mx >= self.x and mx <= self.x + self.w and my >= self.y and my <= self.y + self.h then
        local localY = my - self.y + self.scroll
        local idx = math.floor(localY / self.itemHeight) + 1
        if idx >= 1 and idx <= #self.items then
            self.hovered = idx
        end
    end
end

function UI.ScrollList:draw()
    if not self.visible then return end

    -- Clip region (setScissor uses screen coords, must transform from virtual coords)
    local sx, sy = love.graphics.transformPoint(self.x, self.y)
    local ex, ey = love.graphics.transformPoint(self.x + self.w, self.y + self.h)
    love.graphics.setScissor(sx, sy, ex - sx, ey - sy)

    -- Background
    love.graphics.setColor(UI.colors.panel)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)

    -- Items
    for i, item in ipairs(self.items) do
        local iy = self.y + (i-1) * self.itemHeight - self.scroll
        if iy + self.itemHeight > self.y and iy < self.y + self.h then
            -- Highlight
            if i == self.selected then
                love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], 0.3)
                love.graphics.rectangle("fill", self.x, iy, self.w - 12, self.itemHeight)
            elseif i == self.hovered then
                love.graphics.setColor(UI.colors.buttonHover)
                love.graphics.rectangle("fill", self.x, iy, self.w - 12, self.itemHeight)
            end

            if self.renderItem then
                self.renderItem(item, self.x, iy, self.w - 12, self.itemHeight, i == self.selected)
            else
                love.graphics.setColor(UI.colors.text)
                UI.setFont("normal")
                local text = type(item) == "table" and (item.name or item.text or tostring(item)) or tostring(item)
                love.graphics.print(text, self.x + 8, iy + (self.itemHeight - UI.fonts.normal:getHeight()) / 2)
            end

            -- Separator
            love.graphics.setColor(UI.colors.panelDark)
            love.graphics.line(self.x + 4, iy + self.itemHeight, self.x + self.w - 16, iy + self.itemHeight)
        end
    end

    love.graphics.setScissor()

    -- Scrollbar
    if self.maxScroll > 0 then
        local barH = math.max(20, self.h * (self.h / (self.h + self.maxScroll)))
        local barY = self.y + (self.scroll / self.maxScroll) * (self.h - barH)
        love.graphics.setColor(UI.colors.panelDark)
        love.graphics.rectangle("fill", self.x + self.w - 10, self.y, 10, self.h, 3, 3)
        love.graphics.setColor(UI.colors.panelBorder)
        love.graphics.rectangle("fill", self.x + self.w - 9, barY, 8, barH, 3, 3)
    end

    -- Border
    love.graphics.setColor(UI.colors.panelBorder)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 3, 3)
end

function UI.ScrollList:click(mx, my)
    if not self.visible then return false end
    if mx >= self.x and mx <= self.x + self.w and my >= self.y and my <= self.y + self.h then
        local localY = my - self.y + self.scroll
        local idx = math.floor(localY / self.itemHeight) + 1
        if idx >= 1 and idx <= #self.items then
            self.selected = idx
            if self.onSelect then
                self.onSelect(self.items[idx], idx)
            end
            return true
        end
    end
    return false
end

function UI.ScrollList:wheelmoved(x, y)
    if not self.visible then return end
    self.scroll = self.scroll - y * self.itemHeight * 0.5
    self.scroll = math.max(0, math.min(self.maxScroll, self.scroll))
end

function UI.ScrollList:getSelected()
    if self.selected > 0 and self.selected <= #self.items then
        return self.items[self.selected], self.selected
    end
    return nil, 0
end

-------------------------------------------------------------------------------
-- DIALOG CLASS
-------------------------------------------------------------------------------
UI.Dialog = {}
UI.Dialog.__index = UI.Dialog

function UI.Dialog.new(title, x, y, w, h, opts)
    opts = opts or {}
    local self = setmetatable({}, UI.Dialog)
    self.title = title
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.open = true
    self.buttons = {}
    self.content = opts.content
    self.onClose = opts.onClose
    self.scrollList = opts.scrollList
    self.closeable = opts.closeable ~= false
    self.fadeIn = 0
    return self
end

function UI.Dialog:addButton(text, callback, opts)
    opts = opts or {}
    local btnW = opts.width or 100
    table.insert(self.buttons, {text = text, callback = callback, opts = opts, width = btnW})
end

function UI.Dialog:update(dt, mx, my)
    if not self.open then return end
    self.fadeIn = math.min(1, self.fadeIn + dt * 5)
    for _, b in ipairs(self.buttons) do
        if b.btn then b.btn:update(mx, my) end
    end
    if self.scrollList then
        self.scrollList:update(mx, my)
    end
end

function UI.Dialog:draw()
    if not self.open then return end

    -- Overlay
    love.graphics.setColor(0, 0, 0, 0.4 * self.fadeIn)
    love.graphics.rectangle("fill", 0, 0, 480, 320)

    -- Panel
    UI.drawPanel(self.x, self.y, self.w, self.h, {
        title = self.title,
        shadow = true,
        radius = 8,
    })

    -- Content
    local contentY = self.y + 34
    if self.content then
        love.graphics.setColor(UI.colors.text)
        UI.setFont("normal")
        love.graphics.printf(self.content, self.x + 12, contentY, self.w - 24, "left")
    end

    if self.scrollList then
        self.scrollList:draw()
    end

    -- Buttons
    local totalW = 0
    for _, b in ipairs(self.buttons) do totalW = totalW + b.width + 8 end
    local bx = self.x + (self.w - totalW) / 2
    local by = self.y + self.h - 38
    for i, b in ipairs(self.buttons) do
        if not b.btn then
            b.btn = UI.Button.new(b.text, bx, by, b.width, 30, b.callback, b.opts or {})
        else
            b.btn.x = bx
            b.btn.y = by
        end
        b.btn:draw()
        bx = bx + b.width + 8
    end

    -- Close X button
    if self.closeable then
        love.graphics.setColor(UI.colors.textWhite)
        UI.setFont("normal")
        love.graphics.print("X", self.x + self.w - 18, self.y + 6)
    end
end

function UI.Dialog:click(mx, my)
    if not self.open then return false end

    -- Close button
    if self.closeable and mx >= self.x + self.w - 22 and mx <= self.x + self.w
       and my >= self.y and my <= self.y + 28 then
        self:close()
        return true
    end

    -- Buttons
    for _, b in ipairs(self.buttons) do
        if b.btn and b.btn:click(mx, my) then return true end
    end

    -- Scroll list
    if self.scrollList then
        if self.scrollList:click(mx, my) then return true end
    end

    return true -- block clicks behind dialog
end

function UI.Dialog:wheelmoved(x, y)
    if not self.open then return end
    if self.scrollList then
        self.scrollList:wheelmoved(x, y)
    end
end

function UI.Dialog:close()
    self.open = false
    if self.onClose then self.onClose() end
end

function UI.Dialog:isOpen()
    return self.open
end

-------------------------------------------------------------------------------
-- TEXT INPUT (simple)
-------------------------------------------------------------------------------
UI.TextInput = {}
UI.TextInput.__index = UI.TextInput

function UI.TextInput.new(x, y, w, h, opts)
    opts = opts or {}
    local self = setmetatable({}, UI.TextInput)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.text = opts.default or ""
    self.maxLen = opts.maxLen or 20
    self.active = opts.active ~= false
    self.cursor = #self.text
    self.cursorBlink = 0
    self.placeholder = opts.placeholder or ""
    return self
end

function UI.TextInput:update(dt)
    self.cursorBlink = self.cursorBlink + dt
    if self.cursorBlink > 1 then self.cursorBlink = 0 end
end

function UI.TextInput:draw()
    -- Background
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 4, 4)
    love.graphics.setColor(UI.colors.panelBorder)
    love.graphics.setLineWidth(self.active and 2 or 1)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 4, 4)

    UI.setFont("normal")
    local displayText = self.text
    if #displayText == 0 and not self.active then
        love.graphics.setColor(UI.colors.textLight)
        displayText = self.placeholder
    else
        love.graphics.setColor(UI.colors.text)
    end

    local textY = self.y + (self.h - UI.fonts.normal:getHeight()) / 2
    love.graphics.print(displayText, self.x + 8, textY)

    -- Cursor
    if self.active and self.cursorBlink < 0.5 then
        local textW = UI.fonts.normal:getWidth(self.text)
        love.graphics.setColor(UI.colors.text)
        love.graphics.rectangle("fill", self.x + 8 + textW, textY, 2, UI.fonts.normal:getHeight())
    end
    love.graphics.setLineWidth(1)
end

function UI.TextInput:textinput(t)
    if not self.active then return end
    if #self.text < self.maxLen then
        self.text = self.text .. t
    end
end

function UI.TextInput:keypressed(key)
    if not self.active then return end
    if key == "backspace" then
        self.text = self.text:sub(1, -2)
    end
end

function UI.TextInput:getText()
    return self.text
end

-------------------------------------------------------------------------------
-- TOAST NOTIFICATION SYSTEM
-------------------------------------------------------------------------------
function UI.addToast(message, duration, color)
    table.insert(UI.toasts, {
        message = message,
        timer = duration or 3,
        maxTimer = duration or 3,
        color = color or UI.colors.accent,
        alpha = 0,
    })
end

function UI.updateToasts(dt)
    for i = #UI.toasts, 1, -1 do
        local t = UI.toasts[i]
        t.timer = t.timer - dt
        -- Fade in
        if t.timer > t.maxTimer - 0.3 then
            t.alpha = math.min(1, t.alpha + dt * 5)
        -- Fade out
        elseif t.timer < 0.5 then
            t.alpha = math.max(0, t.alpha - dt * 3)
        else
            t.alpha = 1
        end
        if t.timer <= 0 then
            table.remove(UI.toasts, i)
        end
    end
end

function UI.drawToasts()
    UI.setFont("small")
    for i, t in ipairs(UI.toasts) do
        local tw = UI.fonts.small:getWidth(t.message) + 20
        local th = 24
        local tx = (480 - tw) / 2
        local ty = 40 + (i-1) * 28

        love.graphics.setColor(0, 0, 0, 0.6 * t.alpha)
        love.graphics.rectangle("fill", tx, ty, tw, th, 5, 5)
        love.graphics.setColor(t.color[1], t.color[2], t.color[3], t.alpha)
        love.graphics.rectangle("fill", tx, ty, 4, th, 2, 2)
        love.graphics.setColor(1, 1, 1, t.alpha)
        love.graphics.printf(t.message, tx, ty + 4, tw, "center")
    end
end

-------------------------------------------------------------------------------
-- TAB BAR
-------------------------------------------------------------------------------
UI.TabBar = {}
UI.TabBar.__index = UI.TabBar

function UI.TabBar.new(x, y, w, tabs, callback)
    local self = setmetatable({}, UI.TabBar)
    self.x = x
    self.y = y
    self.w = w
    self.tabs = tabs
    self.selected = 1
    self.callback = callback
    self.tabWidth = w / #tabs
    return self
end

function UI.TabBar:draw()
    for i, tab in ipairs(self.tabs) do
        local tx = self.x + (i-1) * self.tabWidth
        if i == self.selected then
            love.graphics.setColor(UI.colors.panel)
        else
            love.graphics.setColor(UI.colors.panelDark)
        end
        love.graphics.rectangle("fill", tx, self.y, self.tabWidth, 26)
        love.graphics.setColor(UI.colors.panelBorder)
        love.graphics.rectangle("line", tx, self.y, self.tabWidth, 26)

        love.graphics.setColor(i == self.selected and UI.colors.text or UI.colors.textLight)
        UI.setFont("small")
        love.graphics.printf(tab, tx, self.y + 6, self.tabWidth, "center")
    end
end

function UI.TabBar:click(mx, my)
    if my >= self.y and my <= self.y + 26 then
        for i = 1, #self.tabs do
            local tx = self.x + (i-1) * self.tabWidth
            if mx >= tx and mx <= tx + self.tabWidth then
                self.selected = i
                if self.callback then self.callback(i) end
                return true
            end
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- UTILITY
-------------------------------------------------------------------------------
function UI.formatMoney(amount)
    if amount >= 1000000 then
        return string.format("%.1fM gp", amount / 1000000)
    elseif amount >= 1000 then
        return string.format("%.0fK gp", amount / 1000)
    else
        return string.format("%d gp", amount)
    end
end

function UI.formatNumber(n)
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    else
        return string.format("%d", n)
    end
end

function UI.pointInRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

return UI
