# TFG

A tiny Love2D fighting game.

![alt text](.github/image_menu.png)

https://github.com/user-attachments/assets/eaa92371-602d-4eb4-b9a7-538af5209b7b

#### Controls

- Fighter 1: `WASD ERT FG`
- Fighter 2: `UHJK IOP L;`

#### Controller Support?

Sure, https://www.rewasd.com/

Keymaps in `keymap.lua`

#### Multiplayer?

Sure, https://moonlight-stream.org/

## Run

```sh
love src
```

to generate FFT data

```sh
python fft/fft.py
```

> PS: Don't ask about the FFT code. It's dubious.

## Acknowledgements

I do **not** own any of the assets used in this game, they were acquired on free licenses or paid for non-profit usage.

## TODO

- [ ] Win Loss counters? Rounds?
- [ ] Fix sound duplication and cleanup sound manager
- [ ] Clashing is still buggy (flashing and knockback)
- [ ] Improve game over screen, maybe keep track of P1 vs P2 wins?
- [ ] Add more 300x800 backgrounds
- [ ] Uses for the interact action
  - Rock entity
  - Emote  
- [ ] Finish basic AI to be fun to play against
- [ ] Fix sprite scaling in character select
- [ ] Countdown to fight (maybe not explicit) and fighter enter anims?
- [ ] Keymappings get reset on game over bug
