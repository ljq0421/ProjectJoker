extends SceneTree

const CARD_IDS := [
	&"faceless_strict_mapping",
	&"faceless_reverse_replay",
	&"faceless_compressed_repeat",
	&"faceless_closed_circuit",
]

var output := "res://tmp/card-face-runtime-preview.png"


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var stage := ColorRect.new()
	stage.color = Color("080619")
	stage.size = viewport.size
	stage.theme = load("res://resources/themes/neon_dream_theme.tres")
	viewport.add_child(stage)

	var column := VBoxContainer.new()
	column.position = Vector2(22, 18)
	column.size = Vector2(1236, 444)
	column.add_theme_constant_override("separation", 12)
	stage.add_child(column)

	var hand_title := Label.new()
	hand_title.text = "手牌 / 190 × 126"
	hand_title.add_theme_font_size_override("font_size", 18)
	column.add_child(hand_title)

	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 10)
	column.add_child(hand_row)
	for index in range(CARD_IDS.size()):
		var card: CardDefinition = CardCatalog.new().find_card(CARD_IDS[index])
		var token: CardToken = load(
			"res://scenes/components/card_token.tscn"
		).instantiate()
		hand_row.add_child(token)
		token.bind_card(index, card, index == 2, false)

	var shop_title := Label.new()
	shop_title.text = "商店 / 250 × 190（卡面 250 × 167）"
	shop_title.add_theme_font_size_override("font_size", 18)
	column.add_child(shop_title)

	var shop_row := HBoxContainer.new()
	shop_row.add_theme_constant_override("separation", 10)
	column.add_child(shop_row)
	for index in range(4):
		var card: CardDefinition = CardCatalog.new().find_card(CARD_IDS[index])
		var token: ShopCardToken = load(
			"res://scenes/components/shop_card_token.tscn"
		).instantiate()
		shop_row.add_child(token)
		token.bind_card(card, index == 1, false, &"offer", 1)

	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.save_png(output) != OK:
		push_error("failed to capture card-face runtime preview")
		quit(1)
		return
	print("CAPTURED card-face runtime preview -> %s" % output)
	quit(0)
