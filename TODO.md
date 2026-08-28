## Engine
- Thread startup?
- Transfer preloads into loads
- Latejoin / leaving during game
- Add card reload command
- Console command updates
- [Explosions dont hurt levelbodies]
- [LOS checks for AOE]
- [Fields (like mines) dont sync state (maybe fixed)]
- [FUCKING DUCKS????? seems to be projectile bounce sound]
- Netcode updates
- DOT fields
- Level gen update, wait till rooms updated
- [Damage hooks can cause certain cards to break with pellets (ie scavenger)]
- Make sacrifice work


## Players
- >Temporary stat modifiers : attribute system
- [Too much speed prevents melee from blocking border damage]
- [Incorrect damage sources]
- Slide needs to be better at slower speeds, maybe strong rework
- [Players can be hit through walls by aoe (no los check)]
- Hurt visuals


## Guns & Projectiles
- [Bullet trails dont sync the last position they went to (temp fix added)]
- [Bullets dont fire from gun (visual)]
- [Projectiles clip through walls, sometimes]
- custom collision api? would speed up raycast
- pserver rids over refs? see psqp, also perf boost
- [OCFM breacks scav]


## Spells & Magic
- Heal to DOT
- More self harm/masochist spells
- >Held spells
- **spells need more visuals**
- split potency into strength, duration, size
- Utrakill coin "field" (lvlb)
- mine spell should track players


## Cards
- make rarer cards visually more unique, custom flip anims?
- change draw once into max draws
- Remove card spider graphs
- Card purge
- Condensed descriptions (ie +jump +speed +accel : +agility)
- "Finalize" and update card register function + docs

### Card Ideas
- dash based cards, need to add dash hook
- slide cards
- damage resistance cards? all mutex
- reduced kb taken card
- low health : more damage
- low health : more move speed
- longer without touching floor : more damage

### Balance Changes
- Mines nerf, maybe all explosive cards
- 12GS too much kb?
- nerf bcb (fix temp stats)
- late game magic cards are severly undertested/used


## Enviroment & Graphics
- Player animation & model rework
- Effect visuals
- Projectile visuals
- levelbodies scale health by round


## UI/UX
- Make health easier to indirectly read
- [Card hitboxing is sometimes completely incorrect (cant reproduce)]
- [Card hovers appear while picking cards]
- [Cards can be chosen face-down]
- [Formatting issues with certain cards]
- [Card quantities get desynced (appears fixed, need more testing)]
- [Input processing issues with debug keybinds in menus]
- Update spell charge visuals
- Enter to join game
- Card stat preview
- AFK FPS reducer
