local love = _G.love
local SoundManager = {}

function SoundManager:loadSound(filePath)
    return love.audio.newSource(filePath, 'static')
end

function SoundManager:playSound(sound, params)
    params = params or {}
    local delay = params.delay or 0
    local repeatCount = params.repeatCount or 1
    local volume = params.volume or 1
    local pitch = params.pitch or 1
    local cloneSound = params.clone or false
    local preventOverlap = params.preventOverlap or false

    -- Prevent playing the same sound if it's already playing and preventOverlap is true
    if preventOverlap and sound:isPlaying() then
        return
    end

    -- print('playing sound', sound, delay, repeatCount, volume, pitch, preventOverlap)

    if cloneSound then
        sound = sound:clone()
    end

    if delay > 0 then
        self:scheduleSound(sound, delay, repeatCount, volume, pitch, preventOverlap)
    else
        self:executeSound(sound, repeatCount, volume, pitch)
    end
end

function SoundManager:scheduleSound(sound, delay, repeatCount, volume, pitch, preventOverlap)
    local currentTime = love.timer.getTime()
    table.insert(
        self.scheduledSounds,
        {
            time = currentTime + delay,
            sound = sound,
            repeatCount = repeatCount,
            volume = volume,
            pitch = pitch,
            preventOverlap = preventOverlap
        }
    )
end

function SoundManager:executeSound(sound, repeatCount, volume, pitch)
    sound:setVolume(volume)
    sound:setPitch(pitch)
    for i = 1, repeatCount do
        sound:play()
    end
end

SoundManager.scheduledSounds = {}

function SoundManager:update()
    local currentTime = love.timer.getTime()
    for i = #self.scheduledSounds, 1, -1 do
        local soundData = self.scheduledSounds[i]
        if currentTime >= soundData.time then
            -- Prevent playing if preventOverlap is enabled and sound is still playing
            if not (soundData.preventOverlap and soundData.sound:isPlaying()) then
                self:executeSound(soundData.sound, soundData.repeatCount, soundData.volume, soundData.pitch)
            end
            table.remove(self.scheduledSounds, i)
        end
    end
end

return SoundManager
