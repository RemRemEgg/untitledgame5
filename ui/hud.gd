class_name HUD
extends CanvasLayer


@onready var fps: RichTextLabel = $fps as RichTextLabel
@onready var gun_debug: RichTextLabel = $gun_debug as RichTextLabel
@onready var health: ProgressBar = $health as ProgressBar
@onready var stam_true: ProgressBar = $stam_true as ProgressBar
@onready var stam_round: ProgressBar = $stam_round as ProgressBar

@onready var debug_any: RichTextLabel = $debug_any as RichTextLabel


var player: Player

func _ready() -> void:
	player = get_parent().get_parent().get_parent() as Player


func _process(_delta: float) -> void:
	fps.text = "%2.2f" % (Performance.get_monitor(Performance.TIME_PROCESS) *1000)
	health.value = player.health
	health.max_value = player.max_health
	stam_true.value = player.stamina*100.0 / player.stamina_max
	stam_round.value = floorf(player.stamina)*100.0 / player.stamina_max
	
	gun_debug.text = "%s / %s \n%01.1f " % [player.gun.clip, player.procgun.clip_size, player.gun.reload]
