local time = {}

function time.sleep(seconds)
    local start = love.timer.getTime()
    while love.timer.getTime() - start < seconds do
        -- Do nothing, just wait
    end
end

return time
