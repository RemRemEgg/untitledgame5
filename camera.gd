extends Node3D


var SPEED: float = 6.0
var cam_ax: float = 0.0
var p_rot: float = 0.0
@onready var camera: Camera3D = $Camera3D as Camera3D
@onready var label: Label = $Camera3D/Label as Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if Input.is_action_pressed("up"): position.y += SPEED*delta
	if Input.is_action_pressed("down"): position.y -= SPEED*delta

	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized() * delta
	if direction:
		position.x += direction.x * SPEED
		position.z += direction.z * SPEED
	
	label.text = str(Performance.get_monitor(Performance.TIME_PROCESS) * 1_000)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var delta_y := deg_to_rad(-event.relative.x * 0.2)
		rotate_y(delta_y)
		var delta_x := clampf(deg_to_rad(-event.relative.y * 0.2) + cam_ax, -PI/2, PI/2) - cam_ax
		cam_ax += delta_x
		camera.rotate_x(delta_x)
	
