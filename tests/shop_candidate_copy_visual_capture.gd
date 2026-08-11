extends SceneTree

const OUTPUT_DIR := "res://tmp/shop-candidate-copy-captures"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var shop: ShopScreen = load("res://scenes/shop/shop_screen.tscn").instantiate()
	viewport.add_child(shop)
	var area := AreaCatalog.new().gold_corridor()
	var catalog := CardCatalog.new()
	var session := ShopSession.new(
		catalog,
		area.starting_deck_ids,
		area.shop_offer_ids,
		10,
		ShopIntelSnapshot.routes(area.second_route_ids),
		0,
		true,
		0,
		true
	)
	shop.bind_session(session, catalog)
	var profiles: Array[DieState] = []
	for die_index in range(1, 7):
		profiles.append(DieState.new(StringName("d%d" % die_index), die_index))
	shop.bind_formal_context(profiles, EngravingCatalog.new())
	shop._on_card_selected(session.offer_ids[0], &"offer")
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("failed to capture shop candidate copy")
		quit(1)
		return
	if image.save_png("%s/shop-candidate-1920x1080.png" % OUTPUT_DIR) != OK:
		push_error("failed to save 1920x1080 shop candidate capture")
		quit(1)
		return
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	if image.save_png("%s/shop-candidate-1280x720.png" % OUTPUT_DIR) != OK:
		push_error("failed to save 1280x720 shop candidate capture")
		quit(1)
		return
	print("CAPTURED shop candidate copy -> %s" % OUTPUT_DIR)
	quit(0)
