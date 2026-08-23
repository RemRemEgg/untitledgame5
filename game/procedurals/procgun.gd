class_name ProcGun
extends RefCounted


var spider: PackedFloat64Array = [1.0, 1.0, 1.0]
var pproj: ProcProj


func reset_stats() -> void:
	for stat in all_stats:
		stat.reset_value()
	pproj.reset_stats()

func calculate_stats() -> void:
	for stat in all_stats:
		stat.calculate_value()
	pproj.calculate_stats()


## Bullets per Second. Default 12.0
var fire_rate := Stat.new(&"Rate of Fire", 12.0)
## Bullet speed in u/s. Default 300.0
var b_speed := Stat.new(&"Bullet Speed", 300.0)
## Spread in 1/200th rad from true direction. Default 3.5. Max value is 157; approx 45 deg off of center / 90 deg cone.
var inaccuracy := Stat.new(&"Spread", 3.5, 0.0, 157, false)
## Number of bullets fired pre trigger press. Default 1
var pellets := Stat.new(&"Pellets", 1, 1)
## Total clip size. Default 11
var clip_size := Stat.new(&"Clip Size", 11, 1)
## Reload time, in seconds. Default 0.75, min 0.15
var reload_time := Stat.new(&"Reload Time", 0.75, 0.15, 9e9, false)
## All stats
var all_stats: Array[Stat] = [fire_rate, reload_time, inaccuracy, pellets, clip_size, b_speed]

func process(gun: Gun, trans: Transform3D, ownr: Entity, delta: float, can_fire: bool) -> void:
	for stat in all_stats:
		stat.update(delta)
	
	if gun.reload:
		gun.reload -= delta
		if gun.reload <= 0.0:
			gun.reload = 0.0
			gun.clip = clip_size.value_int
			gun.fire_timer = 1.0
		else:return
	
	gun.fire_timer += delta * fire_rate.value
	if !can_fire:
		gun.fire_timer = minf(gun.fire_timer, 1.0)
		return
	
	while gun.fire_timer >= 1.0 && gun.clip > 0:
		var pellets_shot := pellets.value_int
		if ownr is Player:
			var ed := EventHook.EventData.from_player(ownr as Player)
			ed.percent = pellets_shot / clip_size.value
			(ownr as Player).shooting_hook.execute(ed)
		
		gun.clip -= 1
		for __ in pellets_shot:
			fire_one_bullet(trans, ownr, (gun.fire_timer - 1.0) / fire_rate.value, 1.0 / clip_size.value)
		
		gun.fire_timer -= 1.0
		var volume := (pellets_shot/clip_size.value)*4.0 - 2.3
		var pitch := (gun.clip / clip_size.value)
		# hp of current bullets relative to max bullets
		pitch = 1.0 - (pitch / (pitch + 0.2))
		pitch = 1.0 + (pitch) + (volume/8.0)+0.5
		SFXHandler.play_world(SFXHandler.SHOOT, trans.origin, volume, pitch)
	
	if gun.clip <= 0:
		gun.reload = reload_time.value
		gun.fire_timer = 0.0


func fire_one_bullet(trans: Transform3D, ownr: Entity, delta: float, strength: float) -> void:
	var inacc_trans := trans \
		.rotated_local(Vector3.FORWARD, randf_range(0, PI*2.0)) \
		.rotated_local(Vector3.RIGHT, randf() * inaccuracy.value/200.0)
	make_bullet(Vector3(0, 0, -b_speed.value), inacc_trans, ownr, delta, strength)


static var dbg_proj: Dictionary
func make_bullet(vel: Vector3, trans: Transform3D, ownr: Entity, delta: float, strength: float) -> void:
	var proj := Network.send_projectile(trans)
	if !proj:
		Console.print_err(&"Making bullet failed :/")
		return
	
	proj.strength = strength
	proj.ownr = ownr
	proj.velocity = trans.basis * vel
	pproj.update(proj, delta)


func recalc_spider_graph() -> void:
	var augments := Stat.new(&"augments", 1)
	augments.adder += pproj.collide_hook.get_effect_count() + pproj.damage_hook.get_effect_count()
	Util.calculate_spider(spider, [
		[b_speed, pproj.scale, pproj.damage, pproj.knockback], # quality
		[augments, pproj.bounces], # augments
		[fire_rate, inaccuracy, pellets, clip_size, reload_time] # quantity
	])
