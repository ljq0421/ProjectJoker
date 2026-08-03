extends SceneTree

var output := ""
var state := "main"
var scope := "demo"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--state="):
			state = argument.trim_prefix("--state=")
		elif argument.begins_with("--scope="):
			scope = argument.trim_prefix("--scope=")
	call_deferred("_run")

func _run() -> void:
	if output.is_empty():
		push_error("main menu capture requires --output")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var menu: MainMenuScreen = load(
		"res://scenes/run/main_menu_screen.tscn"
	).instantiate()
	if scope == "demo":
		menu.demo_scope_override = 1
	elif scope == "full":
		menu.demo_scope_override = 0
	else:
		push_error("unknown main menu capture scope: %s" % scope)
		quit(1)
		return
	menu.expedition_save_path = "user://visual-capture-expedition.cfg"
	menu.tutorial_config_path = "user://visual-capture-onboarding.cfg"
	viewport.add_child(menu)
	await _settle()
	if state == "credits":
		menu._on_credits_pressed()
		await _settle()
	elif state != "main":
		push_error("unknown main menu capture state: %s" % state)
		quit(1)
		return
	var image := viewport.get_texture().get_image()
	if image == null or image.save_png(output) != OK:
		push_error("failed to save main menu capture")
		quit(1)
		return
	print("CAPTURED main-menu scope=%s state=%s -> %s" % [scope, state, output])
	quit(0)

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame
