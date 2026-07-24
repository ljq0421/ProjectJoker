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
	used: bool
) -> void:
	card_index = index
	text = "%s\n%s" % [definition.display_name, _target_copy(definition.target_type)]
	button_pressed = selected
	disabled = used
	tooltip_text = "%s；目标：%s" % [
		definition.display_name,
		_target_copy(definition.target_type),
	]

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
	return "未知"
