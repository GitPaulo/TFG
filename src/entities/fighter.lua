local Anim8 = require 'lib.anim8'

local Class, love, SoundManager = _G.Class, _G.love, _G.SoundManager
local Fighter = Class:extend()

-- Enum: State
_G.ANIM_STATE_IDLE = "idle"
_G.ANIM_STATE_RUN = "run"
_G.ANIM_STATE_JUMP = "jump"
_G.ANIM_STATE_LIGHT_ATTACK = "light"
_G.ANIM_STATE_MEDIUM_ATTACK = "medium"
_G.ANIM_STATE_HEAVY_ATTACK = "heavy"
_G.ANIM_STATE_HIT = "hit"
_G.ANIM_STATE_DEATH = "death"
_G.ANIM_STATE_KNOCKBACK = "knockback"
_G.ANIM_STATE_DASHING = "dashing"
_G.ANIM_STATE_STUNNED = "stunned"
_G.ANIM_STATE_GRAB = "grab"
_G.ANIM_STATE_INTERACT = "interact"

-- Enum: Attack Type
_G.ATTACK_TYPE_LIGHT = "light"
_G.ATTACK_TYPE_MEDIUM = "medium"
_G.ATTACK_TYPE_HEAVY = "heavy"

-- Enum: Direction
_G.DIRECTION_LEFT = -1
_G.DIRECTION_RIGHT = 1

-- Enum: Fighter General
_G.FIGHTER_STUNNED_DURATION = 1.5
_G.FIGHTER_DASH_DURATION = 0.2
_G.FIGHTER_GRAVITY = 1000
_G.FIGHTER_KNOCKBACK_SPEED = 400
_G.FIGHTER_KNOCKBACK_DELAY = 0.2
_G.FIGHTER_GRAB_RANGE = 50 -- TODO: the origin can vary by model... Bad!

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
    self.staminaRecoveryRate = traits.staminaRecoveryRate or 10
    self.jumpStrength = -(traits.jumpStrength or 600)
    self.dashSpeed = traits.dashSpeed or 500
    self.hitboxes = hitboxes or {}
    self.attacks = attacks or {}
    self.isAI = isAI or false

    -- Check
    self:assertRequiredTraits()

    -- Position and movement
    self.dy = 0
    self.direction = (id == 1) and DIRECTION_RIGHT or DIRECTION_LEFT -- Set direction to right for player 1 and left for player 2
    -- General State: 1:1 with the animation states AND any state that is mutually exclusive
    self.state = ANIM_STATE_IDLE
    -- Character Flags, MORE THAN ONE can be active at the same time
    -- Character State: block
    self.isBlocking = false
    self.isBlockingDamage = false
    -- Character State: jump
    self.isAirborne = false
    self.isGrounded = true
    self.gravity = FIGHTER_GRAVITY
    -- Character State: attack
    self.isAttacking = false -- This is the general attack flag
    self.isAttackActive = false -- This is the flag for the active attack => FRAME <=
    self.attackType = nil
    self.lastAttackType = nil
    self.attackEndTime = 0
    -- Character State: dash
    self.dashDuration = FIGHTER_DASH_DURATION
    self.dashEndTime = 0
    self.dashStaminaCost = 25
    self.dashLastPressTime = {left = 0, right = 0}
    self.dashPressWindow = 0.3
    -- Character State: clash
    self.isClashing = false
    self.clashTime = 0
    self.knockbackTargetX = self.x
    self.knockbackActive = false
    self.knockbackDelayTimer = 0
    self.knockbackApplied = false
    self.pendingDamage = nil
    self.lostClash = false
    -- Character State: hit
    self.hitEndTime = 0
    self.damageApplied = false -- ensures it only every applies once
    -- Character State: recovery
    self.isRecovering = false
    self.recoveryEndTime = 0
    -- Character State: stun
    self.isStunned = false
    self.stunnedTimer = 0
    -- Character State: grab
    self.grabStartTime = nil
    self.grabHasThrown = false
    self.grabDirection = self.direction
    self.isGrabPositioned = false

    -- Other
    self.deathAnimationFinished = false

    -- Animation, Sprites and sound
    self.spritesheets = self:loadSpritesheets(spriteConfig)
    self.animations = self:loadAnimations(spriteConfig)
    self.animationDurations = self:loadAnimationDurations(spriteConfig)
    self.sounds = self:loadSoundFX(soundFXConfig) -- Fighter related sound effects

    -- Set the default animation to idle
    self.currentAnimation = self.animations.idle
