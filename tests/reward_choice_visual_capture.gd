extends SceneTree

const OUTPUT_DIR := "res://tmp/reward-choice-captures"

var viewport: SubViewport
var panel: EngravingRewardPanel


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	panel = load(
		"res://scenes/components/engraving_reward_panel.tscn"
	).instantiate()
	viewport.add_child(panel)
	var cards := CardCatalog.new()
	var engravings := EngravingCatalog.new()
	var profiles: Array[DieState] = []
	for index in range(6):
		profiles.append(DieState.new(StringName("d%d" % (index + 1)), index + 1))
	panel.bind_reward(
		[&"engraving_echo", &"engraving_anchor"],
		profiles,
		engravings,
		[&"shop_long_push"],
		cards.starter_ids(),
		cards
	)
	await process_frame
	await process_frame
	if not _save("01-card-replacement.png"):
		return
	panel._show_engraving_mode()
	panel._on_engraving_selected(&"engraving_echo")
	panel._on_die_button_pressed(panel.get_node("%DieRow").get_child(0))
	panel._on_face_button_pressed(panel.get_node("%FaceGrid").get_child(3))
	await process_frame
	await process_frame
	if not _save("02-engraving-selection.png"):
		return
	print("CAPTURED reward choice frames -> %s" % OUTPUT_DIR)
	quit(0)


func _save(file_name: String) -> bool:
	var image := viewport.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	if image == null or image.save_png(path) != OK:
		push_error("failed to capture reward choice frame: %s" % file_name)
		quit(1)
		return false
	return true
