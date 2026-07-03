class_name HUD
extends CanvasLayer

@onready var hurt_visual: Panel = $hurt_visual as Panel

@onready var crosshairs: Control = $crosshairs as Control
@onready var crosshair: TextureRect = $crosshairs/crosshair as TextureRect
@onready var reloading: TextureRect = $crosshairs/reloading as TextureRect
@onready var hit_marker: TextureRect = $hit_marker as TextureRect
@onready var hit_marker_invul: TextureRect = $hit_marker_invul as TextureRect

@onready var charge_1: RichTextLabel = $spells/charge1 as RichTextLabel
@onready var charge_2: RichTextLabel = $spells/charge2 as RichTextLabel

@onready var chatbox: RichTextLabel = $chat/chatbox as RichTextLabel
var chatduration: Array[float] = []

@onready var gun_debug: RichTextLabel = $gun/gun_debug as RichTextLabel

@onready var health: ProgressBar = $stats/health as ProgressBar
@onready var stam_true: ProgressBar = $stats/stam_true as ProgressBar
@onready var stam_round: ProgressBar = $stats/stam_round as ProgressBar

@onready var debug: RichTextLabel = $debug as RichTextLabel

@onready var win_lose_display: TextureRect = $win_lose_display as TextureRect
@onready var wl_lose: Label = $win_lose_display/lose as Label
@onready var wl_win: Label = $win_lose_display/win as Label

@onready var info_holder: Control = $info_holder as Control
@onready var info: Info = $info_holder/info as Info


const SPELL_READY := &"[color=#cfc]"
const SPELL_WAITING := &"[color=#caa]"


var player: Player
var hurt_timer: float = -1.0
var hit_marker_timer: float = -1.0
var hit_marker_invul_timer: float = -1.0
var win_lose_timer: float = -1.0
var is_win: bool = true


func _ready() -> void:
	player = get_parent().get_parent() as Player


func _process(delta: float) -> void:
	hurt_timer -= delta
	hit_marker_timer -= delta
	hit_marker_invul_timer -= delta
	win_lose_timer -= delta
	
	# hurt indicator
	hurt_visual.visible = (hurt_timer >= 0.0)
	
	# crosshairs
	crosshairs.rotation = (player.gun.fire_timer * (PI/2.0)) \
			if !player.gun.reload else \
			(player.gun.reload*PI / player.procgun.reload_time.value)
	crosshair.modulate = Color(1.0, 1.0, 1.0, 0.86)
	crosshair.visible = !player.gun.reload
	reloading.visible = player.gun.reload
	hit_marker.visible = (hit_marker_timer >= 0.0)
	hit_marker_invul.visible = (hit_marker_invul_timer >= 0.0)
	if hit_marker.visible: hit_marker.scale = Vector2.ONE * (1.5 - hit_marker_timer**2*10.0)
	if player.gun.fire_timer != 1.0:
		crosshair.modulate = Color(0.5, 0.65, 1.0, 1.0)
	
	charge_1.text = &"[color=#b85]%s[color=#5af]%s" %\
			[&"≡" if Util.has_frac(player.spell_1.charges) else &"", &"■".repeat(floori(player.spell_1.charges))]
	charge_2.text = &"[color=#5af]%s[color=#b85]%s" %\
			[&"■".repeat(floori(player.spell_2.charges)), &"≡" if Util.has_frac(player.spell_2.charges) else &""]
	
	# stats
	health.value = player.health
	health.max_value = player.max_health.value
	stam_true.value = player.stamina*100.0 / player.max_stamina.value
	stam_round.value = floorf(player.stamina)*100.0 / player.max_stamina.value
	
	# debug
	var perf := Performance.get_monitor(Performance.TIME_PROCESS) *1000
	debug.text = "%03.2f : %03.0f/%03.0f FPS\n%03.2f UPS\n%s Wins" %\
		[perf, Engine.get_frames_per_second(), 1000/perf, player.velocity.length(), Network.players[player.uuid].wins]
	
	# gun debug
	gun_debug.text = "%s / %s \n%02.1f %02.1f" % [player.gun.clip, player.procgun.clip_size.value_int, player.gun.fire_timer, player.gun.reload]
	
	# win lose text
	win_lose_display.visible = (win_lose_timer >= 0.0 && win_lose_timer <= 3.0)
	wl_win.visible = is_win
	wl_lose.visible = !is_win
	
	# chat messages
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
	chatduration.append(10.0)
