local love, SoundManager, AIController = _G.love, _G.SoundManager, _G.AIController
local Game = {}

local BACKGROUND_FRAME_WIDTH = 800
local BACKGROUND_FRAME_HEIGHT = 300
local BACKGROUND_FRAMES = 38
local SPEED = 10

function Game:enter(params)
    -- Set the window size to match the dimensions of a single sprite
    love.window.setMode(BACKGROUND_FRAME_WIDTH, BACKGROUND_FRAME_HEIGHT,{['fullscreen'] = false})

    self.backgroundAnimation = love.graphics.newImage('assets/background_game_spritesheet.png')
    self:buildBackground()

    -- Game state
    self.timer = 0
    self.gameOver = false
    self.winner = nil

    -- Fighter setup
    self.fighter1 = params.fighter1
    self.fighter2 = params.fighter2

    assert(self.fighter1, 'Fighter 1 must be provided to the game state')
    assert(self.fighter2, 'Fighter 2 must be provided to the game state')

    -- Flash screen
    self.flashStartTime = love.timer.getTime()
    self.flashDuration = 0.8
    self.flashActive = false

    -- AI setup (assuming fighter2 is controlled by AI)
    self.aiController = params.useAI and AIController:new(self.fighter2, self.fighter1) or nil

    -- FFT visualizer setup
    self.fftBufferSize = 64
    self.fftData = {}
    self.fftAngleStep = (2 * math.pi) / self.fftBufferSize
    self.fftRadius = 25
    self.fftMaxHeight = 18

    -- Songs
    self.songs = params.songs
    self.currentSongIndex = 1
    assert(self.songs, 'Songs must be provided to the game state')
    self:playCurrentSong()

    -- Load font for FPS counter
    self.fpsFont = love.graphics.newFont(12)
    self.gameOverFont = love.graphics.newFont(32)
    self.winnerFont = love.graphics.newFont(20)
    self.instructionsFont = love.graphics.newFont(16)
    self.eventFont = love.graphics.newFont(20)
end

function Game:exit()
    self.music:stop()
end

function Game:update(dt)
    if self.gameOver then
        return
    end

    self.timer = self.timer + dt * SPEED

    -- Check if the current song has finished playing
    if not self.music:isPlaying() then
        self.currentSongIndex = self.currentSongIndex % #self.songs + 1
        self:playCurrentSong()
    end

    -- Update FFT data index based on the song's playback position
    local playbackPosition = self.music:tell() -- in seconds
    local sampleRate = 48000 -- 48000 Hz sample rate
    local chunkSize = 2048 -- chunk size used in FFT calculation
    local overlap = 0.75 -- 75% overlap used in FFT calculation
    local stepSize = chunkSize * (1 - overlap) -- 25% of the chunk size

    local samplesPerSecond = sampleRate / stepSize
    local fftDataIndex = math.floor(playbackPosition * samplesPerSecond) + 1
    self.fftDataIndex = (fftDataIndex - 1) % #self.fftData + 1

    -- Update AI controller
    if self.aiController then
        self.aiController:update(dt)
    end

    -- Update fighters with the other fighter's state
    self.fighter1:update(dt, self.fighter2)
    self.fighter2:update(dt, self.fighter1)

    -- Flash logic
    if self.fighter1.isClashing or self.fighter2.isClashing then
        if not self.flashActive then
            self.flashActive = true
            self.flashStartTime = love.timer.getTime()
        end
    end

    -- Check for game over - leave this block last
    local hasFighterDied = self.fighter1.state == 'death' or self.fighter2.state == 'death'
    if hasFighterDied then
        -- Check if death animation is still playing
        if self.fighter1.state == 'death' then
            self.fighter1:checkDeathAnimationFinished()
        end
        if self.fighter2.state == 'death' then
            self.fighter2:checkDeathAnimationFinished()
        end

        -- Only set game over when death animations are finished
        if self.fighter1.deathAnimationFinished or self.fighter2.deathAnimationFinished then
            self.gameOver = true
            if self.fighter1.deathAnimationFinished and self.fighter2.deathAnimationFinished then
                self.winner = 'Draw!'
            else
                self.winner = self.fighter1.deathAnimationFinished and self.fighter2.name or self.fighter1.name
            end
            self.music:stop()
        end
    end
