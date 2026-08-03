class_name ShopCardToken
extends Button

const BuildIdentities = preload("res://scripts/run/build_identity_catalog.gd")
const Formatter = preload("res://scripts/ui/card_display_formatter.gd")

signal card_selected(card_id: StringName, role: StringName)

var card_id: StringName
var role: StringName
var _hovered := false

func _ready() -> void:
	pressed.connect(func() -> void: card_selected.emit(card_id, role))
	mouse_entered.connect(func() -> void:
		_hovered = true
		_refresh_face_emphasis()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_refresh_face_emphasis()
	)
	focus_entered.connect(_refresh_face_emphasis)
	focus_exited.connect(_refresh_face_emphasis)

func bind_card(
	card: CardDefinition,
	selected: bool,
	p_disabled: bool,
	p_role: StringName,
	price: int = -1
) -> void:
	card_id = card.id
	role = p_role
	button_pressed = selected
	disabled = p_disabled
	var identities := BuildIdentities.new()
	var formatter := Formatter.new()
	var identity_copy := identities.display_name(
		identities.identity_for_card(card)
	)
	var face := get_node_or_null("CardFaceContent")
	if face != null:
		text = ""
		icon = null
		face.bind_card(card, identity_copy, price, true)
	else:
		text = formatter.shop_compact_copy(card, identity_copy, price)
		icon = load(formatter.effect_icon_path(card))
	if face != null:
		face.set_interaction_state(selected, p_disabled)
		_refresh_face_emphasis()
	tooltip_text = "%s；%s" % [card.display_name, card.rule_text]
	set_meta("shop_role", role)
	set_meta("card_id", card_id)

func _target_copy(target_type: CardDefinition.TargetType) -> String:
	return Formatter.new().target_copy(target_type)


func _refresh_face_emphasis() -> void:
	var face := get_node_or_null("CardFaceContent")
	if face != null:
		face.set_emphasized(_hovered or has_focus())
