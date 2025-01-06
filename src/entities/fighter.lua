local Anim8 = require 'lib.anim8'

local Class, love, SoundManager = _G.Class, _G.love, _G.SoundManager
local Fighter = Class:extend()

function Fighter:init(
    id,
    isAI,
    name,
    startingX,
    startingY,
    scale,
    controls,
    traits,
    hitboxes,
    attacks,
    spriteConfig,
    soundFXConfig)
    -- Character Properties
    self.id = id
    self.name = name
    self.x = startingX
    self.y = startingY
    self.scale = scale
    self.width = scale.width
    self.height = scale.height
    self.controls = controls
    self.speed = traits.speed or 200
    self.health = traits.health or 100
    self.maxHealth = traits.health or 100
    self.stamina = traits.stamina or 100
    self.maxStamina = traits.stamina or 100
    self.jumpStrength = -(traits.jumpStrength or 600)
    self.dashSpeed = traits.dashSpeed or 500
    self.hitboxes = hitboxes or {}
    self.attacks = attacks or {}
    self:validateFighterParameters()

    -- Character State
    self.dy = 0
    self.direction = (id == 2) and -1 or 1 -- Set direction to right for player 1 and left for player 2
    self.state = 'idle'
    self.isBlocking = false
    self.isBlockingDamage = false
    self.isAirborne = false
    self.isDashing = false
    self.isRecovering = false
    self.isClashing = false
    self.isAttackActive = false
    -- Character State: attack
    self.attackType = nil
    self.lastAttackType = nil
    self.attackEndTime = 0
    self.recoveryEndTime = 0
    -- Character State: dash
    self.lastTapTime = {left = 0, right = 0}
    self.dashDuration = 0.25
    self.dashEndTime = 0
    self.dashStaminaCost = 25
    self.deathAnimationFinished = false
    -- Character State: clash
    self.clashTime = 0
    self.knockbackTargetX = self.x
    self.knockbackSpeed = 400
    self.knockbackActive = false
    self.knockbackDelay = 0.2
    self.knockbackDelayTimer = 0
    self.lostClash = false
    -- Character State: hit
    self.hitEndTime = 0
    self.damageApplied = false -- ensures it only every applies once
    -- Other
    self.gravity = 1000
    self.isAI = isAI or false

    -- Animation, Sprites and sound
    self.spritesheets = self:loadSpritesheets(spriteConfig)
    self.animations = self:loadAnimations(spriteConfig)
    self.animationDurations = self:loadAnimationDurations(spriteConfig)
    self.sounds = self:loadSoundFX(soundFXConfig) -- Fighter related sound effects

    -- Set the default animation to idle
    self.currentAnimation = self.animations.idle
end

function Fighter:validateFighterParameters()
    assert(self.id, 'ID must be defined for fighter')
    assert(self.name, 'Name must be defined for fighter')
    assert(self.x, 'Starting X position must be defined for fighter')
    assert(self.y, 'Starting Y position must be defined for fighter')
    assert(self.scale, 'Scale must be defined for fighter')
    assert(self.width, 'Width must be defined for fighter')
    assert(self.height, 'Height must be defined for fighter')
    assert(self.controls, 'Controls must be defined for fighter')

    for attackType, hitbox in pairs(self.hitboxes) do
        assert(hitbox.ox, 'Offset Y must be defined for hitbox: ' .. attackType)
        assert(hitbox.oy, 'Offset X must be defined for hitbox: ' .. attackType)
        assert(hitbox.width, 'Width must be defined for hitbox: ' .. attackType)
        assert(hitbox.height, 'Height must be defined for hitbox: ' .. attackType)
    end

    for attackType, attack in pairs(self.attacks) do
        assert(attack.start, 'Start frame must be defined for attack: ' .. attackType)
        assert(attack.active, 'Active frame must be defined for attack: ' .. attackType)
        assert(attack.damage, 'Damage must be defined for attack: ' .. attackType)
        assert(attack.recovery, 'Recovery time must be defined for attack: ' .. attackType)
    end
