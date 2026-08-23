# Changes
### Mechanics
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

### Cards
- Balance changes, spelling fixes
- 4 new starting guns: Cannon, Flamethrower, Plasma Beam, Peashooter
- Many cards added and removed
- Card uuids are now the same as the abbv. Removed card abbv

### Graphics & Enviroment
- Light orbs move slightly faster
- Added fullscreen button to lobbies
- Increased particle sizes
- Many new rooms, including half size rooms
- Spell selection menu now displays which cards each spell has, as well as current card
- Added sound. More sounds to come
- Added player trackers


# Bug Fixes
- Fix bounds visualizers getting removed twice
- Fixed some levelbodies not syncing correctly
- Particle instancing no longer causes frame stuttering
- Fields were affecting bodies when they shouldnt have been


# Known Bugs
- Formatting issues with cards
- Cards can be chosen face-down
- Card quantities get desynced (maybe fixed?)
- Input processing issues with debug keybinds in menus
- Card hovers appear while picking cards
- Bullets dont fire from gun (visual)
- Card hitboxing is sometimes completely incorrect (cant reproduce)
- Bullet trails dont sync the last position they went to (temp fix added)
- Spectators still have collision
- Players can be hit through walls
- Explosions dont hurt levelbodies
- FUCKING DUCKS?????


# TODO List
- Slide
- Mines detonate after timer (field death effect) and have startup
- Update spell charge visuals
- Netcode updates
- Player animation & model rework
- Higher shield regen delay
- Enter to join game
- LOS checks for AOE
- Card purge
- Larger base bullet size
- Card stat preview
- Grapple desc fix
- Player trackers need to be more visible
- Snare ping fix
- Incorrect damage sources
- Too much speed prevents melee from blocking border damage
- Spectators need to disable collision
- 12GS too much kb?
- Spell 1 and 2 flipped in stat menu?
- Improve slide
- Projectiles clip through walls
- Levelgeo anim errors vector to infinity
- Remove card spider graphs
- Add card reload command

- Console command updates
- More magic cards / abilities
- Hurt visuals
- Add meta cards
- "Finalize" and update card register function + docs
- Make sacrifice work
- Temporary stat modifiers
- Latejoin / leaving during game

- AFK FPS reducer
- Thread startup?
- Transfer preloads into loads
- Effect visuals
- Projectile visuals
- Condensed descriptions (ie +jump +speed +accel => +agility)
- Give spider charts a real background
