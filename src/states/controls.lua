local love = _G.love
local Gui = _G.Gui
local Controls = {}

local WINDOW_WIDTH = 425
local WINDOW_HEIGHT = 281
local PADDING = 10
local COLUMN_WIDTH = 200
local MAX_CONTROLS_PER_COLUMN = 3

function Controls:enter(params)
    self.keyMappings = params.keyMappings
    self.currentPlayer = 1 -- 1 for Player 1, 2 for Player 2
    self.currentKey = nil
    self.awaitingKey = false

    -- Load fonts
    self.titleFont = love.graphics.newFont(32)
    self.instructionFont = love.graphics.newFont(16)
    self.keyFont = love.graphics.newFont(12)
    self.smallFont = love.graphics.newFont(10)

    -- Set custom cursor
    self.cursor = Gui.Cursor("assets/cursor.png")
    love.mouse.setVisible(false)

    -- Load background music
    self.backgroundMusic = love.audio.newSource('assets/characterselect.mp3', 'stream')
    self.backgroundMusic:setLooping(true)
    love.audio.play(self.backgroundMusic)
end

function Controls:render()
    love.graphics.clear(0, 0, 0, 1)

    -- Render title
    love.graphics.setFont(self.titleFont)
    love.graphics.printf("Rebind Controls", 0, 20, WINDOW_WIDTH, "center")

    -- Render currently selected player's controls
    local currentPlayerControls = self.keyMappings["fighter" .. self.currentPlayer .. "Controls"]
    love.graphics.setFont(self.instructionFont)
    love.graphics.printf("Player " .. self.currentPlayer .. " Controls:", 20, 100, WINDOW_WIDTH, "left")

    -- Render each control action and its assigned key in columns
    local xOffset = 20
    local yOffset = 140
    local controlsInColumn = 0

    for action, key in pairs(currentPlayerControls) do
        love.graphics.setFont(self.keyFont)
        love.graphics.printf(action .. ": " .. key, xOffset, yOffset, COLUMN_WIDTH, "left")
        yOffset = yOffset + 20
        controlsInColumn = controlsInColumn + 1

        if controlsInColumn >= MAX_CONTROLS_PER_COLUMN then
            controlsInColumn = 0
            yOffset = 140
            xOffset = xOffset + COLUMN_WIDTH
        end
    end

    -- Render awaiting key message
    if self.awaitingKey then
        love.graphics.setFont(self.instructionFont)
        love.graphics.printf(
            "Press a new key to bind for " .. self.currentKey,
            0,
            WINDOW_HEIGHT - 50,
            WINDOW_WIDTH,
            "center"
        )
    end

    -- Render instructions
    love.graphics.setFont(self.smallFont)
    love.graphics.printf("Use 'Left'/'Right' to switch players", 0, WINDOW_HEIGHT - 60, WINDOW_WIDTH, "center")
    love.graphics.printf("Press the current key to rebind it, then press a new key.", 0, WINDOW_HEIGHT - 40, WINDOW_WIDTH, "center")

    -- Render custom cursor
    self.cursor:render()
end

function Controls:update(dt)
    -- Update cursor
    local mouseX, mouseY = love.mouse.getPosition()
    self.cursor:update(mouseX, mouseY)
end

function Controls:keypressed(key)
    if self.awaitingKey then
        -- Assign the pressed key to the current action for the current player
        self.keyMappings["fighter" .. self.currentPlayer .. "Controls"][self.currentKey] = key
        self.awaitingKey = false
        self.currentKey = nil
    else
        -- Check if the pressed key matches any action
        local currentPlayerControls = self.keyMappings["fighter" .. self.currentPlayer .. "Controls"]
        for action, assignedKey in pairs(currentPlayerControls) do
            if key == assignedKey then
                self.awaitingKey = true
                self.currentKey = action
                return
            end
        end

        if key == "left" then
            -- Cycle to the previous player (wrap around)
            self.currentPlayer = self.currentPlayer - 1
            if self.currentPlayer < 1 then
                self.currentPlayer = 2 -- Wrap around to Player 2
            end
        elseif key == "right" then
            -- Cycle to the next player (wrap around)
            self.currentPlayer = self.currentPlayer + 1
            if self.currentPlayer > 2 then
                self.currentPlayer = 1 -- Wrap around to Player 1
            end
        elseif key == "escape" then
            -- Exit to settings and cleanup
            love.audio.stop(self.backgroundMusic)
            self.stateMachine:change("settings")
        end
    end
end

function Controls:exit()
    -- Save changes globally when exiting
    _G.KeyMappings = self.keyMappings
    love.audio.stop(self.backgroundMusic)
end

return Controls
