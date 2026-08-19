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
	_MAX_COUNT }


static func load_all_fields() -> void:
	fields.resize(_MAX_COUNT)
	for i in _MAX_COUNT:
		@warning_ignore_start("unused_parameter")
		match i:
			REVERSE_GRAV:
				var fdata := load_field(&"reverse_grav", i)
				fdata.effect_world = true
				fdata.shape = SphereShape3D.new()
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.REBECCA_PURPLE, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					if body is Player:
						(body as Player).velocity.y += 64.0 * delta * field.strength
					if body is LevelBody:
						(body as LevelBody).apply_central_force(Vector3.UP * 64.0)
			
			SHRINK:
				var fdata := load_field(&"shrink", i)
				fdata.effect_world = true
				fdata.shape = SphereShape3D.new()
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.GREEN_YELLOW, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					body.scale *= (1.0 - 0.03*field.strength) ** delta
			
			GROW:
				var fdata := load_field(&"shrink", i)
				fdata.effect_world = true
				fdata.shape = SphereShape3D.new()
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.DARK_GREEN, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					body.scale *= (1.0 + 0.025*field.strength) ** delta
			
			IMPLODE:
				var fdata := load_field(&"implode", i)
				fdata.effect_world = true
				fdata.shape = SphereShape3D.new()
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.DARK_GRAY, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
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
				fdata.shape = SphereShape3D.new()
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.NAVAJO_WHITE, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					if body is Player:
						(body as Player).velocity *= (1.0 + 1.5*field.strength) ** delta
			
			MINE:
				var fdata := load_field(&"mine", i)
				fdata.shape = SphereShape3D.new()
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_MINE, field.global_position, [field.radius, field.time])
					field.visuals.append(vfx)
				fdata.effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					if body is Player && randf() <= 0.15:
						if Game.world.has_line(field.global_position, body.global_position):
							var rt := field.strength ** 0.5
							Game.world.create_explosion(field.global_position, field.radius, 24.0*rt, 32.0*rt)
							field.time = -100.0
			
			HEAL:
				var fdata := load_field(&"heal", i)
				fdata.shape = SphereShape3D.new()
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.PALE_VIOLET_RED, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					if body is Player:
						var p := body as Player
						p.health = minf(p.health + delta * field.strength * 4.0, p.max_health.value)
			
			SPIN:
				var fdata := load_field(&"spin", i)
				fdata.shape = SphereShape3D.new()
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.YELLOW, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.effect_world = true
				fdata.effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					body.global_position += body.global_transform.looking_at(field.global_position-body.global_position) * Vector3.LEFT * delta * field.strength * 0.015
			
			WIND:
				var fdata := load_field(&"wind", i)
				fdata.effect_world = true
				fdata.shape = SphereShape3D.new()
				fdata.spawn_effect = func spawn(field:Field) -> void:
					var vfx := VFXHandler.spawn_local(VFXHandler.AREA_SPHERE, field.global_position, [Color.CORNFLOWER_BLUE, field.radius, field.time])
					field.visuals.append(vfx)
				fdata.effect = func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:
					if body is Player:
						(body as Player).velocity += delta * field.strength * -field.global_basis.z
					if body is LevelBody:
						(body as LevelBody).apply_central_force(field.strength * -field.global_basis.z * 16.0)
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
	## [codeblock]func effect(field:Field, body:PhysicsBody3D, delta:float) -> void:[/codeblock]
	var effect: Callable
	var effect_players: bool = true
	var effect_world: bool = true
	
	
	func instantiate() -> Field:
		var f := Field.new()
		
		var coll := CollisionShape3D.new()
		coll.shape = shape
		f.add_child(coll)
		f.time = 1.0
		f.effect = effect
		f.collision_mask = (0b0010_0010 * int(effect_players)) | (0b0001_0001 * int(effect_world))
		
		return f
