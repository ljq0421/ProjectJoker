class_name ShopCardToken
extends Button

const BuildIdentities = preload("res://scripts/run/build_identity_catalog.gd")

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
	var price_copy := "" if price < 0 else "\n售价：%d 情报券" % price
	var identities := BuildIdentities.new()
	text = "%s｜%s\n目标：%s\n%s%s" % [
		card.display_name,
		identities.display_name(identities.identity_for_card(card)),
		_target_copy(card.target_type),
		card.rule_text,
		price_copy,
	]
	tooltip_text = "%s；%s" % [card.display_name, card.rule_text]
	set_meta("shop_role", role)
	set_meta("card_id", card_id)

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
