local Gui = {}

function Gui.Button(x, y, width, height, text, onClick, sounds)
    local button = {
        x = x,
        y = y,
        width = width,
        height = height,
        text = text,
        onClick = onClick,
        hover = false,
        sounds = sounds or {hover = nil, click = nil},
        update = function(self, mouseX, mouseY)
            local isHovering = mouseX >= self.x and mouseX <= self.x + self.width and
                               mouseY >= self.y and mouseY <= self.y + self.height

            if isHovering and not self.hover then
                if self.sounds.hover then
                    love.audio.play(self.sounds.hover:clone())
                end
            end

            self.hover = isHovering
        end,
        render = function(self, font, hoverColor, normalColor)
            local color = self.hover and hoverColor or normalColor
            love.graphics.setColor(color[1], color[2], color[3], color[4])
            love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
            love.graphics.setFont(font)
            love.graphics.printf(self.text, self.x, self.y + (self.height / 5), self.width, "center")
            love.graphics.setColor(1, 1, 1, 1) -- Reset color
        end,
        mousepressed = function(self, mouseX, mouseY, button)
            if button == 1 and self.hover then
                if self.sounds.click then
                    love.audio.play(self.sounds.click:clone())
                end
                self.onClick()
            end
        end
    }
    return button
end

function Gui.Checkbox(x, y, size, label, state, onToggle)
    local checkbox = {
        x = x,
        y = y,
        size = size,
        label = label,
        state = state or false,
        onToggle = onToggle,
        hover = false,
        update = function(self, mouseX, mouseY)
            self.hover = mouseX >= self.x and mouseX <= self.x + self.size and
                         mouseY >= self.y and mouseY <= self.y + self.size
        end,
        render = function(self, font, hoverColor, normalColor)
            local color = self.hover and hoverColor or normalColor
            love.graphics.setColor(color[1], color[2], color[3], color[4])
            love.graphics.rectangle("line", self.x, self.y, self.size, self.size)
            if self.state then
                love.graphics.line(self.x, self.y, self.x + self.size, self.y + self.size)
                love.graphics.line(self.x + self.size, self.y, self.x, self.y + self.size)
            end
            love.graphics.setFont(font)
            love.graphics.printf(self.label, self.x + self.size + 10, self.y, 200, "left")
            love.graphics.setColor(1, 1, 1, 1) -- Reset color
        end,
        mousepressed = function(self, mouseX, mouseY, button)
            if button == 1 and self.hover then
                self.state = not self.state
                if self.onToggle then
                    self.onToggle(self.state)
                end
            end
        end
    }
    return checkbox
end

function Gui.Cursor(imagePath)
    local cursor = {
        image = love.graphics.newImage(imagePath),
        x = 0,
        y = 0,
        update = function(self, mouseX, mouseY)
            self.x = mouseX
            self.y = mouseY
        end,
        render = function(self)
            -- Disable the default cursor
            love.mouse.setVisible(false) 
            love.graphics.draw(self.image, self.x, self.y)
        end
    }
    
    return cursor
end

return Gui
