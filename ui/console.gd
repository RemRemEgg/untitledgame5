extends CanvasLayer

@onready var lines: RichTextLabel
@onready var input: LineEdit

var history: Array[String]
var h_index := -1
var load_status: int = 0
var load_call: Callable


static var DEBUG: bool = true


func _ready() -> void:
	lines = $margin/vbox/lines as RichTextLabel
	input = $margin/vbox/input as LineEdit
	history = []
	input.text_submitted.connect(submit_console)

func _process(_delta: float) -> void:
	if load_status % 3 == 1:
		load_call.call_deferred()
		load_status += 1
	if load_status % 3 == 2: return
	match load_status:
		0: attempt_load(load_cards, &"Loading Cards")
		3: attempt_load(load_resources, &"Loading Cards")
		#0: attempt_load(Global.load_resources, "Loading Global Resources")
		#3: attempt_load(Server.load_resources, "Loading Server Resources")
		#6: attempt_load(ProcItem.register_all, "Loading Static Items")
		#9: attempt_load(self.cleanup, "Cleaning up")
		#12: attempt_load(func():Limbo.goto.call_deferred(Limbo.MAIN_MENU), "Starting Main Menu...")

func attempt_load(load_step: Callable, load_name: String) -> void:
	self.print(load_name)
	load_call = load_step
	load_status += 1

func load_cards() -> void:
	load_status += 1
	Card.register_all_cards()

func load_resources() -> void:
	load_status += 1 +3+3+3
	self.print(&"CLoad complete, initalizing")
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file(&"res://ui/connection_ui.tscn")
	load_status = -1
	toggle_console()

####################################################################################################################################################################################
## # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
####################################################################################################################################################################################

func _input(event: InputEvent) -> void:
	if event is InputEventKey && event.is_pressed():
		if event.is_action(&"dbg_console") || (event.is_action(&"escape") && visible): call_deferred(&"toggle_console")
		if event.keycode == KEY_UP:
			h_index = clamp(h_index +1, -1, history.size() -1)
			input.clear()
			if h_index != -1: input.insert_text_at_caret(history[h_index])
		if event.keycode == KEY_DOWN:
			h_index = clamp(h_index -1, -1, history.size() -1)
			input.clear()
			if h_index != -1: input.insert_text_at_caret(history[h_index])

func toggle_console() -> void:
	if load_status > -1: return
	visible = !visible
	set_process(visible)
	if visible:
		input.grab_focus()
		input.text = ""

func submit_console(text: String) -> void:
	input.text = ""
	parse_command(text)
	h_index = -1
	if (history.size() > 0 && history[0] != text) || history.size() == 0: history.push_front(text)

func print(text: String) -> void:
	print_rich(&"[Console] " + text.replace(&"\n", &"\n          "))
	lines.text += (&"\n" if !lines.text.is_empty() else &"") + text

func print_err(text: String) -> void:
	print_rich(&"[color=red][Error] " + text.replace(&"\n", &"\n[Error] ") + &"[/color]")
	push_error(&"[Error] " + text.replace(&"\n", &"\n[Error] "))
	lines.text += (&"\n" if !lines.text.is_empty() else &"") + &"[color=red]" + text + &"[/color]"

func parse_command(text: String) -> void:
	var commands := Util.split_in_same_level(text, &";")
	self.print(&"> " + text)
	for command in commands:
		var args := Util.split_in_same_level(command, &" ")
		#while args.size() > 0 && !args[0].is_empty(): args.pop_front() #TODO ???
		run_command(args)

var hit_error: bool = false
var is_help: bool = false
func help(txt: StringName) -> bool:
	if is_help: self.print(txt)
	return is_help
func run_command(args: Array[String]) -> void:
	hit_error = false
	if args.size() == 0: return
	match args[0]:
		&"help":
			if help(&"help [command]"):return
			match args.size():
				1: self.print(&"Commands: help fps")
				2:
					is_help = true
					args.pop_front()
					run_command(args)
					is_help = false
				3: exact_args(args, 2)
		&"fps":
			if help(&"fps [target:int]"): return
			if args.size() < 2: return self.print(&"FPS target: %s (%s mspt), Running: %s" % [&"uncapped" if Engine.max_fps == 0 else StringName(str(Engine.max_fps)),round(1000.0/Engine.max_fps),Engine.get_frames_per_second()])
			Engine.max_fps = int(args[1])
			self.print(&"FPS target set to %s (%s mspt)" % [Engine.max_fps,round(1000.0/Engine.max_fps)])
		&"net":
			if help(&"net <info|state> [value]"): return
			if !(exact_args(args, 1) || exact_args(args, 2)): return
			match args[1]:
				&"info":
					self.print(&"Network[%s]: S:%s N:%s" % [Network.uuid, Network.NS_NAME[Network.self_player.state], Network.NS_NAME[Network.next_state]])
				&"state":
					Network.change_to_state(Network.NS_NAME.find(args[2]))
		_ when !hit_error: print_err(&"Unknown Command '%s'" % args[0])
		_: pass

func exact_args(args: Array[String], count: int) -> bool:
	if args.size() == count+1: return true
	hit_error = true
	print_err(&"Invalid arguments, expected %s got %s" % [count, args.size()-1])
	return false

func in_game() -> bool:
	if Game: return true
	hit_error = true
	print_err(&"Must be in-game to use this command")
	return false