end

--[[
    Load
--]]

function Fighter:assertRequiredTraits()
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
        assert(attack.cost, 'Stamina cost must be defined for attack: ' .. attackType)
        assert(attack.recovery, 'Recovery time must be defined for attack: ' .. attackType)
    end
end

function Fighter:loadSpritesheets(configs)
    local spritesheets = {}

    for key, config in pairs(configs) do
        spritesheets[key] = love.graphics.newImage(config.path)

        if _G.isDebug then
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
    -- TODO: suspect bad code
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

--[[
    Update
--]]

function Fighter:update(dt, other)
    if self.state ~= ANIM_STATE_DEATH then
        -- Update state: update -> hit, recovery, stun, knockback
        self:updateState(dt, other)
        -- Update input: start -> attack, start dash, start jump
        self:updateInput(dt, other)
        -- Update actions: apply -> movement, jumping, attacking
        self:updateActions(dt, other)
    else
        -- Update death animation
        self:updateDeathAnimation()
    end

    -- Always update the current animation
    self.currentAnimation:update(dt)
end

function Fighter:updateState(dt, other)
    self:handleStun(dt)
    self:handleKnockback(dt)
    self:handleClash(other)
    self:handleDamage(other)
    self:handleStamina(dt)
    self:handleRecovery()
end

function Fighter:updateInput(dt, other)
    if self.isAI then
        self:handleAIInput(dt, other)
    else 
        self:handlePlayerInput(dt, other)
    end
end

function Fighter:updateActions(dt, other)
    self:handleAttacks(other)
    self:handleMovement(dt, other)
    self:handleBlocking(dt, other)
    self:handleJumping(dt, other)    
    self:handleGrab(dt, other)
end

function Fighter:handleAIInput(dt, other)
    -- TODO
end

function Fighter:handlePlayerInput(dt, other)
    -- Current time
    local currentTime = love.timer.getTime()
    local startState = self.state
    -- Check conditions
    local isAttacking = self.isAttacking
    local isDead = self.state == ANIM_STATE_DEATH
    local isJumping = self.state == ANIM_STATE_JUMP
    local isDashing = self.state == ANIM_STATE_DASHING
    local isStunned = self.state == ANIM_STATE_STUNNED
    local isGrabbing = self.state == ANIM_STATE_GRAB
    local isHit = self.state == ANIM_STATE_HIT
    local isAllowedToJump = not isAttacking and not isHit and not isDashing and 
        not self.isRecovering and not self.isClashing and not self.isStunned and not self.isAirborne and not self.knockbackActive

    ---
    --- Pre (new) input handling
    ---
    if love.keyboard.isDown(self.controls.left) or love.keyboard.isDown(self.controls.right) then
        self:setGrabDirection()
    end

    -- Block (new) input in blocked states
    if isDead or isDashing or isHit or isStunned or isGrabbing or self.isClashing or self.knockbackActive or self.isStunned or self.isAttacking then
        return
    end

    --
    -- Dashing
    ---
    if love.keyboard.wasPressed(self.controls.left) then
        if currentTime - (self.dashLastPressTime.left or 0) < self.dashPressWindow then
            self:startDash(DIRECTION_LEFT)
            return;
        end
        self.dashLastPressTime.left = currentTime
    end
    if love.keyboard.wasPressed(self.controls.right) then
        if currentTime - (self.dashLastPressTime.right or 0) < self.dashPressWindow then
            self:startDash(DIRECTION_RIGHT)
            return
        end
        self.dashLastPressTime.right = currentTime
    end

    ---
    --- Movement
    ---
    if love.keyboard.isDown(self.controls.left) then
        self:startRun(DIRECTION_LEFT, dt, other)
    elseif love.keyboard.isDown(self.controls.right) then
        self:startRun(DIRECTION_RIGHT, dt, other)
    end

    ---
    --- Jumping
    ---
    if isAllowedToJump and love.keyboard.wasPressed(self.controls.jump) then
        self:startJump()
    end

    --- 
    --- Attacks
    ---
    if love.keyboard.wasPressed(self.controls.light) then
        self:startAttack(ATTACK_TYPE_LIGHT)
    elseif love.keyboard.wasPressed(self.controls.medium) then
        self:startAttack(ATTACK_TYPE_MEDIUM)
    elseif love.keyboard.wasPressed(self.controls.heavy) then
        self:startAttack(ATTACK_TYPE_HEAVY)
    end

    ---
    --- Grab
    ---
    if love.keyboard.wasPressed(self.controls.grab) then
        self:startGrab(other)
    end

    ---
    --- Interact
    ---
    if love.keyboard.wasPressed(self.controls.interact) then
        self:startInteract(other)
    end

    --- 
    --- Idle
    ---
    if self:noKeysPressed() and not self.isAirborne then
        self:setAnimState(ANIM_STATE_IDLE)
    end
