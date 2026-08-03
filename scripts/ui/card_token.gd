class_name CardToken
extends Button

const Formatter = preload("res://scripts/ui/card_display_formatter.gd")

signal card_activated(card_index: int)

var card_index: int

func _ready() -> void:
	pressed.connect(func() -> void: card_activated.emit(card_index))

func bind_card(
	index: int,
	definition: CardDefinition,
	selected: bool,
	used: bool,
	_selection_step: String = "",
	disabled_reason: String = ""
) -> void:
	card_index = index
	var formatter := Formatter.new()
	text = formatter.compact_copy(definition)
	icon = load(formatter.effect_icon_path(definition))
	button_pressed = selected
	disabled = used or not disabled_reason.is_empty()
	tooltip_text = "%s · %s · %s · %s；目标：%s；%s" % [
		definition.suit_copy(),
		definition.rank_label,
		definition.rarity_copy(),
		definition.display_name,
		target_copy_for(definition),
		definition.rule_text,
	]
	if not disabled_reason.is_empty():
		tooltip_text += "；当前不可用：%s" % disabled_reason

func target_copy_for(definition: CardDefinition) -> String:
	return Formatter.new().target_copy_for(definition)

func _target_copy(target_type: CardDefinition.TargetType) -> String:
	return Formatter.new().target_copy(target_type)
