class_name SFXHandler

static var sounds: Array[AudioStreamWAV]
enum {
	DASH,
	DEATH,
	EXPLOSION,
	HIT,
	HURT,
	JUMP,
	KICK,
	LOSE,
	MAGIC_READY,
	POWERUP,
	RUBBER,
	SHOCKWAVE,
	SHOOT,
	WAVE,
	_MAX_COUNT }


static func load_all_sounds() -> void:
	sounds.resize(_MAX_COUNT)
	for i in _MAX_COUNT:
		match i:
			DASH: load_sound(&"dash", i)
			DEATH: load_sound(&"death", i)
			EXPLOSION: load_sound(&"explosion", i)
			HIT: load_sound(&"hit", i)
			HURT: load_sound(&"hurt", i)
			JUMP: load_sound(&"jump", i)
			KICK: load_sound(&"kick", i)
			LOSE: load_sound(&"lose", i)
			MAGIC_READY: load_sound(&"magic_ready", i)
			POWERUP: load_sound(&"powerup", i)
			RUBBER: load_sound(&"rubber", i)
			SHOCKWAVE: load_sound(&"shockwave", i)
			SHOOT: load_sound(&"shoot", i)
			WAVE: load_sound(&"wave", i)


static func load_sound(sound_id: StringName, i: int) -> void:
	Console.print(&"Loading effect '%s'" % sound_id)
	sounds[i] = AudioStreamWAV.load_from_file(&"res://sfx/%s.wav" % sound_id, {&"compress/mode":0})


## Plays a sound in the world, for everyone
static func play_world(sound_id: int, pos: Vector3, volume: float = 0.0, pitch_scale: float = 1.0, disable_falloff: bool = false) -> void:
	Network.sfx_sync.rpc(sound_id, pos, volume, pitch_scale, disable_falloff)


## Plays a sound in the world, only for current player
static func play_world_local(sound_id: int, pos: Vector3, volume: float = 0.0, pitch_scale: float = 1.0, disable_falloff: bool = false) -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.unit_size = 15.0
	sound.stream = sounds[sound_id]
	Game.world.sounds.add_child(sound)
	
	sound.global_position = pos
	sound.volume_db = volume
	sound.pitch_scale = pitch_scale * randf_range(0.9, 1.1)
	if disable_falloff: sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	
	sound.play()
	sound.finished.connect(sound.queue_free)


## Plays a sound
static func play_user(sound_id: int, volume: float = 0.0, pitch_scale: float = 1.0) -> void:
	var sound := AudioStreamPlayer.new()
	sound.stream = sounds[sound_id]
	Game.add_child(sound)
	
	sound.volume_db = volume
	sound.pitch_scale = pitch_scale * randf_range(0.95, 1.05)
	
	sound.play()
	sound.finished.connect(sound.queue_free)
