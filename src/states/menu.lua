local love = _G.love
local Gui = _G.Gui
local Menu = {}

local TITLE_TEXT = "Tiny Fighting Game"
local PLAY_BUTTON_TEXT = "Play"
local CHARACTER_SELECT_TEXT = "Characters"
local SETTINGS_TEXT = "Settings"

local BUTTON_WIDTH = 140
local BUTTON_HEIGHT = 35
local WINDOW_WIDTH = 425
local WINDOW_HEIGHT = 281
local BUTTON_X = (WINDOW_WIDTH - BUTTON_WIDTH) / 2

local SETTINGS_BUTTON_Y = WINDOW_HEIGHT / 1.36 - 2 * BUTTON_HEIGHT - 20
local CHARACTER_BUTTON_Y = SETTINGS_BUTTON_Y + BUTTON_HEIGHT + 10
local PLAY_BUTTON_Y = CHARACTER_BUTTON_Y + BUTTON_HEIGHT + 10

local FRAMES = 120
local SPEED = 10

function Menu:enter(params)
    -- Set the window to menu size
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT, {["fullscreen"] = false})

    -- For first open
    params = params or {}

    -- Settings
    self.settings = params.settings or { useAI = false, muteSound = false }

    -- Selected Fighters
    self.selectedFighters = params.selectedFighters or { "Samurai1", "Samurai2" }

    -- Background
    self.background = love.graphics.newImage("assets/background_menu_spritesheet.png")
    self:buildBackground()

    -- Load fonts
    self.titleFont = love.graphics.newFont(32)
    self.buttonFont = love.graphics.newFont(20)

    -- Initialize timer and titleScale
    self.timer = 0
    self.titleScale = 1

    -- Load background music
    self.backgroundMusic = love.audio.newSource("assets/menu.mp3", "stream")
    self.backgroundMusic:setLooping(true)
    love.audio.stop()
    love.audio.play(self.backgroundMusic)

    -- Button sounds
    local hoverSound = love.audio.newSource("assets/hover.mp3", "static")
    local clickSound = love.audio.newSource("assets/click.mp3", "static")

    -- Set custom cursor
    self.cursor = Gui.Cursor("assets/cursor.png")

    -- Create buttons
    self.playButton = Gui.Button(
        BUTTON_X, PLAY_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT,
        PLAY_BUTTON_TEXT,
        function() self:MoveToGame() end,
        { hover = hoverSound, click = clickSound }
    )

    self.characterButton = Gui.Button(
        BUTTON_X, CHARACTER_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT,
        CHARACTER_SELECT_TEXT,
        function() self.stateMachine:change("characterselect") end,
        { hover = hoverSound, click = clickSound }
    )

    self.settingsButton = Gui.Button(
        BUTTON_X, SETTINGS_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT,
        SETTINGS_TEXT,
        function() self.stateMachine:change("settings", self.settings) end,
        { hover = hoverSound, click = clickSound }
    )
end

function Menu:exit()
    -- Cleanup
    love.audio.stop(self.backgroundMusic)
end

function Menu:update(dt)
    local mouseX, mouseY = love.mouse.getPosition()

    -- Update buttons
    self.playButton:update(mouseX, mouseY)
    self.characterButton:update(mouseX, mouseY)
    self.settingsButton:update(mouseX, mouseY)

    -- Update the title animation
    self.timer = self.timer + dt * SPEED
    self.titleScale = 1 + 0.1 * math.sin(love.timer.getTime() * 3)

    -- Update cursor
    self.cursor:update(mouseX, mouseY)
end

function Menu:render()
    love.graphics.clear(0, 0, 0, 1)

    -- Draw the background with animation
    local currentFrame = (math.floor(self.timer) % FRAMES) + 1
    love.graphics.draw(self.background, self.background_quads[currentFrame], 0, 0)

    -- Draw the title with animation
    love.graphics.setFont(self.titleFont)
    love.graphics.push()
    love.graphics.translate(WINDOW_WIDTH / 2, WINDOW_HEIGHT / 5)
    love.graphics.scale(self.titleScale, self.titleScale)
    love.graphics.printf(TITLE_TEXT, -WINDOW_WIDTH / 2, 0, WINDOW_WIDTH, "center")
    love.graphics.pop()

    -- Render buttons
    self.playButton:render(self.buttonFont, {1, 1, 0.8, 0.8}, {1, 1, 1, 1})
    self.characterButton:render(self.buttonFont, {1, 1, 0.8, 0.8}, {1, 1, 1, 1})
    self.settingsButton:render(self.buttonFont, {1, 1, 0.8, 0.8}, {1, 1, 1, 1})

    -- Draw custom cursor
    self.cursor:render()
end

function Menu:mousepressed(x, y, button)
    self.playButton:mousepressed(x, y, button)
    self.characterButton:mousepressed(x, y, button)
    self.settingsButton:mousepressed(x, y, button)
end

function Menu:keypressed(key)
    if key == "space" then
        self:MoveToGame()
    end
end

function Menu:MoveToGame()
    self.stateMachine:change(
        "loading",
        {
            useAI = self.settings.useAI,
            songs = {
                {path = "assets/game1.mp3", fftDataPath = "assets/fft_data_game1.msgpack"},
                {path = "assets/game2.mp3", fftDataPath = "assets/fft_data_game2.msgpack"},
                {path = "assets/game3.mp3", fftDataPath = "assets/fft_data_game3.msgpack"}
            },
            selectedFighters = self.selectedFighters
        }
    )
end

function Menu:buildBackground()
    self.background_quads = {}
    local imgWidth, imgHeight = self.background:getWidth(), self.background:getHeight()
    local frameWidth = WINDOW_WIDTH
    local frameHeight = WINDOW_HEIGHT
    local cols = 9
    local rows = 14

    for i = 0, FRAMES - 1 do
        local col = i % cols
        local row = math.floor(i / cols)
        local x = col * frameWidth
        local y = row * frameHeight
        table.insert(self.background_quads, love.graphics.newQuad(x, y, frameWidth, frameHeight, imgWidth, imgHeight))
    end
end

return Menu