end

function Game:render()
    -- Clear screen with black color
    love.graphics.clear(0, 0, 0, 1)

    -- Draw the background image
    local currentFrame = (math.floor(self.timer) % BACKGROUND_FRAMES) + 1
    -- love.graphics.draw(self.backgroundAnimation)
    love.graphics.draw(self.backgroundAnimation, self.backgroundFrames[currentFrame])

    -- Render fighters
    self.fighter1:render(self.fighter2)
    self.fighter2:render(self.fighter1)

    -- Block
    self:drawBlock()

    -- Flash screen when fighters collide
    self:drawFlash()

    -- Render health bars
    self:drawHealthBars()

    -- Render recovery progress bars
    self:drawRecoveryBars() 

    -- Render FFT visualizer
    self:drawFFT()

    -- Render game over screen if game is over
    if self.gameOver then
        self:drawGameOverScreen()
    end

    -- Render FPS counter in the top right corner
    if _G.isDebug then
        love.graphics.setFont(self.fpsFont)
        love.graphics.setColor(1, 1, 1, 1)
        local fps = love.timer.getFPS()
        love.graphics.print('FPS: ' .. fps, BACKGROUND_FRAME_WIDTH - 60, 10)
    end
end

function Game:drawBlock()
    if self.fighter1.isBlockingDamage then
        love.graphics.setFont(self.eventFont)
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print('Blocked', self.fighter1.x - 18, self.fighter1.y - 22)
        love.graphics.setColor(1, 1, 1, 1) -- Reset color
    end

    if self.fighter2.isBlockingDamage then
        love.graphics.setFont(self.eventFont)
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print('Blocked', self.fighter2.x - 18, self.fighter2.y - 22)
        love.graphics.setColor(1, 1, 1, 1) -- Reset color
    end
end

function Game:drawFlash()
    if not self.flashActive then
        return
    end

    local elapsedTime = love.timer.getTime() - self.flashStartTime
    if elapsedTime < self.flashDuration then
        local alpha = 1 - (elapsedTime / self.flashDuration) -- Fade out smoothly
        love.graphics.setColor(1, 1, 1, alpha) -- White with decreasing opacity
        love.graphics.rectangle("fill", 0, 0, BACKGROUND_FRAME_WIDTH, BACKGROUND_FRAME_HEIGHT)
        love.graphics.setColor(1, 1, 1, 1) -- Reset color
    else
        self.flashActive = false
    end
end

function Game:drawGameOverScreen()
    -- Apply semi-transparent red overlay
    love.graphics.setColor(1, 0, 0, 0.5)
    love.graphics.rectangle('fill', 0, 0, BACKGROUND_FRAME_WIDTH, BACKGROUND_FRAME_HEIGHT)
    love.graphics.setColor(1, 1, 1, 1) -- Reset color to white

    -- Render game over text
    love.graphics.setFont(self.gameOverFont)
    love.graphics.printf('Game Over', 0, BACKGROUND_FRAME_HEIGHT / 2 - 60, BACKGROUND_FRAME_WIDTH, 'center')
    love.graphics.setFont(self.winnerFont)
    love.graphics.printf(self.winner .. ' wins!', 0, BACKGROUND_FRAME_HEIGHT / 2 - 10, BACKGROUND_FRAME_WIDTH, 'center')
    love.graphics.setFont(self.instructionsFont)
    love.graphics.printf("Press 'ESC' to return to Main Menu", 0, BACKGROUND_FRAME_HEIGHT / 2 + 20, BACKGROUND_FRAME_WIDTH, 'center')
end