end

function Fighter:loadSpritesheets(configs)
    local spritesheets = {}

    for key, config in pairs(configs) do
        spritesheets[key] = love.graphics.newImage(config.path)
        print(
            'Loaded spritesheet for',
            key,
            'from',
            config.path,
            'with frame count:',
            config.frames,
            'and dimensions:',
            spritesheets[key]:getDimensions()
        )
    end

    return spritesheets
end

function Fighter:loadAnimations(configs)
    local animations = {}

    for key, config in pairs(configs) do
        local path = config.path
        local frameCount = config.frames
        local frameDuration = config.frameDuration
        local spritesheet = self.spritesheets[key]
        local frameWidth = math.floor(spritesheet:getWidth() / frameCount)
        local frameHeight = spritesheet:getHeight()

        animations[key] = self:createAnimation(spritesheet, frameWidth, frameHeight, frameCount, frameDuration)
    end

    return animations
end

function Fighter:loadAnimationDurations(configs)
    local durations = {}
    for stateOrAttack, config in pairs(configs) do
        local totalDuration = 0
        for _, duration in ipairs(config.frameDuration) do
            totalDuration = totalDuration + duration
        end
        durations[stateOrAttack] = totalDuration
    end
    return durations
end

function Fighter:loadSoundFX(configs)
    local sounds = {}
    for key, filePath in pairs(configs) do
        sounds[key] = SoundManager:loadSound(filePath)
    end
    -- add clash
    sounds['clash'] = SoundManager:loadSound('assets/clash.mp3')
    return sounds
end

function Fighter:createAnimation(image, frameWidth, frameHeight, frameCount, frameDuration)
    if not image then
        print('Error: Image for animation is nil')
        return nil
    end
    local grid = Anim8.newGrid(frameWidth, frameHeight, image:getWidth(), image:getHeight())
    local animation = Anim8.newAnimation(grid('1-' .. frameCount, 1), frameDuration)

    -- Used on death
    function animation:pauseAtEnd()
        self:gotoFrame(frameCount)
        self:pause()
    end

    return animation
end

function Fighter:update(dt, other)
    if self.state ~= 'death' then
        -- Handle all actions except death
        self:updateActions(dt, other)
        -- Update the state of the fighter after handling actions
        self:updateState(dt, other)
    else
        -- Handle death animation
        self:checkDeathAnimationFinished()
    end

    -- Always update the current animation
    self.currentAnimation:update(dt)
end

function Fighter:updateActions(dt, other)
    self:handleMovement(dt, other)
    self:handleJumping(dt, other)
    self:handleAttacks(other)
    self:handleDamage(other)
end

function Fighter:updateState(dt, other)
    local currentTime = love.timer.getTime()
    local isAttacking = self.state == 'attacking'
    local isHit = self.state == 'hit'
    local isRecoveryPeriodOver = currentTime >= self.recoveryEndTime
    local isAttackPeriodOver = currentTime >= self.attackEndTime
    local isHitPeriodOver = currentTime >= self.hitEndTime
    local isIdle = self.state == 'idle'

    -- Handle knockback
    if self.knockbackActive or self.knockbackDelayTimer > 0 then
        self:checkForKnockback(dt)
    end

    -- Check if active attack
    if isAttacking then
        self:checkAttackActivity(currentTime)
        self:checkForClash(other)
    end

    -- Transition from attacking to recovery if the attack period has ended
    if isAttacking and isAttackPeriodOver then
        if self.isAirborne then
            self:setState('jump')
        else
            self:setState('idle')
        end

        -- Start recovery period
        self:startRecovery(self.attackType)
    end

    -- End recovery period if the recovery time has passed
    if self.isRecovering and isRecoveryPeriodOver then
        self:endRecovery()
    end

    -- Transition from hit to idle if the hit period has ended
    if isHit and isHitPeriodOver then
        self:setState('idle')
    end

    -- Recover stamina if the fighter is idle
    if isIdle then
        self:recoverStamina(dt)
    end