end

function Fighter:handleStun(dt)
    if self.state ~= ANIM_STATE_STUNNED then
        return
    end

    -- Decrease the stun timer
    self.stunnedTimer = self.stunnedTimer - dt
    if self.stunnedTimer <= 0 then
        self:setAnimState(ANIM_STATE_IDLE)
    end
end

function Fighter:handleAttacks(other)
    local currentTime = love.timer.getTime()

    -- Check if an attack is active and handle its end
    if self.isAttacking then
        -- Set when attack hitboxes are active
        -- Note: attackData.active = end frame
        local attackData = self.attacks[self.attackType]
        if attackData then
            local currentFrame = self.currentAnimation.position
            if currentFrame >= attackData.start and currentFrame < attackData.active then
                self.isAttackActive = true
            else
                self.isAttackActive = false
            end
        end

        -- Check if attack duration has elapsed
        if currentTime >= self.attackEndTime then
            self.isAttacking = false
            self.isAttackActive = false
            self.damageApplied = false
            self.attackType = nil
            self.attackActiveFrame = nil
            self.attackEndFrame = nil
            other.isBlockingDamage = false -- Reset blocking damage flag for other

            self:setAnimState(ANIM_STATE_IDLE)           
            self:startRecovery()
        end
    end
end

function Fighter:handleDamage(other)
    local currentTime = love.timer.getTime()
    local isHit = self.state == ANIM_STATE_HIT
    
    -- Reset hit state to idle
    if isHit and currentTime > self.hitEndTime then
        self:setAnimState(ANIM_STATE_IDLE)
    end

    -- Prevent applying damage multiple times
    if other.damageApplied then
        return
    end

    -- Retrieve attack hitbox and data
    local attackHitbox = other:getAttackHitbox()
    local attackData = other.attacks[other.attackType]
    if not attackHitbox or not attackData then
        return -- Exit if no valid hitbox or attack data
    end

    -- Check for hitbox overlap
    local selfHitbox = self:getHitbox()
    if not self:checkHitboxOverlap(selfHitbox, attackHitbox) then
        return -- Exit if no hit
    end

    -- Handle blocking
    local blockingStaminaCost = 10
    if self.isBlocking and self.stamina >= blockingStaminaCost then
        if self.isBlockingDamage then
            return -- ensure stamina cost is applied once
        end
        self.isBlockingDamage = true -- gets reset by other's end of attack
        self.stamina = self.stamina - blockingStaminaCost
        SoundManager:playSound(self.sounds.block)
        return
    end

    -- Apply full damage
    self:takeDamage(attackData.damage)
    other.damageApplied = true
end

function Fighter:handleRecovery()
    local currentTime = love.timer.getTime()
    local isRecoveryPeriodOver = currentTime >= self.recoveryEndTime

    -- End recovery period
    if self.isRecovering and isRecoveryPeriodOver then
        self.isRecovering = false
    end
