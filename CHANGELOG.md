# Mechanics
- Updates to player physics interactions to make them more consistent
- Casting no longer increases knockback from hamful walls
- Increased knockback from hamful walls
- Updates to sudden death and level gen
- Increased player size and jump height
- Melee hitbox scales with velocity
- Kick bounce directions is affected by camera direction
- Updates to rooms and generation
- Rebind magic casting to Q and E, melee is F or V
- Default box health changed from 50 to 40
- Added armor, giving %dr while active and regens over time
- Increased default bullet knockback 0 -> 20
- Added `fullscreen` command
- Melee does damage to levelbodies
- Added explosions
- Bullets bounce off players, and hit effects are split between bounces
- Spells can be chain cast
- Indirect kills count as player kills
- Many small fixes and qol changes that didnt make the list (yet)
- Only 2 gun cards offered at start of game
- Increased default bullet size
- Mines now have a startup (1.0s) and dont explode instantly (0.25s)

## Cards
- Balance changes, spelling fixes
- 4 new starting guns: Cannon, Flamethrower, Plasma Beam, Peashooter
- Many cards added and removed
- Card uuids are now the same as the abbv. Removed card abbv

## Graphics & Enviroment
- Light orbs move slightly faster
- Added fullscreen button to lobbies
- Increased particle sizes
- Many new rooms, including half size rooms
- Spell selection menu now displays which cards each spell has, as well as current card
- Added sound. More sounds to come
- Added player trackers


## Bug Fixes
- Fix bounds visualizers getting removed twice
- Fixed some levelbodies not syncing correctly
- Particle instancing no longer causes frame stuttering
- Fields were affecting bodies when they shouldnt have been
