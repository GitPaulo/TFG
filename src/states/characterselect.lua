local love = _G.love
local Gui = _G.Gui
local table = _G.table
local Anim8 = _G.Anim8
local CharacterSelect = {}

local SPRITE_SCALE = 2
local PLAYER_COUNT = 2

function CharacterSelect:enter(params)
    self.currentPlayer = 1
    self.selectedFighters = {1, 2}
    self.characters = {}
    self.animations = {}

    -- Load character data from files
    for _, file in ipairs(love.filesystem.getDirectoryItems('fighters')) do
        if _G.isDebug then
            print('Loading fighter: ' .. file)
        end
        if file:match('%.lua$') then
            local character = table.shallowcopy(require('fighters.' .. file:gsub('%.lua$', '')))
            table.insert(self.characters, character)
            local spriteSheetPath = 'assets/fighters/' .. character.name .. '/Idle.png'
            local spriteSheet = love.graphics.newImage(spriteSheetPath)

            if _G.isDebug then
                print('Sprite sheet path:', spriteSheetPath)
                print('Sprite sheet dimensions:', spriteSheet:getWidth(), 'x', spriteSheet:getHeight())
            end

            -- Get number of frames
            local numFrames = character.spriteConfig.idle.frames
            if _G.isDebug then
                print('Number of frames:', numFrames)
            end

            -- Dynamically calculate frame dimensions
            local frameWidth = spriteSheet:getWidth() / numFrames
            local frameHeight = spriteSheet:getHeight()

            -- Check if the calculated frame dimensions fit within the sprite sheet dimensions
            if spriteSheet:getWidth() < frameWidth * numFrames or spriteSheet:getHeight() < frameHeight then
                error('Frame dimensions exceed sprite sheet dimensions for ' .. character.name)
            end

            if _G.isDebug then
                print('Calculated Frame dimensions:', frameWidth, 'x', frameHeight)
            end

            -- Create animation
            local grid = Anim8.newGrid(frameWidth, frameHeight, spriteSheet:getWidth(), spriteSheet:getHeight())
            local success, animation = pcall(Anim8.newAnimation, grid('1-' .. numFrames, 1), 0.1)
            if success then
                table.insert(
                    self.animations,
                    {
                        spriteSheet = spriteSheet,
                        animation = animation,
                        frameWidth = frameWidth,
                        frameHeight = frameHeight
                    }
                )
            else
                if _G.isDebug then
                    print('Error creating animation:', animation)
                end
            end
        end
    end

    -- Ensure selected fighters are within bounds
    for i = 1, PLAYER_COUNT do
        self.selectedFighters[i] = self.selectedFighters[i] % #self.characters + 1
    end

    -- Load fonts
    self.titleFont = love.graphics.newFont(32)
    self.instructionFont = love.graphics.newFont(16)
    self.statsFont = love.graphics.newFont(10)

    -- Set custom cursor
    self.cursor = Gui.Cursor('assets/cursor.png')
    love.mouse.setVisible(false)

    -- Load background music
    self.backgroundMusic = love.audio.newSource('assets/characterselect.mp3', 'stream')
    self.backgroundMusic:setLooping(true)
    love.audio.play(self.backgroundMusic)
end

function CharacterSelect:exit()
    love.mouse.setVisible(true)
end

function CharacterSelect:update(dt)
    local currentPlayerIndex = self.selectedFighters[self.currentPlayer]
    if _G.isDebug then
        print('Current player index: ', self.currentPlayer, 'Selected Fighter Index: ', currentPlayerIndex)
    end

    self.animations[currentPlayerIndex].animation:update(dt)

    local function wrapSelection(index, step)
        index = index + step
        if index < 1 then
            return #self.characters
        elseif index > #self.characters then
            return 1
        else
            return index
        end
    end

    if love.keyboard.wasPressed('left') then
        self.selectedFighters[self.currentPlayer] = wrapSelection(self.selectedFighters[self.currentPlayer], -1)
    elseif love.keyboard.wasPressed('right') then
        self.selectedFighters[self.currentPlayer] = wrapSelection(self.selectedFighters[self.currentPlayer], 1)
    elseif love.keyboard.wasPressed('return') then
        if self.currentPlayer < PLAYER_COUNT then
            self.currentPlayer = self.currentPlayer + 1
        else
            local selectedFighterNames = {}
            for i, index in ipairs(self.selectedFighters) do
                selectedFighterNames[i] = self.characters[index].name
            end
            self.stateMachine:change('menu', {selectedFighters = selectedFighterNames})
        end
    end

    -- Update custom cursor
    local mouseX, mouseY = love.mouse.getPosition()
    self.cursor:update(mouseX, mouseY)
end

function CharacterSelect:render()
    love.graphics.clear(0.1, 0.1, 0.1)

    -- Draw title
    love.graphics.setFont(self.titleFont)
    love.graphics.printf('Select Your Fighter', 0, 10, love.graphics.getWidth(), 'center')

    -- Draw player number and character name
    love.graphics.setFont(self.instructionFont)
    local currentCharacter = self.characters[self.selectedFighters[self.currentPlayer]].name
    love.graphics.printf(
        'Player ' .. self.currentPlayer .. ' as "' .. currentCharacter .. '"',
        0,
        60,
        love.graphics.getWidth(),
        'center'
    )

    -- Draw the selected character sprite
    local animationData = self.animations[self.selectedFighters[self.currentPlayer]]
    local windowWidth, windowHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local spriteX = (windowWidth - (animationData.frameWidth * SPRITE_SCALE)) / 2
    local spriteY = (windowHeight - (animationData.frameHeight * SPRITE_SCALE)) / 2 + 20
    animationData.animation:draw(animationData.spriteSheet, spriteX, spriteY, 0, SPRITE_SCALE, SPRITE_SCALE)

    -- Draw stats next to the character sprite
    local character = self.characters[self.selectedFighters[self.currentPlayer]]
    local stats = {
        'Speed: ' .. character.traits.speed,
        'Health: ' .. character.traits.health,
        'Stamina: ' .. character.traits.stamina,
        'Light Damage: ' .. character.attacks.light.damage,
        'Medium Damage: ' .. character.attacks.medium.damage,
        'Heavy Damage: ' .. character.attacks.heavy.damage
    }
    local statsX, statsY, statsYGap = 280, 100, 14
    love.graphics.setFont(self.statsFont)
    love.graphics.setColor(1, 1, 1)
    for i, stat in ipairs(stats) do
        love.graphics.printf(stat, statsX, statsY + statsYGap * i, 200, 'left')
    end

    -- Draw instructions
    love.graphics.setFont(self.instructionFont)
    local instructionY = windowHeight - 60
    love.graphics.printf("Use 'Arrow' keys to swap and 'Enter' to confirm", 0, instructionY, windowWidth, 'center')
    love.graphics.printf("Press 'Esc' to go back", 0, instructionY + 30, windowWidth, 'center')

    -- Draw custom cursor
    self.cursor:render()
end

function CharacterSelect:keypressed(key)
    if key == 'escape' then
        self.stateMachine:change('menu')
    end
end

return CharacterSelect