function Game:drawRecoveryBars()
    local function drawRecoveryBar(fighter)
        local currentTime = love.timer.getTime()
        local lastAttackType = fighter.lastAttackType

        -- Ensure lastAttackType exists in fighter.attacks
        local recoveryDuration =
            (lastAttackType and fighter.attacks[lastAttackType]) and fighter.attacks[lastAttackType].recovery or 0
        local elapsedTime = currentTime - (fighter.recoveryEndTime - recoveryDuration)
        local progress = math.min(elapsedTime / recoveryDuration, 1) -- Ensure progress doesn't exceed 1

        local barWidth = 44 -- Full width of the bar
        local barHeight = 4
        local x = fighter.id == 1 and 10 or love.graphics.getWidth() - 10 - barWidth
        local y = 45 -- Position just under the stamina bar

        love.graphics.setColor(1, 1, 1, 0.5) -- Background color
        love.graphics.rectangle('fill', x, y, barWidth, barHeight)

        love.graphics.setColor(1, 1, 1, 1) -- Progress color
        love.graphics.rectangle('fill', x, y, barWidth * progress, barHeight)

        love.graphics.setColor(1, 1, 1, 1) -- Reset color
    end

    -- Draw recovery bars for both fighters
    drawRecoveryBar(self.fighter1)
    drawRecoveryBar(self.fighter2)
end

function Game:buildBackground()
    self.backgroundFrames = {}

    local animationWidth, animationHeight = self.backgroundAnimation:getWidth(), self.backgroundAnimation:getHeight()

    for currentFrame = 0, BACKGROUND_FRAMES - 1 do
        table.insert(
            self.backgroundFrames,
            love.graphics.newQuad(
                BACKGROUND_FRAME_WIDTH * currentFrame, 0,
                BACKGROUND_FRAME_WIDTH, BACKGROUND_FRAME_HEIGHT,
                animationWidth, animationHeight
            )
        )
    end
end

function Game:drawHealthBars()
    local barWidth = 300
    local barHeight = 20
    local padding = 10

    -- Fighter 1 health bar
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle('fill', padding, padding, barWidth, barHeight)
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.rectangle(
        'fill',
        padding,
        padding,
        barWidth * (self.fighter1.health / self.fighter1.maxHealth),
        barHeight
    )

    -- Fighter 1 stamina bar
    love.graphics.setColor(0, 0, 1, 1)
    love.graphics.rectangle(
        'fill',
        padding,
        padding + barHeight + 3,
        barWidth * (self.fighter1.stamina / self.fighter1.maxStamina),
        barHeight / 4
    )

    -- Fighter 2 health bar
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle('fill', love.graphics.getWidth() - barWidth - padding, padding, barWidth, barHeight)
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.rectangle(
        'fill',
        love.graphics.getWidth() - barWidth - padding,
        padding,
        barWidth * (self.fighter2.health / self.fighter2.maxHealth),
        barHeight
    )

    -- Fighter 2 stamina bar
    love.graphics.setColor(0, 0, 1, 1)
    love.graphics.rectangle(
        'fill',
        love.graphics.getWidth() - barWidth - padding,
        padding + barHeight + 3,
        barWidth * (self.fighter2.stamina / self.fighter2.maxStamina),
        barHeight / 4
    )

    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

function Game:drawFFT()
    local centerX = BACKGROUND_FRAME_WIDTH / 2
    local centerY = 40
    local fftData = self.fftData[self.fftDataIndex]
    if fftData then
        for i = 1, #fftData do
            local angle = self.fftAngleStep * (i - 1)
            local barHeight = fftData[i] * self.fftMaxHeight
            if barHeight then
                local x1 = centerX + self.fftRadius * math.cos(angle)
                local y1 = centerY + self.fftRadius * math.sin(angle)
                local x2 = centerX + (self.fftRadius + barHeight) * math.cos(angle)
                local y2 = centerY + (self.fftRadius + barHeight) * math.sin(angle)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.line(x1, y1, x2, y2)
            end
        end
    end
end

function Game:keypressed(key)
    if key == 'escape' then
        self.stateMachine:change('menu')
    end
end

function Game:playCurrentSong()
    local song = self.songs[self.currentSongIndex]
    self.music = love.audio.newSource(song.path, 'stream')
    self.music:setLooping(false)
    self.music:play()

    -- Use preloaded FFT data
    self.fftData = song.fftData
    self.fftDataIndex = 1
end

return Game
