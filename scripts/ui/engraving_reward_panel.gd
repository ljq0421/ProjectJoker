class_name EngravingRewardPanel
extends Control

signal engraving_selected(engraving_id: StringName)
signal die_selected(die_id: StringName)
signal face_selected(face: int)
signal install_requested(engraving_id: StringName, die_id: StringName, face: int)
signal card_reward_requested(card_id: StringName, replaced_id: StringName)
signal reward_card_selected(card_id: StringName)
signal replacement_card_selected(card_id: StringName)

const OPTION_SCENE = preload("res://scenes/components/engraving_option_token.tscn")
const CARD_SCENE = preload("res://scenes/components/shop_card_token.tscn")
const BuildIdentities = preload("res://scripts/run/build_identity_catalog.gd")

var selected_engraving_id: StringName = &""
var selected_die_id: StringName = &""
var selected_face: int = 0
var selected_reward_card_id: StringName = &""
var selected_replaced_card_id: StringName = &""
var _card_catalog: CardCatalog

func _ready() -> void:
	visible = false
	%InstallEngravingButton.pressed.connect(_on_install_pressed)
	%CardRewardModeButton.pressed.connect(_show_card_mode)
	%EngravingRewardModeButton.pressed.connect(_show_engraving_mode)
	%ConfirmCardRewardButton.pressed.connect(_on_card_reward_pressed)

func bind_reward(
	offer_ids: Array[StringName],
	profiles: Array[DieState],
	catalog: EngravingCatalog,
	rare_card_ids: Array[StringName] = [],
	deck_ids: Array[StringName] = [],
	card_catalog: CardCatalog = null,
	restored_reward_card_id: StringName = &"",
	restored_replaced_card_id: StringName = &""
) -> void:
	_clear_container(%OfferRow)
	_clear_container(%DieRow)
	_clear_container(%FaceGrid)
	_clear_container(%RareCardOfferRow)
	_clear_container(%RewardDeckGrid)
	selected_engraving_id = &""
	selected_die_id = &""
	selected_face = 0
	selected_reward_card_id = restored_reward_card_id
	selected_replaced_card_id = restored_replaced_card_id
	_card_catalog = card_catalog
	%RewardErrorLabel.text = ""

	for engraving_id in offer_ids:
		var definition := catalog.find_engraving(engraving_id)
		if definition == null:
			continue
		var token: EngravingOptionToken = OPTION_SCENE.instantiate()
		%OfferRow.add_child(token)
		token.bind_engraving(definition, false)
		token.engraving_selected.connect(_on_engraving_selected)

	for card_id in rare_card_ids:
		var card := card_catalog.find_card(card_id) if card_catalog != null else null
		if card == null:
			continue
		var token: ShopCardToken = CARD_SCENE.instantiate()
		%RareCardOfferRow.add_child(token)
		token.bind_card(card, false, false, &"reward_offer")
		token.card_selected.connect(_on_reward_card_selected)

	for card_id in deck_ids:
		var card := card_catalog.find_card(card_id) if card_catalog != null else null
		if card == null:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(136, 46)
		button.toggle_mode = true
		button.text = card.display_name
		button.tooltip_text = "%s｜%s" % [
			BuildIdentities.new().display_name(
				BuildIdentities.new().identity_for_card(card)
			),
			card.rule_text,
		]
		button.set_meta("card_id", card_id)
		button.pressed.connect(_on_replacement_card_pressed.bind(button))
		%RewardDeckGrid.add_child(button)

	for profile in profiles:
		var button := Button.new()
		button.custom_minimum_size = Vector2(92, 58)
		button.toggle_mode = true
		button.text = String(profile.id).to_upper()
		if profile.engraving_id != &"":
			button.text += "\n已刻印"
			button.disabled = true
		button.set_meta("die_id", profile.id)
		button.pressed.connect(_on_die_button_pressed.bind(button))
		%DieRow.add_child(button)

	for face in range(1, 7):
		var button := Button.new()
		button.custom_minimum_size = Vector2(72, 58)
		button.toggle_mode = true
		button.text = str(face)
		button.set_meta("face", face)
		button.pressed.connect(_on_face_button_pressed.bind(button))
		%FaceGrid.add_child(button)

	visible = true
	%CardRewardModeButton.visible = not rare_card_ids.is_empty()
	%CardRewardModeButton.disabled = rare_card_ids.is_empty()
	_show_card_mode() if not rare_card_ids.is_empty() else _show_engraving_mode()
	_update_selection()

func show_error(message: String) -> void:
	%RewardErrorLabel.text = message
	SfxAccess.play(self, &"error")

func restore_engraving_selection(engraving_id: StringName) -> void:
	selected_engraving_id = engraving_id
	_show_engraving_mode()
	_update_selection()

func close() -> void:
	visible = false

