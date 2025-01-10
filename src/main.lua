require 'dependencies'

_G.FPS_CAP = 60

local KeyMappings, Menu, Game, CharacterSelect, Loading, Settings, Controls, StateMachine, love, SoundManager =
    _G.KeyMappings,
    _G.Menu,
    _G.Game,
    _G.CharacterSelect,
    _G.Loading,
    _G.Settings,
    _G.Controls,
    _G.StateMachine,
    _G.love,
    _G.SoundManager -- Do not add _G.isDebug as it is changed by Settings
local gStateMachine
local tickPeriod = 1 / _G.FPS_CAP -- seconds per tick
local accumulator = 0.0
local frameCount = 0
local fpsTimer = 0
local fpsFont = love.graphics.newFont(12)

-- State Machine Initialization
function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')

    -- Initialize state machine with separate state files
    gStateMachine =
        StateMachine:new(
        {
            ['menu'] = Menu,
            ['game'] = Game,
            ['loading'] = Loading,
            ['characterselect'] = CharacterSelect,
            ['settings'] = Settings,
            ['controls'] = Controls
        }
    )
    gStateMachine:change('menu')

    love.keyboard.keysPressed = {}
end

-- Game Update Logic
function love.update(dt)
    -- Fixed-rate game loop
    accumulator = accumulator + dt
    while accumulator >= tickPeriod do
        SoundManager:update()
        gStateMachine:update(tickPeriod)
        accumulator = accumulator - tickPeriod
        love.keyboard.keysPressed = {}
    end

    -- FPS tracking
    fpsTimer = fpsTimer + dt
    frameCount = frameCount + 1
    if fpsTimer >= 1 then
        _G.actualFPS = frameCount
        frameCount = 0
        fpsTimer = fpsTimer - 1
    end
end

-- Game Render Logic
function love.draw()
    gStateMachine:render()

    -- Debug FPS Display
    if _G.isDebug then
        love.graphics.setFont(fpsFont)
        love.graphics.setColor(1, 1, 1, 1)
        local width = love.graphics.getWidth()
        love.graphics.print('FPS: ' .. _G.actualFPS, width - 60, 10)
    end
end

local keyStates = {} -- Store key states
function love.keyboard.setKeyState(key, isPressed)
    if key then
        keyStates[key] = isPressed
    else
        print('Warning: Attempt to set state for nil key') -- Debugging invalid key
    end
end

function love.keyboard.isDown(key)
    return keyStates[key] or false
end

function love.keyboard.wasPressed(key)
    return love.keyboard.keysPressed[key]
end

function love.mousepressed(x, y, button)
    gStateMachine:mousepressed(x, y, button)
end

function love.keypressed(key, scancode, isrepeat)
    if key == "rctrl" then -- Debug key
        debug.debug()
    end

    love.keyboard.keysPressed[key] = true
    love.keyboard.setKeyState(key, true)

    if _G.isDebug then
        print('Key Pressed: ', key) -- Debugging key press
    end

    gStateMachine:keypressed(key)
end

function love.keyreleased(key)
    love.keyboard.setKeyState(key, false)
end
