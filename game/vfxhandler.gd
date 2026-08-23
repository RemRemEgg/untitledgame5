class_name VFXHandler

static var effects: Array[PackedScene]
enum {
	PARTICLE_GENERIC, ## [scale]
	PARTICLE_BURST, ## [scale]
	AREA_SPHERE, ## <color> <radius> <duration>
	AREA_MINE, ## <radius> <duration>
	BLOCK_BREAK, ## <basis> <size> <amount>
	EXPLOSION, ## <size>
	PLAYER_DEATH, ## <uuid> [scale]
	PLAYER_DUST, ## <uuid> [scale]
	PLAYER_SLIDE, ## <uuid> <velocity>
	SPELL_SHOCKWAVE, ## <scale>
	_MAX_COUNT }


static func load_all_effects() -> void:
	effects.resize(_MAX_COUNT)
	for i in _MAX_COUNT:
		match i:
			PARTICLE_GENERIC: load_effect(&"particle_generic", i)
			PARTICLE_BURST: load_effect(&"particle_burst", i)
			AREA_SPHERE: load_effect(&"shockwave", i)
			AREA_MINE: load_effect(&"mine", i)
			BLOCK_BREAK: load_effect(&"block_break", i)
			EXPLOSION: load_effect(&"explosion", i)
			PLAYER_DEATH: load_effect(&"player_death", i)
			PLAYER_DUST: load_effect(&"particle_burst", i)
			PLAYER_SLIDE: load_effect(&"player_slide", i)
			SPELL_SHOCKWAVE: load_effect(&"shockwave", i)


static func load_effect(effect_id: StringName, i: int) -> void:
	Console.print(&"Loading effect '%s'" % effect_id)
	effects[i] = ResourceLoader.load(&"res://vfx/%s.tscn" % effect_id) as PackedScene


static func quick_setup(effect_id: int, pos: Vector3) -> Node3D:
	var vfx := effects[effect_id].instantiate() as Node3D
	add_vfx_to_world(vfx, pos)
	return vfx


static func add_vfx_to_world(vfx: Node3D, pos: Vector3) -> void:
	Game.world.visuals.add_child(vfx)
	vfx.global_position = pos


static func setup_particle(particle: GPUParticles3D) -> void:
	particle.finished.connect(particle.queue_free)
	particle.emitting = true


## Spawns a vfx for everyone
static func spawn(effect_id: int, pos: Vector3, data: Array = []) -> void:
	Network.vfx_sync.rpc(effect_id, pos, data)


## Spawns a vfx for this player
static func spawn_local(effect_id: int, pos: Vector3, data: Array) -> Node3D:
	var vfx: Node3D = null
	match effect_id:
		
		PARTICLE_GENERIC, PARTICLE_BURST:
			vfx = quick_setup(effect_id, pos) as GPUParticles3D
			setup_particle(vfx)
			if data.size() > 0: vfx.scale *= data[0]
			(vfx.material_override as StandardMaterial3D).albedo_color = Color.from_hsv(randf(), randf()**0.5, 1.0)
			
		
		AREA_SPHERE:
			vfx = quick_setup(effect_id, pos) as MeshInstance3D
			vfx.get_tree().create_timer(data[2]).timeout.connect(vfx.queue_free)
			vfx.scale *= data[1]
			vfx.material_override = vfx.material_override.duplicate()
			(vfx.material_override as ShaderMaterial).set_shader_parameter(&"modulo", data[0] as Color)
			
		
		AREA_MINE:
			vfx = quick_setup(effect_id, pos) as MeshInstance3D
			vfx.get_tree().create_timer(data[1]).timeout.connect(vfx.queue_free)
			vfx.scale *= data[0]
			vfx.material_override = vfx.material_override.duplicate()
		
		BLOCK_BREAK:
			vfx = quick_setup(effect_id, pos) as GPUParticles3D
			setup_particle(vfx)
			vfx.global_basis = data[0] as Basis
			(vfx.process_material as ParticleProcessMaterial).emission_box_extents = data[1] as Vector3
			vfx.amount = data[2] as int
		
		EXPLOSION:
			vfx = quick_setup(effect_id, pos) as MeshInstance3D
			var tween := vfx.create_tween()
			vfx.scale = Vector3.ONE * 0.01
			tween.tween_property(vfx, ^"scale", Vector3.ONE * data[0], 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(vfx, ^"rotation", Vector3(randf_range(PI/2.0,PI*1.5), randf_range(PI/2.0,PI*1.5), randf_range(PI/2.0,PI*1.5)), 0.35)
			tween.parallel().tween_property(vfx, ^"rotation", Vector3(randf_range(PI/2.0,PI*1.5), randf_range(PI/2.0,PI*1.5), randf_range(PI/2.0,PI*1.5)), 0.35).as_relative()
			tween.finished.connect(vfx.queue_free)
		
		PLAYER_DEATH, PLAYER_DUST:
			vfx = quick_setup(effect_id, pos) as GPUParticles3D
			setup_particle(vfx)
			vfx.material_override = Network.player_from_uuid(data[0]).player_model.material
			if data.size() > 1: vfx.scale *= data[1]
		
		PLAYER_SLIDE:
			vfx = quick_setup(effect_id, pos) as GPUParticles3D
			setup_particle(vfx)
			vfx.material_override = Network.player_from_uuid(data[0]).player_model.material
			var tween := vfx.create_tween()
			tween.tween_property(vfx, ^"position", data[1], 1.0).as_relative()
		
		SPELL_SHOCKWAVE:
			vfx = quick_setup(effect_id, pos) as MeshInstance3D
			var tween := vfx.create_tween()
			vfx.scale = Vector3.ONE * 0.01
			tween.tween_property(vfx, ^"scale", Vector3.ONE * data[0], 0.4)
			tween.finished.connect(vfx.queue_free)
	
	return vfx
