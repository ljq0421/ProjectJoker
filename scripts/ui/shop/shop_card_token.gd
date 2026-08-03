class_name ShopCardToken
extends Button

const BuildIdentities = preload("res://scripts/run/build_identity_catalog.gd")
const Formatter = preload("res://scripts/ui/card_display_formatter.gd")

signal card_selected(card_id: StringName, role: StringName)

var card_id: StringName
var role: StringName

func _ready() -> void:
	pressed.connect(func() -> void: card_selected.emit(card_id, role))

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
	text = formatter.shop_compact_copy(
		card,
		identities.display_name(identities.identity_for_card(card)),
		price
	)
	icon = load(formatter.effect_icon_path(card))
	tooltip_text = "%s；%s" % [card.display_name, card.rule_text]
	set_meta("shop_role", role)
	set_meta("card_id", card_id)

func _target_copy(target_type: CardDefinition.TargetType) -> String:
	return Formatter.new().target_copy(target_type)
