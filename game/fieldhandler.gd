class_name FieldHandler

static var fields: Array[FieldData]
enum {
	REVERSE_GRAV,
	SHRINK,
	GROW,
	IMPLODE,
	MINE,
	ACCELERATE,
	HEAL,
	SPIN,
	WIND,
	ELECTRICITY,
	_MAX_COUNT }


static func load_all_fields() -> void:
	var SPHERE := SphereShape3D.new()
	SPHERE.radius = 1.0
	
	fields.resize(_MAX_COUNT)
	for i in _MAX_COUNT:
		@warning_ignore_start("unused_parameter")
		match i:
			REVERSE_GRAV:
				var fdata := load_field(&"reverse_grav", i)
				fdata.effect_world = true
				fdata.shape = SPHERE
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.REBECCA_PURPLE, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.body_effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					if body is Player:
						(body as Player).velocity.y += 64.0 * delta * field.strength
					if body is LevelBody:
						(body as LevelBody).apply_central_force(Vector3.UP * 64.0)
			
			SHRINK:
				var fdata := load_field(&"shrink", i)
				fdata.effect_world = true
				fdata.shape = SPHERE
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.GREEN_YELLOW, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.body_effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					body.scale *= (1.0 - 0.03*field.strength) ** delta
			
			GROW:
				var fdata := load_field(&"shrink", i)
				fdata.effect_world = true
				fdata.shape = SPHERE
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.DARK_GREEN, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.body_effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					body.scale *= (1.0 + 0.025*field.strength) ** delta
			
			IMPLODE:
				var fdata := load_field(&"implode", i)
				fdata.effect_world = true
				fdata.shape = SPHERE
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.DARK_GRAY, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.body_effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					var dir := body.global_position - field.global_position
					var l := dir.length()
					dir = (dir / l) * (1.0 - (l / field.radius))
					dir *= field.strength
					
					if body is Player:
						(body as Player).velocity += dir * -48 * delta
					if body is LevelBody:
						body.apply_central_force(dir * 25600.0)
			
			ACCELERATE:
				var fdata := load_field(&"accelerate", i)
				fdata.shape = SPHERE
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.NAVAJO_WHITE, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.body_effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					if body is Player:
						(body as Player).velocity *= (1.0 + 1.5*field.strength) ** delta
			
			MINE:
				const TRIGGER_DELAY := 0.25
				var fdata := load_field(&"mine", i)
				fdata.shape = SPHERE
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_MINE, field.global_position, [field.radius, field.time])
					field.visuals.append(vfx)
					var pre_scale := field.scale
					field.scale = Vector3.ONE * 0.05
					field.create_tween().tween_property(field, ^"scale", pre_scale, 1.0)
				
				fdata.idle_effect = func idle(field:Field, delta:float) -> void:
					if field.time > TRIGGER_DELAY:
						for visual in field.visuals:
							visual.rotate_y(delta * 0.1)
							visual.scale = field.scale
					else:
						for visual in field.visuals:
							visual.rotate_y(-delta*5.0)
							visual.scale = field.scale
				
				fdata.body_effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					if field.time <= TRIGGER_DELAY: return
					if body is Player:
						if Game.world.has_line(field.global_position, body.global_position):
							field.sync_time.rpc(TRIGGER_DELAY)
				
				fdata.end_effect = func end(field:Field) -> void:
					var rt := field.strength ** 0.5
					Game.world.create_explosion(field.global_position, field.radius, 24.0*rt, 32.0*rt)
			
			HEAL:
				var fdata := load_field(&"heal", i)
				fdata.shape = SPHERE
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.PALE_VIOLET_RED, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.body_effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					if body is Player:
						var p := body as Player
						p.health = minf(p.health + delta * field.strength * 4.0, p.max_health.value)
			
			SPIN:
				var fdata := load_field(&"spin", i)
				fdata.shape = SPHERE
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.YELLOW, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.effect_world = true
				fdata.body_effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					body.global_position += body.global_transform.looking_at(field.global_position-body.global_position) * Vector3.LEFT * delta * field.strength * 0.015
			
			WIND:
				var fdata := load_field(&"wind", i)
				fdata.effect_world = true
				fdata.shape = SPHERE
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.CORNFLOWER_BLUE, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.body_effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					if body is Player:
						(body as Player).velocity += delta * field.strength * -field.global_basis.z
					if body is LevelBody:
						(body as LevelBody).apply_central_force(field.strength * -field.global_basis.z * 16.0)
			
			ELECTRICITY:
				var fdata := load_field(&"electricity", i)
				fdata.shape = SPHERE
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.CORNFLOWER_BLUE, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.body_effect = dot_effect
		@warning_ignore_restore("unused_parameter")


static func load_field(proj_id: StringName, i: int) -> FieldData:
	Console.print(&"Loading field '%s'" % proj_id)
	fields[i] = FieldData.new()
	return fields[i]


static func spawn(field_id: int, trans: Transform3D, scale: float, duration: float, strength: float) -> void:
	Network.field_sync.rpc(field_id, trans, scale, duration, strength)


static func spawn_local(field_id: int, trans: Transform3D, scale: float, duration: float, strength: float) -> void:
	var field := fields[field_id].instantiate()
	field.id = field_id
	field.transform = trans
	field.time = duration
	field.scale *= scale
	field.radius *= scale
	field.strength = strength
	Game.world.projectiles.add_child(field)
	fields[field_id].spawn_effect.call(field)


class FieldData:
	var shape: Shape3D
	## [codeblock]func spawn(field:Field) -> void:[/codeblock]
	var spawn_effect: Callable
	## [codeblock]func idle(field:Field, delta:float) -> void:[/codeblock]
	var idle_effect: Callable
	## [codeblock]func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:[/codeblock]
	var body_effect: Callable
	## [codeblock]func end(field:Field) -> void:[/codeblock]
	var end_effect: Callable
	var effect_players: bool = true
	var effect_world: bool = false
	
	
	func instantiate() -> Field:
		var f := Field.new()
		
		var coll := CollisionShape3D.new()
		coll.shape = shape
		f.add_child(coll)
		f.time = 1.0
		f.data = self
		f.collision_mask = (0b0010_0010 * int(effect_players)) | (0b0001_0001 * int(effect_world))
		
		return f


#region resued field functions
static func dot_effect(field: Field, body: PhysicsBody3D, delta: float) -> void:
	if body == Game.player:
		if Util.accumulate_delta([field.delta_buffer], [delta]):
			var de := DamageEvent.new(field.strength * delta).set_type(DamageEvent.TYPE_MAGIC).set_dot()
			Game.player.take_damage(de)
#endregion