end

function Fighter:checkAttackActivity()
    local currentFrame = self.currentAnimation.position
    -- Check if attack is active
    if currentFrame >= self.attackActiveFrame and currentFrame < self.attackEndFrame then
        self.isAttackActive = true
    else
        self.isAttackActive = false
    end
end

function Fighter:handleMovement(dt, other)
    if self.state == 'attacking' or self.state == 'hit' or self.isClashing or self.knockbackActive then
        return
    end

    local windowWidth = love.graphics.getWidth()
    local currentTime = love.timer.getTime()

    -- Handle dashing
    if self.isDashing then
        if currentTime < self.dashEndTime then
            local dashSpeed = self.direction * self.dashSpeed * dt
            local newX = self.x + dashSpeed
            if newX < 0 then
                newX = 0
            elseif newX + self.width > windowWidth then
                newX = windowWidth - self.width
            end
            if not self:checkXCollision(newX, self.y, other) then
                self.x = newX
            end
            return -- Exit movement handling while dashing
        else
            self.isDashing = false
        end
    end

    -- Detect double-tap for dashing
    if not self.isAI then -- AI doesn't need to check for double-tap
        if love.keyboard.wasPressed(self.controls.left) then
            if currentTime - (self.lastTapTime.left or 0) < 0.3 then
                self:startDash(-1)
            end
            self.lastTapTime.left = currentTime
        elseif love.keyboard.wasPressed(self.controls.right) then
            if currentTime - (self.lastTapTime.right or 0) < 0.3 then
                self:startDash(1)
            end
            self.lastTapTime.right = currentTime
        end
    end

    -- Handle normal movement
    if love.keyboard.isDown(self.controls.left) then
        self.direction = -1 -- Set direction to left
        local newX = self.x - self.speed * dt
        if newX < 0 then
            newX = 0
        end
        if not self:checkXCollision(newX, self.y, other) then
            self.x = newX
            if not self.isAirborne then
                self:setState('run')
            end
        end
    elseif love.keyboard.isDown(self.controls.right) then
        self.direction = 1 -- Set direction to right
        local newX = self.x + self.speed * dt
        if newX + self.width > windowWidth then
            newX = windowWidth - self.width
        end
        if not self:checkXCollision(newX, self.y, other) then
            self.x = newX
            if not self.isAirborne then
                self:setState('run')
            end
        end
    elseif not self.isAirborne then
        self:setState('idle') -- Set state to idle if no movement keys are pressed
    end

    self.isBlocking = self.direction == other.direction
end

function Fighter:startDash(direction)
    if self.stamina >= self.dashStaminaCost then
        self.isDashing = true
        self.direction = direction
        self.dashEndTime = love.timer.getTime() + self.dashDuration
        self.stamina = self.stamina - self.dashStaminaCost -- Consume stamina
        SoundManager:playSound(self.sounds.dash, {clone = true}) -- Use the clone parameter here
    end
end

function Fighter:recoverStamina(dt)
    if self.state == 'idle' and self.stamina < self.maxStamina then
        self.stamina = self.stamina + self.dashStaminaCost * dt
        if self.stamina > self.maxStamina then
            self.stamina = self.maxStamina
        end
    end
end

function Fighter:checkXCollision(newX, newY, other)
    return not (newX + self.width <= other.x or newX >= other.x + other.width or newY + self.height <= other.y or
        newY >= other.y + other.height)
end

