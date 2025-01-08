return {
    name = 'Samurai3',
    scale = {x = 1.7, y = 2, ox = 17, oy = -5, width = 40, height = 80},
    traits = {health = 100, speed = 190, stamina = 100, dashSpeed = 550, jumpStrength = 650},
    hitboxes = {
        light = {ox = 0, oy = 0, width = 60, height = 110, recovery = 0.1},
        medium = {ox = 0, oy = 0, width = 35, height = 100, recovery = 0.3},
        heavy = {ox = 0, oy = 0, width = 40, height = 60, recovery = 0.5}
    },
    attacks = {
        light = {start = 1, active = 3, damage = 5, recovery = 0.2},
        medium = {start = 1, active = 3, damage = 8, recovery = 0.4},
        heavy = {start = 1, active = 3, damage = 18, recovery = 0.8}
    },
    spriteConfig = {
        idle = {
            path = 'assets/fighters/Samurai3/Idle.png',
            frames = 5,
            frameDuration = {0.1, 0.1, 0.1, 0.1, 0.1}
        },
        run = {
            path = 'assets/fighters/Samurai3/Run.png',
            frames = 7,
            frameDuration = {0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1}
        },
        jump = {
            path = 'assets/fighters/Samurai3/Jump.png',
            frames = 3,
            frameDuration = {0.1, 0.1, 0.1}
        },
        light = {
            path = 'assets/fighters/Samurai3/Attack1.png',
            frames = 5,
            frameDuration = {0.1, 0.1, 0.1, 0.1, 0.1}
        },
        medium = {
            path = 'assets/fighters/Samurai3/Attack2.png',
            frames = 5,
            frameDuration = {0.1, 0.1, 0.1, 0.1, 0.1}
        },
        heavy = {
            path = 'assets/fighters/Samurai3/Attack3.png',
            frames = 10,
            frameDuration = {0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1}
        },
        hit = {
            path = 'assets/fighters/Samurai3/Hit.png',
            frames = 3,
            frameDuration = {0.1, 0.1, 0.1}
        },
        death = {
            path = 'assets/fighters/Samurai3/Death.png',
            frames = 10,
            frameDuration = {0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1}
        }
    },
    soundFXConfig = {
        light = 'assets/fighters/Samurai3/Attack1.wav',
        medium = 'assets/fighters/Samurai3/Attack1.wav',
        heavy = 'assets/fighters/Samurai3/Attack1.wav',
        hit = 'assets/fighters/Samurai3/Hit.mp3',
        block = 'assets/fighters/Samurai3/Block.wav',
        jump = 'assets/fighters/Samurai3/Jump.mp3',
        dash = 'assets/fighters/Samurai3/Dash.mp3',
        death = 'assets/fighters/Samurai3/Death.mp3'
    }
}
