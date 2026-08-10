class_name AreaEventPanel
extends Control

signal choice_requested(choice_id: StringName, target_die_id: StringName)

@onready var title_label: Label = %EventTitle
@onready var detail_label: Label = %EventDetail
@onready var options: VBoxContainer = %EventOptions
@onready var error_label: Label = %EventError

func _ready() -> void:
	visible = false

func bind_session(area: AreaRunSession) -> void:
	_reset_options()
	match area.current_event_id:
		AreaRunSession.EVENT_DICE_ARTISAN:
			title_label.text = "普通房事件 · 骰子工匠"
			detail_label.text = "选择一颗骰子，将它的幸运面重投为不同点数。"
			for die_index in range(1, 7):
				var die_id := StringName("d%d" % die_index)
				_add_option(
					"D%d｜当前幸运面 %d" % [
						die_index,
						int(area.lucky_faces.get(die_id, 0)),
					],
					&"reroll",
					die_id
				)
		AreaRunSession.EVENT_REST_STOP:
			title_label.text = "普通房事件 · 休息站"
			detail_label.text = "整备下一场遭遇：第一轮初始校准 +1。"
			_add_option("接受整备", &"rest")
		AreaRunSession.EVENT_MYSTERY_GAMBLE:
			title_label.text = "普通房事件 · 神秘赌局"
			detail_label.text = "选择确定收益，或支付情报换取本区域随机稀有牌。"
			_add_option("获得 1 情报", &"intel")
			var reason := area.event_choice_block_reason(&"rare_card")
			_add_option("支付 2 情报 · 获得随机稀有牌", &"rare_card", &"", reason)
		_:
			title_label.text = "普通房事件"
			detail_label.text = "事件数据不存在。"

func bind_choice_room(area: AreaRunSession) -> void:
	_reset_options()
	title_label.text = "无面中枢 · 抉择房"
	detail_label.text = "三项公开契据只能选择一项；代价与收益立即写入检查点。"
	_add_option(
		"加压契据｜下一场目标 +10% · 立即获得 3 情报",
		&"raise_target",
		&"",
		area.choice_room_block_reason(&"raise_target")
	)
	_add_option(
		"预付校准｜支付 2 情报 · 下一场首轮校准 +2",
		&"buy_calibration",
		&"",
		area.choice_room_block_reason(&"buy_calibration")
	)
	if area.deck_ids.size() <= CardDeck.MIN_DECK_SIZE:
		_add_option(
			"注销牌页｜免费移除 1 张牌",
			&"remove_card",
			&"",
			"牌组必须大于十二张才能移除"
		)
	else:
		for card_id in area.deck_ids:
			var card := area.card_catalog.find_card(card_id)
			_add_option(
				"注销牌页｜免费移除「%s」" % card.display_name,
				&"remove_card",
				card_id,
				area.choice_room_block_reason(&"remove_card", card_id)
			)

func bind_engraving_room(area: AreaRunSession) -> void:
	_reset_options()
	title_label.text = "无面中枢 · 刻印房"
	detail_label.text = "从种子固定候选中免费安装一枚刻印；已有刻印不会被覆盖。"
	var empty_dice: Array[DieState] = []
	for profile in area.die_profiles:
		if profile.engraving_id == &"":
			empty_dice.append(profile)
	if area.special_engraving_offer_ids.is_empty():
		_add_option(
			"刻印池已耗尽",
			&"none",
			&"",
			"没有尚未拥有的区域刻印，可直接跳过"
		)
	elif empty_dice.is_empty():
		_add_option(
			"没有未刻印骰子",
			&"none",
			&"",
			"六颗骰子均已刻印，不能覆盖已有刻印"
		)
	else:
		for engraving_id in area.special_engraving_offer_ids:
			var engraving := area.engraving_catalog.find_engraving(engraving_id)
			for profile in empty_dice:
				var lucky_face := int(area.lucky_faces.get(profile.id, 0))
				_add_option(
					"%s → %s 的 %d 点面" % [
						engraving.display_name,
						String(profile.id).to_upper(),
						lucky_face,
					],
					engraving_id,
					profile.id,
					area.engraving_room_block_reason(engraving_id, profile.id)
				)
	_add_option("跳过刻印房", &"", &"")

func show_error(reason: String) -> void:
	error_label.text = reason

func close() -> void:
	visible = false

func _reset_options() -> void:
	visible = true
	error_label.text = ""
	for child in options.get_children():
		child.queue_free()

func _add_option(
	copy: String,
	choice_id: StringName,
	target_die_id: StringName = &"",
	block_reason: String = ""
) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(520, 48)
	button.text = copy
	button.disabled = not block_reason.is_empty()
	button.tooltip_text = block_reason
	button.pressed.connect(
		func() -> void: choice_requested.emit(choice_id, target_die_id)
	)
	options.add_child(button)