function Fighter:handleJumping(dt, other)
    local windowHeight = love.graphics.getHeight()
    local groundLevel = windowHeight - 10 -- Define the ground level
    local skyLevel = 0 -- Define the top level (skybox)

    -- Boolean flags for readability
    local isAttacking = self.state == 'attacking'
    local isHit = self.state == 'hit'
    local isRecovering = self.isRecovering
    local isClashing = self.isClashing
    local isAirborne = self.isAirborne
    local isFalling = self.dy > 0
    local isAllowedToJump = not isAirborne and not isAttacking and not isHit and not isRecovering and not isClashing
    local isAllowedToChangeState = not isAttacking and not isHit and not isRecovering and not isClashing

    -- Update vertical position due to gravity
    self.dy = self.dy + self.gravity * dt

    -- Potential new position after applying gravity
    -- REMEMBER: y-axis is inverted in LOVE2D, BIGGER NUMBER = LOWER POSITION
    local newY = self.y + self.dy * dt
    local isOnOrBelowGround = newY >= groundLevel - self.height -- Check if the new position is on the ground

    -- Check for collision with the ground
    if isOnOrBelowGround then
        self.y = groundLevel - self.height
        self.isAirborne = false
        self.dy = 0
        if isAllowedToChangeState then
            if not love.keyboard.isDown(self.controls.left) and not love.keyboard.isDown(self.controls.right) then
                self:setState('idle') -- Set state to idle if no movement keys are pressed
            elseif isFalling then
                self:setState('jump') -- Set state to jump if the fighter is falling
            end
        end
    elseif newY <= skyLevel then
        -- Prevent fighter from moving above the top of the screen
        self.y = skyLevel
        self.dy = 0
    elseif self:checkYCollision(newY, other) then
        -- Check for collision with the other fighter
        if isFalling then
            self.y = other.y - self.height -- Adjust position if colliding while falling
            self.dy = 0
            self.isAirborne = false
        else
            self.y = self.y -- Keep current position if rising
            self.dy = 0
        end

        -- Set state to idle (standing on top)
        if isAllowedToChangeState then
            self:setState('idle') -- Set state to idle if conditions allow
        end
    else
        -- Update position if no collision with the opponent
        self.y = newY
        self.isAirborne = true
    end

    -- Only allow initiating a jump if certain conditions are met
    if isAllowedToJump and love.keyboard.wasPressed(self.controls.jump) then
        self.dy = self.jumpStrength
        self.isAirborne = true
        self:setState('jump')
        -- Play jump sound
        SoundManager:playSound(self.sounds.jump)
    end
end

function Fighter:checkYCollision(newY, other)
    return not (self.x + self.width <= other.x or self.x >= other.x + other.width or newY + self.height < other.y or
        newY > other.y + other.height)
end

function Fighter:handleAttacks()
    if love.keyboard.wasPressed(self.controls.light) then
        self:startAttack('light')
    elseif love.keyboard.wasPressed(self.controls.medium) then
        self:startAttack('medium')
    elseif love.keyboard.wasPressed(self.controls.heavy) then
        self:startAttack('heavy')
    end
end

function Fighter:handleDamage(other)
    self.isBlockingDamage = false

    if other.state ~= 'attacking' or not self:isHit(other) then
        return
    end

    if self.isBlocking then
        self.isBlockingDamage = true
        -- Play block sound effect if available
        SoundManager:playSound(self.sounds.block)
    elseif not other.damageApplied then
        local attackHitbox = other:getAttackHitbox()
        local attackData = other.attacks[other.attackType]
        if attackHitbox then
            local attackDamage = attackData.damage
            self:takeDamage(attackDamage)
            other.damageApplied = true -- Ensure damage is only applied once
        end
    end
end