end

function Fighter:handleStamina(dt)
    local isIdle = self.state == ANIM_STATE_IDLE
    -- Recover stamina if the fighter is idle
    if isIdle then
        if self.state == ANIM_STATE_IDLE and self.stamina < self.maxStamina then
            self.stamina = self.stamina + self.staminaRecoveryRate * dt
            if self.stamina > self.maxStamina then
                self.stamina = self.maxStamina
            end
        end
    end
end

function Fighter:handleMovement(dt, other)
    local windowWidth = love.graphics.getWidth()
    local currentTime = love.timer.getTime()
    local newX = self.x -- Starting position

    -- Handle dashing
    if self.state == ANIM_STATE_DASHING then
        if currentTime < self.dashEndTime then
            -- Calculate dash movement
            local dashSpeed = self.direction * self.dashSpeed * dt
            newX = self.x + dashSpeed

            -- Clamp position to screen bounds
            newX = math.max(0, math.min(newX, windowWidth - self.width))

            -- Move if no collision
            if not self:checkXCollision(newX, self.y, other) then
                self.x = newX
            end

            return -- Exit movement handling while dashing
        else
            -- Transition to running state after dashing
            self:setAnimState(ANIM_STATE_RUN)
        end
    end

    -- Handle running
    if self.state == ANIM_STATE_RUN then
        -- Adjust position based on direction
        if self.direction == DIRECTION_LEFT then
            newX = self.x - self.speed * dt
            -- Clamp position to screen bounds (left edge)
            newX = math.max(0, newX)
        elseif self.direction == DIRECTION_RIGHT then
            newX = self.x + self.speed * dt
            -- Clamp position to screen bounds (right edge)
            newX = math.min(newX, windowWidth - self.width)
        end

        -- Move if no collision
        if not self:checkXCollision(newX, self.y, other) then
            self.x = newX
        end
    end
end

function Fighter:handleBlocking(dt, other)
    local isStunned = self.state == ANIM_STATE_STUNNED
    local isHit = self.state == ANIM_STATE_HIT

    if isStunned or isHit then
        self.isBlocking = false
        return -- Can't block!
    end
    
    -- A fighter blocks if their back is turned to the opponent or if both fighters are turned away
    local isFacingOpponent = (self.direction == 1 and self.x < other.x) 
                                or (self.direction == -1 and self.x > other.x)
    self.isBlocking = not isFacingOpponent or self.direction == other.direction
end

function Fighter:handleJumping(dt, other)
    local windowHeight = love.graphics.getHeight()
    local groundLevel = windowHeight - 10 -- Ground level
    local skyLevel = 0 -- Skybox level

    -- Update vertical velocity due to gravity
    self.dy = self.dy + self.gravity * dt
    local newY = self.y + self.dy * dt -- Potential new position (gravity applied)

    -- Handle landing on opponent's head
    local feetY = self.y + self.height
    local headY = other.y
    local isOnHead = (self.x + self.width > other.x and self.x < other.x + other.width) and (feetY >= headY and feetY <= headY + 10)
    if isOnHead and self.dy > 0 then
        other:startStun() 
        self.dy = self.jumpStrength * 0.69 -- Apply bounce
        self.y = other.y - self.height -- Correct position to prevent overlap
        return -- bounce only!
    end

    -- Handle collisions
    local isJumping = self.state == ANIM_STATE_JUMP
    if newY >= groundLevel - self.height then
        -- Handle ground collision
        self.y = groundLevel - self.height
        self.dy = 0
        self.isAirborne = false
        self.isGrounded = true
        if isJumping then
            self:setAnimState(ANIM_STATE_IDLE)
        end
    elseif newY <= skyLevel then
        -- Handle ceiling collision
        self.y = skyLevel
        self.dy = 0
        self.isAirborne = true
        self.isGrounded = false
    elseif self:checkYCollision(newY, other) then
        -- General collision logic
        self.y = other.y - self.height
        self.dy = 0
        self.isAirborne = false
        self.isGrounded = true
        if isJumping then
            self:setAnimState(ANIM_STATE_IDLE)
        end
    else
        -- Normal movement (no collision)
        self.y = newY
        self.isAirborne = true
        self.isGrounded = false
    end
