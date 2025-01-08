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

function love.update(dt)
    -- Game loop runs at a fixed rate
    accumulator = accumulator + dt
    while accumulator >= tickPeriod do
        SoundManager:update()
        gStateMachine:update(tickPeriod)
        accumulator = accumulator - tickPeriod
        love.keyboard.keysPressed = {}
    end    
end

function love.draw()
    gStateMachine:render()
end

-- Create a table to store key states
local keyStates = {}

function love.keyboard.setKeyState(key, isPressed)
    if key then -- Add this check to ensure key is not nil
        keyStates[key] = isPressed
    else
        print('Warning: Attempt to set state for nil key') -- Add a warning to debug potential issues
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
    --Debug
    if key == "rctrl" then --set to whatever key you want to use
        debug.debug()
    end
    love.keyboard.keysPressed[key] = true
    love.keyboard.setKeyState(key, true)
    if _G.isDebug then
        print('Key Pressed: ', key) -- Debugging statement to check keypresses
    end
    gStateMachine:keypressed(key)
end

function love.keyreleased(key)
    love.keyboard.setKeyState(key, false)
end