function Fighter:startAttack(attackType)
    if self.state == 'attacking' or self.state == 'hit' or self.isRecovering then
        return -- Prevent new attacks from starting if already attacking or recovering or hit
    end

    -- Stamina
    local mediumStaminaCost = 15
    local heavyStaminaCost = 30
    local staminaCost = 0
    if attackType == 'medium' then
        staminaCost = mediumStaminaCost
    elseif attackType == 'heavy' then
        staminaCost = heavyStaminaCost
    end
    if self.stamina < staminaCost then
        return -- Prevent attack if not enough stamina
    end
    self.stamina = self.stamina - staminaCost -- Deduct stamina

    -- Start attack state change
    self.state = 'attacking' -- Note: Don't use self.setState() here
    self.attackType = attackType
    self.lastAttackType = attackType
    self.damageApplied = false -- Reset damage applied for attacker (Important not to stack damage)

    -- Get the precomputed attack duration
    local attackDuration = self.animationDurations[attackType]
    self.attackEndTime = love.timer.getTime() + attackDuration

    -- Get the attack data
    local attackData = self.attacks[attackType]

    -- Set the current animation to the attack animation
    self.currentAnimation = self.animations[attackType]
    self.currentAnimation:gotoFrame(1)
    self.isAttackActive = false

    -- Store start and active frame durations
    self.attackActiveFrame = attackData.start
    self.attackEndFrame = attackData.active

    -- Play the attack sound
    SoundManager:playSound(self.sounds[attackType], {clone = true})
end

function Fighter:startRecovery(attackType)
    if _G.isDebug then
        print('Recovery started for', self.id, 'attack', attackType)
    end
    self.recoveryEndTime = love.timer.getTime() + self.attacks[attackType].recovery

    self.attackType = nil
    self.isRecovering = true
end

function Fighter:endRecovery()
    if _G.isDebug then
        print('Recovery ended for', self.id)
    end
    self.isRecovering = false
end

function Fighter:checkForClash(other)
    local isAllowedToClash =
        self.state == 'attacking' and other.state == 'attacking' and not self.isBlocking and not other.isBlocking and
        not (self:isHit(other) or other:isHit(self))
    if not isAllowedToClash then
        return
    end

    local myHitbox = self:getAttackHitbox()
    local opponentHitbox = other:getAttackHitbox()
    -- Check if the hitboxes overlap
    if self:checkHitboxOverlap(myHitbox, opponentHitbox) then
        self:resolveClash(other)
    end
end

function Fighter:checkForKnockback(dt)
    local windowWidth = love.graphics.getWidth()

    if self.knockbackDelayTimer > 0 then
        self.knockbackDelayTimer = self.knockbackDelayTimer - dt
        if self.knockbackDelayTimer <= 0 then
            self.knockbackActive = true -- Activate knockback after delay
        end
        return
    end

    if self.knockbackActive and self.state ~= 'run' then
        -- Check if the fighter is close to the target position to stop
        if math.abs(self.x - self.knockbackTargetX) < 1 then
            self.knockbackActive = false -- Stop knockback when close to target
            self.isClashing = false

            -- Apply pending damage after knockback
            if self.pendingDamage and self.knockbackApplied then
                self:takeDamage(self.pendingDamage)
                self.pendingDamage = nil
                self.knockbackApplied = false
                self.isClashing = false
            end
        else -- Move incrementally towards the target
            local knockbackStep = self.knockbackSpeed * dt * self.direction * -1 -- Move in the opposite direction
            local newX = self.x + knockbackStep

            -- Ensure the new position is within bounds
            if newX < 0 then
                self.x = 0
                self.knockbackActive = false -- Stop knockback when close to target
                self.isClashing = false
            elseif newX + self.width > windowWidth then
                self.x = windowWidth - self.width
                self.knockbackActive = false -- Stop knockback when close to target
                self.isClashing = false
            else
                self.x = newX -- Move incrementally towards target
            end
        end
    end
end

function Fighter:checkHitboxOverlap(hitbox1, hitbox2)
    return hitbox1.x < hitbox2.x + hitbox2.width and hitbox1.x + hitbox1.width > hitbox2.x and
        hitbox1.y < hitbox2.y + hitbox2.height and
        hitbox1.y + hitbox1.height > hitbox2.y
end