end

function Fighter:handleClash(other)
    -- Check if a clash is allowed
    if not (self.isAttacking and other.isAttacking and self.state ~= ANIM_STATE_HIT and other.state ~= ANIM_STATE_HIT) then
        return
    end

    -- Check if hitboxes overlap
    local myHitbox = self:getAttackHitbox()
    local opponentHitbox = other:getAttackHitbox()
    if not self:checkHitboxOverlap(myHitbox, opponentHitbox) then
        return
    end

    -- Both fighters lose stamina during clash
    self.stamina = math.max(self.stamina - 10, 0)
    other.stamina = math.max(other.stamina - 10, 0)

    -- If both fighters have no stamina, no clash happens
    if self.stamina == 0 and other.stamina == 0 then
        self.isClashing = false
        other.isClashing = false
        self.lostClash = false
        other.lostClash = false
        return
    end

    -- Compare attack weights
    local myAttackWeight = self:getAttackWeight(self.attackType)
    local opponentAttackWeight = other:getAttackWeight(other.attackType)

    if myAttackWeight == opponentAttackWeight then
        -- Both attacks are of equal weight, both fighters are knocked back
        self:applyKnockback(other)
        other:applyKnockback(self)
        self.isClashing = true
        other.isClashing = true
        self.clashTime = love.timer.getTime()
        other.clashTime = self.clashTime
        self.lostClash = false
        other.lostClash = false
    else
        -- Determine winner and loser
        local winner, loser
        if myAttackWeight > opponentAttackWeight or other.stamina == 0 then
            winner = self
            loser = other
        else
            winner = other
            loser = self
        end

        -- Apply knockback and damage
        loser.pendingDamage = winner.attacks[loser.attackType].damage / 2
        loser.knockbackApplied = true
        loser:applyKnockback(winner)

        winner.isClashing = true
        loser.isClashing = true
        winner.clashTime = love.timer.getTime()
        loser.clashTime = winner.clashTime

        winner.lostClash = false
        loser.lostClash = true
    end
end

function Fighter:handleKnockback(dt)
    local windowWidth = love.graphics.getWidth()

    -- Handle knockback delay
    if self.knockbackDelayTimer > 0 then
        self.knockbackDelayTimer = self.knockbackDelayTimer - dt
        if self.knockbackDelayTimer <= 0 then
            self.knockbackActive = true -- Activate knockback after delay
        end
        return
    end

    -- Handle active knockback
    if self.knockbackActive and self.state ~= ANIM_STATE_RUN then
        local distanceToTarget = math.abs(self.x - self.knockbackTargetX)

        -- Stop knockback when close to the target position or out of bounds
        if distanceToTarget < 1 or self.x <= 0 or (self.x + self.width) >= windowWidth then
            self.knockbackActive = false
            self.isClashing = false

            -- Apply pending damage, if any
            if self.pendingDamage and self.knockbackApplied then
                self:takeDamage(self.pendingDamage)
                self.pendingDamage = nil
                self.knockbackApplied = false
            end
            return
        end

        -- Move towards the knockback target
        self:startKnockback(dt)
    end
end

