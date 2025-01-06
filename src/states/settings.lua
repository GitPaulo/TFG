local love = _G.love
local Gui = _G.Gui
local Settings = {}

local WINDOW_WIDTH = 425
local WINDOW_HEIGHT = 281
local BUTTON_WIDTH = 140
local BUTTON_HEIGHT = 35
local CHECKBOX_SIZE = 20
local PADDING = 10

function Settings:enter(params)
    -- Load fonts
    self.titleFont = love.graphics.newFont(32)
    self.instructionFont = love.graphics.newFont(16)
    self.smallFont = love.graphics.newFont(10)

    -- Set custom cursor
    self.cursor = Gui.Cursor('assets/cursor.png')
    love.mouse.setVisible(false)

    -- Load background music
    self.backgroundMusic = love.audio.newSource('assets/characterselect.mp3', 'stream')
    self.backgroundMusic:setLooping(true)
    love.audio.play(self.backgroundMusic)

    -- Load button sounds
    local hoverSound = love.audio.newSource("assets/hover.mp3", "static")
    local clickSound = love.audio.newSource("assets/click.mp3", "static")

    -- Create checkboxes
    self.aiCheckbox = Gui.Checkbox(
        (WINDOW_WIDTH - (CHECKBOX_SIZE + PADDING + self.instructionFont:getWidth('Use AI for Fighter2'))) / 2,
        WINDOW_HEIGHT / 2 - 60,
        CHECKBOX_SIZE,
        "Use AI for Fighter2",
        self.useAI or false,
        function(state)
            self.useAI = state
        end
    )

    self.debugCheckbox = Gui.Checkbox(
        (WINDOW_WIDTH - (CHECKBOX_SIZE + PADDING + self.instructionFont:getWidth('Use Debug Mode'))) / 2,
        self.aiCheckbox.y + CHECKBOX_SIZE + PADDING,
        CHECKBOX_SIZE,
        "Use Debug Mode",
        self.useDebugMode or false,
        function(state)
            self.useDebugMode = state
        end
    )

    self.muteCheckbox = Gui.Checkbox(
        (WINDOW_WIDTH - (CHECKBOX_SIZE + PADDING + self.instructionFont:getWidth('Mute Sound'))) / 2,
        self.debugCheckbox.y + CHECKBOX_SIZE + PADDING,
        CHECKBOX_SIZE,
        "Mute Sound",
        self.muteSound or false,
        function(state)
            self.muteSound = state
            if self.muteSound then
                love.audio.pause(self.backgroundMusic)
            else
                love.audio.play(self.backgroundMusic)
            end
        end
    )

    -- Create "Rebind Controls" button
    self.controlsButton = Gui.Button(
        (WINDOW_WIDTH - BUTTON_WIDTH) / 2,
        self.muteCheckbox.y + CHECKBOX_SIZE + PADDING * 2,
        BUTTON_WIDTH,
        BUTTON_HEIGHT,
        "Rebind Controls",
        function()
            love.audio.stop(self.backgroundMusic)
            self.stateMachine:change('controls', { keyMappings = _G.KeyMappings })
        end,
        {hover = hoverSound, click = clickSound}
    )
end

function Settings:exit()
    love.mouse.setVisible(true)
end

function Settings:update(dt)
    local mouseX, mouseY = love.mouse.getPosition()

    -- Update checkboxes
    self.aiCheckbox:update(mouseX, mouseY)
    self.debugCheckbox:update(mouseX, mouseY)
    self.muteCheckbox:update(mouseX, mouseY)

    -- Update the "Rebind Controls" button
    self.controlsButton:update(mouseX, mouseY)

    -- Update cursor position
    self.cursor:update(mouseX, mouseY)
end

function Settings:render()
    love.graphics.clear(0, 0, 0, 1)

    -- Draw the title
    love.graphics.setFont(self.titleFont)
    love.graphics.printf('Settings', 0, WINDOW_HEIGHT / 9, WINDOW_WIDTH, 'center')

    -- Render checkboxes
    self.aiCheckbox:render(self.instructionFont, {1, 1, 0.8, 0.8}, {1, 1, 1, 1})
    self.debugCheckbox:render(self.instructionFont, {1, 1, 0.8, 0.8}, {1, 1, 1, 1})
    self.muteCheckbox:render(self.instructionFont, {1, 1, 0.8, 0.8}, {1, 1, 1, 1})

    -- Draw the "Rebind Controls" button
    self.controlsButton:render(self.instructionFont, {1, 1, 0.8, 0.8}, {1, 1, 1, 1})

    -- Draw custom cursor
    self.cursor:render()
end

function Settings:mousepressed(x, y, button)
    self.aiCheckbox:mousepressed(x, y, button)
    self.debugCheckbox:mousepressed(x, y, button)
    self.muteCheckbox:mousepressed(x, y, button)
    self.controlsButton:mousepressed(x, y, button)
end

function Settings:keypressed(key)
    if key == 'escape' then
        self.stateMachine:change(
            'menu',
            {
                settings = {
                    useAI = self.useAI,
                    muteSound = self.muteSound
                }
            }
        )
    end
end

return Settings
