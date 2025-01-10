local love = _G.love
local AIController = {}

function AIController:new(fighter, opponent)
    local ai = {}
    setmetatable(ai, self)
    self.__index = self
    ai.fighter = fighter
    ai.opponent = opponent
    ai.jumpCooldown = 0
    ai.attackCooldown = 0.5
    return ai
end

function AIController:update(dt)
    local fighter = self.fighter
    local opponent = self.opponent

    -- Update cooldowns
    if self.jumpCooldown > 0 then
        self.jumpCooldown = self.jumpCooldown - dt
    end

    if self.attackCooldown > 0 then
        self.attackCooldown = self.attackCooldown - dt
    end

    -- Determine AI actions based on distance
    local distance = math.abs(fighter.x - opponent.x)

    if fighter.state == ANIM_STATE_IDLE or fighter.state == ANIM_STATE_RUN then
        if distance < 100 and self.attackCooldown <= 0 then
            self:attack()
        elseif distance < 200 and self.jumpCooldown <= 0 then
            -- self:jump() TODO
        elseif distance >= 50 then
            self:moveTowardsOpponent(dt)
        else
            fighter:setAnimState(ANIM_STATE_IDLE)
        end
    end

    -- Turn to face the opponent
    if fighter.x < opponent.x then
        fighter.direction = DIRECTION_RIGHT
    else
        fighter.direction = DIRECTION_LEFT
    end
end

function AIController:moveTowardsOpponent(dt)
    local fighter = self.fighter
    local opponent = self.opponent

    if fighter.x < opponent.x then
        fighter:startRun(DIRECTION_RIGHT, dt, opponent)
    else
        fighter:startRun(DIRECTION_LEFT, dt, opponent)
    end
end

function AIController:jump()
    local fighter = self.fighter
    if not fighter.isAirborne and fighter.state ~= ANIM_STATE_JUMP then
        fighter:startJump()
        self.jumpCooldown = 1.0 -- 1-second cooldown for jumping
    end
end

function AIController:attack()
    local fighter = self.fighter
    if not fighter.isAttacking and fighter.state ~= ANIM_STATE_HIT then
        fighter:startAttack(ATTACK_TYPE_LIGHT)
        self.attackCooldown = 0.5 -- 0.5-second cooldown for attacking
    end
end

return AIController