function Fighter:handleGrab(dt, other)
    if self.state ~= ANIM_STATE_GRAB then
        return -- Exit if not in grab state
    end

    local currentTime = love.timer.getTime()

    -- Step 1: Position the opponent
    if not self.isGrabPositioned then
        -- Both fighters face the grabDirection
        self.direction = self.grabDirection
        other.direction = self.grabDirection == DIRECTION_LEFT and DIRECTION_RIGHT or DIRECTION_LEFT

        -- Recalculate opponent's position based on grabDirection
        if self.grabDirection == DIRECTION_RIGHT then
            other.x = self.x + self.width + 10 -- Position slightly to the right
        else
            other.x = self.x - other.width - 10 -- Position slightly to the left
        end

        self.isGrabPositioned = true
        return -- Wait for the next frame to stun
    end

    -- Step 2: Stun the opponent
    if not self.grabStartTime then
        other:startStun()
        self.grabStartTime = currentTime -- Start grab timer
        return -- Wait for the next frame
    end

    -- Step 3: Handle throw after the delay
    local elapsedTime = currentTime - self.grabStartTime
    local throwDelay = 1.5
    local grabTotalTime = 2.5

    if elapsedTime >= throwDelay and not self.grabHasThrown then
        self.grabHasThrown = true

        -- Calculate throw direction based on grabDirection
        local throwDirection = self.grabDirection
        other:startRun(throwDirection, dt, self) -- Initiate the throw using startRun

        -- Apply vertical velocity for the throw
        other.dy = -500 -- Adjust upward force as needed
        other.isAirborne = true
        other.isGrounded = false
    end

    -- Step 4: Reset grab state after the grab duration
    if elapsedTime >= grabTotalTime then
        self.grabStartTime = nil
        self.grabHasThrown = false
        self.isGrabPositioned = false -- Reset positioning flag
        self:setAnimState(ANIM_STATE_IDLE) -- Reset to idle state
    end
end

function Fighter:startRun(direction, dt, other)
    local isNotColliding = not self:checkXCollision(self.x, self.y, other);
    if isNotColliding then
        self.direction = direction -- Update direction and run
        self:setAnimState(ANIM_STATE_RUN)
    end
end

function Fighter:startKnockback(dt)
    local knockbackStep = FIGHTER_KNOCKBACK_SPEED * dt * self.direction * -1 -- Move in the opposite direction
    local newX = self.x + knockbackStep

    -- Clamp position within screen bounds
    local windowWidth = love.graphics.getWidth()
    self.x = math.max(0, math.min(newX, windowWidth - self.width))
end

function Fighter:startDash(direction)
    -- Ensure stamina and cooldown requirements are met
    if self.stamina < self.dashStaminaCost then
        return;
    end

    local currentTime = love.timer.getTime()
    
    self.direction = direction
    self.dashEndTime = currentTime + self.dashDuration
    self.stamina = self.stamina - self.dashStaminaCost

    self:setAnimState(ANIM_STATE_DASHING)
    SoundManager:playSound(self.sounds.dash, {clone = true})
end

function Fighter:startRecovery() 
    local currentTime = love.timer.getTime()
    self.recoveryEndTime = currentTime + self.attacks[self.lastAttackType].recovery
    self.isRecovering = true
end

function Fighter:startStun(stunnedTimer)
    if self.state == ANIM_STATE_STUNNED then
        return -- Exit early if already stunned
    end

    -- Set stunned state and timer
    self.stunnedTimer = stunnedTimer or FIGHTER_STUNNED_DURATION

    -- Set stunned animation and play sound
    self:setAnimState(ANIM_STATE_STUNNED)
    SoundManager:playSound(self.sounds.hit)
end

function Fighter:startGrab(other)
    local isHit = self.state == ANIM_STATE_HIT
    local isStunned = self.state == ANIM_STATE_STUNNED
    local isGrabbing = self.state == ANIM_STATE_GRAB
    if isGrabbing or isStunned or isHit or self.isAttacking then
        return -- Cannot grab
    end

    local dx = other.x - self.x
    local dy = other.y - self.y
    local distance = math.sqrt(dx^2 + dy^2)

    -- Ensure the opponent is within grab range and in front of the fighter
    if distance > FIGHTER_GRAB_RANGE or (self.direction == DIRECTION_RIGHT and dx < 0) or (self.direction == DIRECTION_LEFT and dx > 0) then
        return -- Exit if the opponent is out of range or behind the fighter
    end

    self.isGrabPositioned = false

    -- Set the grab state and play grab sound
    self:setAnimState(ANIM_STATE_GRAB)
    SoundManager:playSound(self.sounds.hit)
end


function Fighter:startJump()
    self.dy = self.jumpStrength
    self.isAirborne = true
    self.isGrounded = false

    self:setAnimState(ANIM_STATE_JUMP)
    SoundManager:playSound(self.sounds.jump)
end

