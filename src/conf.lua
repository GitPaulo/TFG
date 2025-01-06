local love = _G.love;

-- Global
_G.isDebug = false
-- Love Configuration
function love.conf(t)
    t.window.width = 425
    t.window.height = 281
    -- NO resizing! TINY!
    t.window.title = "TFG: A Tiny Fighting Game"
    t.console = _G.isDebug
end
