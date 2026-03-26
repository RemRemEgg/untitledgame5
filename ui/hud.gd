class_name HUD
extends CanvasLayer


@onready var fps: RichTextLabel = $fps as RichTextLabel
@onready var stam_true: ProgressBar = $stam_true as ProgressBar
@onready var stam_round: ProgressBar = $stam_round as ProgressBar

var player: Player

func _ready() -> void:
	player = get_parent().get_parent().get_parent() as Player


func _process(_delta: float) -> void:
	fps.text = "%2.2f" % (Performance.get_monitor(Performance.TIME_PROCESS) *1000)
	Performance.get_monitor(Performance.TIME_PROCESS)
	stam_true.value = player.stamina*100.0 / player.stamina_max
	stam_round.value = floorf(player.stamina)*100.0 / player.stamina_max