function Fighter:resolveClash(other)
    local currentTime = love.timer.getTime()

    -- Both fighters lose stamina during clash
    self.stamina = math.max(self.stamina - 10, 0)
    other.stamina = math.max(other.stamina - 10, 0)

    -- If both fighters have no stamina, no clash happens
    if self.stamina == 0 and other.stamina == 0 then
        self.isClashing = false
        self.lostClash = false
        other.lostClash = false
        return
    end

    -- Compare attack types and determine the winner
    local myAttackWeight = self:getAttackWeight(self.attackType)
    local opponentAttackWeight = self:getAttackWeight(other.attackType)

    if myAttackWeight == opponentAttackWeight then
        -- Both attacks are of the same weight, both fighters are knocked back
        self:applyKnockback()
        other:applyKnockback()
        self.isClashing = true
        other.isClashing = true
        self.clashTime = currentTime
        other.clashTime = currentTime
        self.lostClash = false
        other.lostClash = false
    else
        -- Different attack types, the heavier one wins
        if myAttackWeight > opponentAttackWeight or other.stamina == 0 then
            self:winClash(other)
            self.lostClash = false
            other.lostClash = true
        elseif opponentAttackWeight > myAttackWeight or self.stamina == 0 then
            other:winClash(self)
            self.lostClash = true
            other.lostClash = false
        end

        self.isClashing = true
        other.isClashing = true
        self.clashTime = currentTime
        other.clashTime = currentTime
    end
end

function Fighter:getAttackWeight(attackType)
    local weights = {
        light = 1,
        medium = 2,
        heavy = 3
    }
    return weights[attackType] or 0
end

function Fighter:applyKnockback()
    local baseKnockbackDelay = self.knockbackDelay
    local attackType = self.attackType or 'light'

    -- Adjust knockback delay based on the attack type
    if attackType == 'medium' then
        baseKnockbackDelay = baseKnockbackDelay + 0.2
    elseif attackType == 'heavy' then
        baseKnockbackDelay = baseKnockbackDelay + 0.4
    end

    self.knockbackTargetX = self.x + (self.direction * -100) -- Set the target position for knockback
    self.knockbackActive = false -- Knockback will be active after delay
    self.knockbackDelayTimer = baseKnockbackDelay -- Set the delay timer
    self.lostClash = false -- Reset lost clash flag

    -- Play clash sound effect
    SoundManager:playSound(self.sounds.clash, {preventOverlap = true})
end

function Fighter:winClash(loser)
    -- Instead of applying damage immediately, set a flag to apply it later
    loser.pendingDamage = self.attacks[loser.attackType].damage / 2
    loser.knockbackApplied = true
    loser:applyKnockback()
end

function Fighter:setState(newState)
    -- Only change state if the new state is different from the current state
    if self.state == newState then
        return
    end
    self.state = newState

    -- Determine the appropriate animation for the new state
    local newAnimation = self.animations[newState] or self.animations.idle
    self.currentAnimation = newAnimation
    self.currentAnimation:gotoFrame(1)
end

function Fighter:render(other)
    self:drawSprite()
    if _G.isDebug then
        self:drawHitboxes(other)
    end
end

function Fighter:drawSprite()
    local spriteName = self.state == 'attacking' and self.lastAttackType or self.state
    local sprite = self.spritesheets[spriteName] or self.spritesheets.idle

    if self.currentAnimation then
        local frameWidth, frameHeight = self.currentAnimation:getDimensions()
        local scaleX = self.scale.x * self.direction
        local scaleY = self.scale.y
        local offsetX = (self.width - (frameWidth * scaleX)) / 2
        local offsetY = (self.height - (frameHeight * scaleY)) / 2
        local angle = 0
        local posX = self.x + offsetX + (self.scale.ox * self.direction)
        local posY = self.y + offsetY + self.scale.oy

        -- Draw the current animation
        self.currentAnimation:draw(sprite, posX, posY, angle, scaleX, scaleY)

        -- Debug information
        if _G.isDebug and self.id == 1 then
            print(self.scale.ox, self.scale.oy, posX, posY)
            print('[Sprite]:', posX, posY, '<- pos, scale ->', scaleX, scaleY)
        end
    else
        print('Error: No current animation to draw for state:', self.state)
    end
