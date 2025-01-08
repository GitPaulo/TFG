return {
    name = 'Samurai2',
    scale = {x = 1.35, y = 1.3, ox = -4, oy = -2, width = 35, height = 80},
    traits = {health = 100, speed = 185, stamina = 100, staminaRecoveryRate = 50, dashSpeed = 515, jumpStrength = 600},
    hitboxes = {
        light = {ox = 0, oy = 0, width = 90, height = 100},
        medium = {ox = 0, oy = 0, width = 90, height = 130},
        heavy = {ox = 0, oy = 0, width = 90, height = 130}
    },
    attacks = {
        light = {start = 1, active = 3, damage = 5, recovery = 0.2},
        medium = {start = 1, active = 3, damage = 8, recovery = 0.4},
        heavy = {start = 1, active = 3, damage = 18, recovery = 0.8}
    },
    spriteConfig = {
        idle = {
            path = 'assets/fighters/Samurai2/Idle.png',
            frames = 4,
            frameDuration = {0.1, 0.1, 0.1, 0.1}
        },
        run = {
            path = 'assets/fighters/Samurai2/Run.png',
            frames = 8,
            frameDuration = {0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1}
        },
        jump = {
            path = 'assets/fighters/Samurai2/Jump.png',
            frames = 2,
            frameDuration = {0.1, 0.1}
        },
        light = {
            path = 'assets/fighters/Samurai2/Attack1.png',
            frames = 4,
            frameDuration = {0.1, 0.1, 0.1, 0.1}
        },
        medium = {
            path = 'assets/fighters/Samurai2/Attack2.png',
            frames = 4,
            frameDuration = {0.1, 0.1, 0.1, 0.1}
        },
        heavy = {
            path = 'assets/fighters/Samurai2/Attack2.png',
            frames = 4,
            frameDuration = {0.1, 0.1, 0.1, 0.1}
        },
        hit = {
            path = 'assets/fighters/Samurai2/TakeHit.png',
            frames = 3,
            frameDuration = {0.1, 0.1, 0.1}
        },
        death = {
            path = 'assets/fighters/Samurai2/Death.png',
            frames = 7,
            frameDuration = {0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1}
        }
    },
    soundFXConfig = {
        light = 'assets/fighters/Samurai2/Attack1.wav',
        medium = 'assets/fighters/Samurai2/Attack1.wav',
        heavy = 'assets/fighters/Samurai2/Attack1.wav',
        hit = 'assets/fighters/Samurai2/Hit.mp3',
        block = 'assets/fighters/Samurai2/Block.wav',
        jump = 'assets/fighters/Samurai2/Jump.mp3',
        dash = 'assets/fighters/Samurai2/Dash.mp3',
        death = 'assets/fighters/Samurai2/Death.mp3'
    }
}
