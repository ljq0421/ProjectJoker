class_name EngravingRewardPanel
extends Control

signal engraving_selected(engraving_id: StringName)
signal die_selected(die_id: StringName)
signal face_selected(face: int)
signal install_requested(engraving_id: StringName, die_id: StringName, face: int)

const OPTION_SCENE = preload("res://scenes/components/engraving_option_token.tscn")

var selected_engraving_id: StringName = &""
var selected_die_id: StringName = &""
var selected_face: int = 0

func _ready() -> void:
	visible = false
	%InstallEngravingButton.pressed.connect(_on_install_pressed)

func bind_reward(
	offer_ids: Array[StringName],
	profiles: Array[DieState],
	catalog: EngravingCatalog
) -> void:
	_clear_container(%OfferRow)
	_clear_container(%DieRow)
	_clear_container(%FaceGrid)
	selected_engraving_id = &""
	selected_die_id = &""
	selected_face = 0
	%RewardErrorLabel.text = ""

	for engraving_id in offer_ids:
		var definition := catalog.find_engraving(engraving_id)
		if definition == null:
			continue
		var token: EngravingOptionToken = OPTION_SCENE.instantiate()
		%OfferRow.add_child(token)
		token.bind_engraving(definition, false)
		token.engraving_selected.connect(_on_engraving_selected)

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
	_update_selection()

func show_error(message: String) -> void:
	%RewardErrorLabel.text = message
	SfxAccess.play(self, &"error")

func restore_engraving_selection(engraving_id: StringName) -> void:
	selected_engraving_id = engraving_id
	_update_selection()

func close() -> void:
	visible = false

func _on_engraving_selected(engraving_id: StringName) -> void:
	selected_engraving_id = engraving_id
	engraving_selected.emit(engraving_id)
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
	%RewardSelectionLabel.text = "刻印：%s　骰子：%s　骰面：%s" % [
		"未选择" if selected_engraving_id == &"" else selected_engraving_id,
		"未选择" if selected_die_id == &"" else selected_die_id,
		"未选择" if selected_face == 0 else str(selected_face),
	]
	%InstallEngravingButton.disabled = (
		selected_engraving_id == &""
		or selected_die_id == &""
		or selected_face == 0
	)

func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
