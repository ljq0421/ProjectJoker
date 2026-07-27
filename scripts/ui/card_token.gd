class_name CardToken
extends Button

signal card_activated(card_index: int)

var card_index: int

func _ready() -> void:
	pressed.connect(func() -> void: card_activated.emit(card_index))

func bind_card(
	index: int,
	definition: CardDefinition,
	selected: bool,
	used: bool,
	selection_step: String = ""
) -> void:
	card_index = index
	text = "%s · %s\n%s · %s\n%s" % [
		definition.suit_copy(),
		definition.rank_label,
		definition.display_name,
		target_copy_for(definition),
		definition.rule_text,
	]
	button_pressed = selected
	disabled = used
	if selected and not selection_step.is_empty():
		text += "\n▶ %s" % selection_step
	tooltip_text = "%s · %s · %s · %s；目标：%s；%s" % [
		definition.suit_copy(),
		definition.rank_label,
		definition.rarity_copy(),
		definition.display_name,
		target_copy_for(definition),
		definition.rule_text,
	]

func target_copy_for(definition: CardDefinition) -> String:
	var copy := _target_copy(definition.target_type)
	if (
		definition.target_type == CardDefinition.TargetType.GAP
		and not definition.mirror_effects.is_empty()
	):
		copy += " · 可镜像"
	return copy

func _target_copy(target_type: CardDefinition.TargetType) -> String:
	match target_type:
		CardDefinition.TargetType.DIE:
			return "骰子"
		CardDefinition.TargetType.TABLE:
			return "规则台"
		CardDefinition.TargetType.GAP:
			return "桌间"
		CardDefinition.TargetType.GLOBAL:
			return "全局"
		CardDefinition.TargetType.DICE_PAIR:
			return "双骰"
	return "未知"