function Fighter:startAttack(attackType)
    if self.state == ANIM_STATE_HIT or self.isAttackActive or self.isAttacking or self.isRecovering then
        return -- Cannot attack while hit, attacking, or recovering
    end

    -- Stamina cost based on attack type
    local staminaCost = self.attacks[attackType].cost
    if self.stamina < staminaCost then
        return -- Not enough stamina to attack
    end
    self.stamina = self.stamina - staminaCost -- Deduct stamina

    -- Initialize attack state
    self.isAttacking = true
    self.isAttackActive = false
    self.attackType = attackType
    self.lastAttackType = attackType
    self.damageApplied = false -- Reset damage tracking for the attack

    -- Set attack duration and state
    local attackDuration = self.animationDurations[attackType]
    self.attackEndTime = love.timer.getTime() + attackDuration
    self:setAnimState(attackType)

    -- Play attack sound
    SoundManager:playSound(self.sounds[attackType], {clone = true})
end

function Fighter:startInteract()
    -- TODO interactions
end

function Fighter:checkXCollision(newX, newY, other)
    return not (newX + self.width <= other.x or newX >= other.x + other.width or newY + self.height <= other.y or
        newY >= other.y + other.height)
end

function Fighter:checkYCollision(newY, other)
    return not (self.x + self.width <= other.x or self.x >= other.x + other.width or newY + self.height < other.y or
        newY > other.y + other.height)
end

function Fighter:checkHitboxOverlap(hitbox1, hitbox2)
    return hitbox1.x < hitbox2.x + hitbox2.width and hitbox1.x + hitbox1.width > hitbox2.x and
        hitbox1.y < hitbox2.y + hitbox2.height and
        hitbox1.y + hitbox1.height > hitbox2.y
end

function Fighter:getAttackWeight(attackType)
    local weights = {
        light = 1,
        medium = 2,
        heavy = 3
    }
    return weights[attackType] or 0
end

function Fighter:getAttackHitbox()
    if not self.attackType or not self.hitboxes[self.attackType] then
        return nil
    end

    local hitbox = self.hitboxes[self.attackType]
    local hitboxX = self.direction == 1 
        and (self.x + self.width + (hitbox.ox or 0)) 
        or (self.x - hitbox.width + (hitbox.ox or 0))

    -- Ensure the hitbox remains within the screen bounds
    return {
        x = math.max(0, hitboxX),
        y = self.y + (self.height - hitbox.height) / 2 + (hitbox.oy or 0),
        width = hitbox.width,
        height = hitbox.height
    }
end

function Fighter:getHitbox()
    return {
        x = self.x,
        y = self.y,
        width = self.width,
        height = self.height
    }
end

function Fighter:takeDamage(damage)
    self.health = self.health - damage

    -- Check if the fighter is dead
    if self.health <= 0 then
        self.health = 0 -- Clamp health to 0

        -- Handle death state
        if self.state ~= ANIM_STATE_DEATH then
            self:setAnimState(ANIM_STATE_DEATH)

            -- Play death animation and sound
            if self.animations.death then
                self.currentAnimation = self.animations.death
                self.currentAnimation:gotoFrame(1)
            end
            SoundManager:playSound(self.sounds.death)

            -- Mark the start of the death animation
            self.deathAnimationStartTime = love.timer.getTime()
        end
        return -- Exit after handling death
    end

    self.isBlockingDamage = false -- Reset blocking flag
    self:setAnimState(ANIM_STATE_HIT)

    -- Play hit animation and sound
    if self.animations.hit then
        self.currentAnimation = self.animations.hit
        self.currentAnimation:gotoFrame(1)
    end
    SoundManager:playSound(self.sounds.hit)

    -- Set the duration for the hit animation
    if self.currentAnimation and self.currentAnimation.totalDuration then
        self.hitEndTime = love.timer.getTime() + self.currentAnimation.totalDuration
    end
end

