class_name HUD
extends CanvasLayer

@onready var crosshair: TextureRect = $crosshair as TextureRect

@onready var gun_debug: RichTextLabel = $gun/gun_debug as RichTextLabel

@onready var health: ProgressBar = $stats/health as ProgressBar
@onready var stam_true: ProgressBar = $stats/stam_true as ProgressBar
@onready var stam_round: ProgressBar = $stats/stam_round as ProgressBar
@onready var block: ProgressBar = $stats/block as ProgressBar

@onready var chatbox: RichTextLabel = $chat/chatbox as RichTextLabel
var chatduration: Array[float] = []

@onready var info_holder: Control = $info_holder as Control
@onready var info: Control = $info_holder/info as Info


@onready var debug: RichTextLabel = $debug as RichTextLabel


var player: Player

func _ready() -> void:
	player = get_parent().get_parent() as Player


func _process(delta: float) -> void:
	crosshair.rotation = (player.gun.fire_timer + (player.gun.reload / player.procgun.reload_time.value)) * (PI/2.0)
	crosshair.modulate = Color(1.0, 1.0, 1.0, 0.75)
	crosshair.scale = Vector2.ONE*2.0
	if player.gun.fire_timer != 1.0:
		crosshair.modulate = Color(0.75, 0.75, 1.0, 0.5)
		crosshair.scale *= 0.875
	if player.gun.reload:
		crosshair.modulate = Color(1.0, 0.75, 0.75, 0.5)
	
	health.value = player.health
	health.max_value = player.max_health.value
	stam_true.value = player.stamina*100.0 / player.stamina_max.value
	stam_round.value = floorf(player.stamina)*100.0 / player.stamina_max.value
	block.value = (-player.block_timer*100.0) / player.block_cd.value
	block.modulate = Color.WHITE if player.block_timer <= -player.block_cd.value else Color.WEB_GRAY
	
	var perf := Performance.get_monitor(Performance.TIME_PROCESS) *1000
	debug.text = "%03.2f : %03.0f/%03.0f FPS\n%03.2f UPS" %\
		[perf, Engine.get_frames_per_second(), 1000/perf, player.velocity.length()]
	
	gun_debug.text = "%s / %s \n%02.1f %02.1f" % [player.gun.clip, player.procgun.clip_size.value_int, player.gun.fire_timer, player.gun.reload]
	
	var remove_count := 0
	for i in chatduration.size():
		chatduration[i] -= delta
		if chatduration[i] <= 0.0: remove_count += 1
	if remove_count:
		chatduration = chatduration.slice(remove_count) as Array[float]
		chatbox.text = &"\n".join(chatbox.text.split(&"\n").slice(remove_count))
	
	if Input.is_action_pressed(&"view_info"):
		if Input.is_action_just_pressed(&"view_info"): info.swap_to_player(Game.player.uuid)
		info_holder.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		info_holder.visible = false
		Input.mouse_mode = Game.mouse_fallback


func add_chat_message(msg: String) -> void:
	Console.print("[chat] " + msg)
	if chatbox.text: chatbox.text += &"\n"+msg
	else: chatbox.text += msg
	chatduration.append(5.0)
