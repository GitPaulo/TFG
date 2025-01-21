local love = _G.love;

-- Global Config
_G.isDebug = false

-- Love2D Config
function love.conf(t)
    t.window.width = 425
    t.window.height = 281
    -- NO resizing! TINY!
    t.window.title = "TFG: A Tiny Fighting Game"
    t.console = _G.isDebug
end