end

function Fighter:drawHitboxes()
    -- Draw Fighter hitbox
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('line', self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 0, 0, 1) -- Red color for the debug dot
    love.graphics.circle('fill', self.x, self.y, 5) -- Draw a small circle (dot) at (self.x, self.y)
    love.graphics.setColor(1, 1, 1, 1) -- Reset color

    -- Draw Fighter attack hitbox
    if self.isAttackActive then
        local hitbox = self:getAttackHitbox()
        if hitbox then
            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.rectangle('line', hitbox.x, hitbox.y, hitbox.width, hitbox.height)
            love.graphics.setColor(1, 1, 1, 1) -- Reset color
        end
    end

    -- Draw Opponent hitbox
    if self.id == 1 then
        print(
            '[Fighter ' .. self.id .. ']:',
            self.state,
            'x',
            self.x,
            'y',
            self.y,
            'state:',
            self.state,
            'attackType:',
            self.attackType,
            'isRecovering:',
            self.isRecovering,
            'isClashing:',
            self.isClashing,
            'isKnockbackActive:',
            self.knockbackActive,
            'deathAnimationFinished:',
            self.deathAnimationFinished
        )
    end
end

function Fighter:getAttackHitbox()
    if not self.attackType or not self.hitboxes[self.attackType] then
        return nil
    end

    local hitbox = self.hitboxes[self.attackType]
    local hitboxX =
        self.direction == 1 and (self.x + self.width + (hitbox.ox or 0)) or (self.x - hitbox.width + (hitbox.ox or 0))

    return {
        x = hitboxX,
        y = self.y + (self.height - hitbox.height) / 2 + (hitbox.oy or 0),
        width = hitbox.width,
        height = hitbox.height,
        damage = hitbox.damage
    }
end

function Fighter:isHit(other)
    -- Check if the hitbox overlaps with the fighter's hitbox
    local hitbox = other:getAttackHitbox()
    if hitbox and not other.damageApplied and other.isAttackActive then
        if
            hitbox.x < self.x + self.width and hitbox.x + hitbox.width > self.x and hitbox.y < self.y + self.height and
                hitbox.y + hitbox.height > self.y
         then
            return true
        end
    end
    return false
end

function Fighter:takeDamage(damage)
    self.health = self.health - damage
    if self.health <= 0 then
        -- Dead
        self.health = 0
        -- Helps ensure the death animation is played only once
        if self.state ~= 'death' then
            self:setState('death')

            -- Play death animation
            self.currentAnimation = self.animations.death
            self.currentAnimation:gotoFrame(1)

            -- Play death sound
            SoundManager:playSound(self.sounds.death)

            -- Set the start time for the death animation
            self.deathAnimationStartTime = love.timer.getTime()
        end
    else
        self:setState('hit')

        -- Play hit animation
        self.currentAnimation = self.animations.hit
        self.currentAnimation:gotoFrame(1)

        -- Play hit sound effect if available
        SoundManager:playSound(self.sounds.hit)

        -- Set state back to idle after hit animation duration
        local hitDuration = self.currentAnimation.totalDuration
        self.hitEndTime = love.timer.getTime() + hitDuration
    end
end

function Fighter:checkDeathAnimationFinished()
    if self.state == 'death' then
        local currentTime = love.timer.getTime()
        local elapsedTime = currentTime - self.deathAnimationStartTime
        local deathDuration = self.animationDurations['death']

        if elapsedTime >= deathDuration then
            self.deathAnimationFinished = true
            self.currentAnimation:pauseAtEnd() -- Pause the animation at the last frame
        end
    end
end

return Fighter