function Fighter:applyKnockback(other)
    local baseKnockbackDelay = FIGHTER_KNOCKBACK_DELAY
    local attackType = self.attackType or ATTACK_TYPE_LIGHT

    -- Adjust knockback delay based on the attack type
    if attackType == ATTACK_TYPE_MEDIUM then
        baseKnockbackDelay = baseKnockbackDelay + 0.2
    elseif attackType == ATTACK_TYPE_HEAVY then
        baseKnockbackDelay = baseKnockbackDelay + 0.4
    end

    self.knockbackTargetX = self.x + (self.direction * -100) -- Set the target position for knockback
    self.knockbackActive = false -- Knockback will be active after delay
    self.knockbackDelayTimer = baseKnockbackDelay -- Set the delay timer
    self.lostClash = false -- Reset lost clash flag

    if not self.knockbackApplied and not other.knockbackApplied then
        SoundManager:playSound(self.sounds.clash, {preventOverlap = true})
    end       
end

function Fighter:noKeysPressed()
    -- this is dumb but works for now
    return not (love.keyboard.isDown(self.controls.left) or
                love.keyboard.isDown(self.controls.right) or
                love.keyboard.isDown(self.controls.jump) or
                love.keyboard.isDown(self.controls.light) or
                love.keyboard.isDown(self.controls.medium) or
                love.keyboard.isDown(self.controls.heavy) or
                love.keyboard.isDown(self.controls.grab) or
                love.keyboard.isDown(self.controls.interact))
end

function Fighter:setGrabDirection() 
    local isGrabbing = self.state == ANIM_STATE_GRAB
    if not isGrabbing then
        return -- not grabbing
    end

    if love.keyboard.isDown(self.controls.left) then
        self.grabDirection = DIRECTION_LEFT
    elseif love.keyboard.isDown(self.controls.right) then
        self.grabDirection = DIRECTION_RIGHT
    else
        self.grabDirection = self.direction -- Default to facing direction
    end
end

--[[
    Animation State
--]]

function Fighter:setAnimState(newState)
    -- Only change state if the new state is different from the current state
    if self.state == newState then
        return
    end

    -- Get caller info
    if _G.isDebug then 
        local callerInfo = debug.getinfo(2, "n") -- Level 2 is the function that called this one
        local callerName = callerInfo and callerInfo.name or "unknown"
        print('=> Fighter' .. self.id .. ':setAnimState called by:')
        print('Caller:', callerName, 'State:', self.state, '->', newState)
    end

    self.state = newState

    -- Determine the appropriate animation for the new state
    -- Default to idle if no animation is found
    local newAnimation = self.animations[newState] or self.animations.idle
    self.currentAnimation = newAnimation
    self.currentAnimation:gotoFrame(1)
end

function Fighter:updateDeathAnimation()
    if self.state == ANIM_STATE_DEATH then
        local currentTime = love.timer.getTime()
        local elapsedTime = currentTime - self.deathAnimationStartTime
        local deathDuration = self.animationDurations[ANIM_STATE_DEATH]

        if elapsedTime >= deathDuration then
            self.deathAnimationFinished = true
            self.currentAnimation:pauseAtEnd() -- Pause the animation at the last frame
        end
    end
end

--[[
    Rendering
--]]

function Fighter:render(other)
    self:drawSprite()
    if _G.isDebug then
        self:drawHitboxes(other)
    end
end

function Fighter:drawSprite()
    local spriteName = self.state == ANIM_STATE_ATTACKING and self.lastAttackType or self.state
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

        if self.isBlockingDamage then
            love.graphics.setColor(0, .1, .7, 1) -- Blue color for the outline
        end

        -- Flash white if stunned
        if self.state == ANIM_STATE_STUNNED then
            -- Alternate between full white and normal color for flashing effect
            local time = love.timer.getTime()
            local alpha = math.abs(math.sin(time * 10)) -- Oscillates between 0 and 1
            love.graphics.setColor(1, 1, 1, alpha) -- White with pulsing opacity
        end

        -- Draw the current animation
        self.currentAnimation:draw(sprite, posX, posY, angle, scaleX, scaleY)

        -- Reset color to default after drawing
        love.graphics.setColor(1, 1, 1, 1)
    elseif _G.isDebug then
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
end

return Fighter
