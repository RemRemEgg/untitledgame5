# Changes
### Mechanics
- Rework magic
- Added sudden death
- Added spawn invulnerability
- Wallkicking now restores jumps, larger hitbox
- Updated level gen
- Swapped magic and melee keybinds
- Decreased magic cooldown
- Increased melee hitbox size
- Increase ceiling height
- Heal 50% missing hp on kill
- Added temp stat modifiers (not complete)
- Info screen shows stats for local player
- Add debug button
- Increased spawn radius
- Can kick physics objects now
- Wall and player kicks give up to 10% extra speed

### Cards
- Flattened rarity cure slightly
- Card balance changes
- Added alignment cards
- Added card Masochist
- Added card Slick Trick
- Added card Snare
- Rebalanced magic tree, add study card
- Increased strength of shockwave vs objects

### Graphics & Enviroment
- Updated player materials
- New level textures
- New magic texture
- Player color names now appear in chat
- Decrease player outline opacity
- Add hurt effect
- Started visual effects
- Decrease FOV


# Bug Fixes
- Player model no longer has flipped faces
- Kick animation reaches higher when jumping
- Turtle stacks
- Cuber stacks
- Healthbars sync max health
- Projectile trails disappear after bullet does
- Snare no longer fails to find player if there are too many physics objects nearby
- Sudden death no longer happens during initial card draw


# Known Bugs
- Formatting issues with cards
- Cards can be chosen face-down
- Card quantities get desynced
- Hitting bounds while casting does not apply knockback
- Input processing issues with debug keybinds in menus
- Card hovers appear while picking cards
- Bullets dont fire from gun (visual)
- Card hitboxing is sometimes completely incorrect
- Bullet trails dont sync the last position they went to (temp fix added)
- Spectators still have collision


# TODO List
- Lifesteal
- Effect visuals

- Condensed descriptions (ie +jump +speed +accel => +agility)
- Rework level gen
- Projectile visuals
- Netcode updates
- Card sync
- DamageEvent seralized
- More magic cards / abilities
- Non-bullet projectiles for cards
- "Finalize" and update card register function + docs
- Transfer preloads into loads
- Thread startup?
- Latejoin / leaving during game
- Player animation states
- Updated player model
- AFK FPS reducer
- Hurt visuals
- Temporary stat modifiers
- Make sacrifice work
- Add meta cards