func _on_engraving_selected(engraving_id: StringName) -> void:
	selected_engraving_id = engraving_id
	engraving_selected.emit(engraving_id)
	_update_selection()

func _on_reward_card_selected(card_id: StringName, _role: StringName) -> void:
	if selected_reward_card_id != card_id:
		SfxAccess.play(self, &"card_select")
	selected_reward_card_id = card_id
	reward_card_selected.emit(card_id)
	_update_selection()

func _on_replacement_card_pressed(button: Button) -> void:
	var card_id: StringName = button.get_meta("card_id", &"")
	if selected_replaced_card_id != card_id:
		SfxAccess.play(self, &"card_select")
	selected_replaced_card_id = card_id
	replacement_card_selected.emit(card_id)
	_update_selection()

func _on_card_reward_pressed() -> void:
	if selected_reward_card_id == &"" or selected_replaced_card_id == &"":
		show_error("请先选择稀有牌和要替换的当前牌")
		return
	card_reward_requested.emit(
		selected_reward_card_id,
		selected_replaced_card_id
	)

func _show_card_mode() -> void:
	%CardRewardModeButton.button_pressed = true
	%EngravingRewardModeButton.button_pressed = false
	for node in [
		%RareCardTitle,
		%RareCardOfferRow,
		%RewardDeckTitle,
		%RewardDeckGrid,
		%ConfirmCardRewardButton,
	]:
		node.visible = true
	for node in [%OfferRow, %DieTitle, %DieRow, %FaceTitle, %FaceGrid, %InstallEngravingButton]:
		node.visible = false
	_update_selection()

func _show_engraving_mode() -> void:
	%CardRewardModeButton.button_pressed = false
	%EngravingRewardModeButton.button_pressed = true
	for node in [
		%RareCardTitle,
		%RareCardOfferRow,
		%RewardDeckTitle,
		%RewardDeckGrid,
		%ConfirmCardRewardButton,
	]:
		node.visible = false
	for node in [%OfferRow, %DieTitle, %DieRow, %FaceTitle, %FaceGrid, %InstallEngravingButton]:
		node.visible = true
	_update_selection()

func _on_die_button_pressed(button: Button) -> void:
	var die_id: StringName = button.get_meta("die_id")
	if selected_die_id != die_id:
		SfxAccess.play(self, &"engraving_select")
	selected_die_id = die_id
	die_selected.emit(selected_die_id)
	_update_selection()

func _on_face_button_pressed(button: Button) -> void:
	var face := int(button.get_meta("face"))
	if selected_face != face:
		SfxAccess.play(self, &"engraving_select")
	selected_face = face
	face_selected.emit(selected_face)
	_update_selection()

func _on_install_pressed() -> void:
	if (
		selected_engraving_id == &""
		or selected_die_id == &""
		or selected_face == 0
	):
		show_error("请依次选择刻印、骰子和骰面")
		return
	install_requested.emit(selected_engraving_id, selected_die_id, selected_face)

func _update_selection() -> void:
	for child in %OfferRow.get_children():
		if child is EngravingOptionToken:
			child.button_pressed = child.engraving_id == selected_engraving_id
	for child in %DieRow.get_children():
		if child is Button:
			child.button_pressed = child.get_meta("die_id", &"") == selected_die_id
	for child in %FaceGrid.get_children():
		if child is Button:
			child.button_pressed = int(child.get_meta("face", 0)) == selected_face
	for child in %RareCardOfferRow.get_children():
		if child is ShopCardToken:
			child.button_pressed = child.card_id == selected_reward_card_id
	for child in %RewardDeckGrid.get_children():
		if child is Button:
			child.button_pressed = (
				child.get_meta("card_id", &"") == selected_replaced_card_id
			)
	if %CardRewardModeButton.button_pressed:
		%RewardSelectionLabel.text = "稀有牌：%s　替换：%s" % [
			_card_name(selected_reward_card_id),
			_card_name(selected_replaced_card_id),
		]
	else:
		%RewardSelectionLabel.text = "刻印：%s　骰子：%s　骰面：%s" % [
			"未选择" if selected_engraving_id == &"" else selected_engraving_id,
			"未选择" if selected_die_id == &"" else selected_die_id,
			"未选择" if selected_face == 0 else str(selected_face),
		]
	%ConfirmCardRewardButton.disabled = (
		selected_reward_card_id == &""
		or selected_replaced_card_id == &""
	)
	%InstallEngravingButton.disabled = (
		selected_engraving_id == &""
		or selected_die_id == &""
		or selected_face == 0
	)

func _card_name(card_id: StringName) -> String:
	if card_id == &"":
		return "未选择"
	var card := _card_catalog.find_card(card_id) if _card_catalog != null else null
	return "未知" if card == null else card.display_name

func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
