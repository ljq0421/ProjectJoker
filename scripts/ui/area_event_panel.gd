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
	visible = true
	error_label.text = ""
	for child in options.get_children():
		child.queue_free()
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

func show_error(reason: String) -> void:
	error_label.text = reason

func close() -> void:
	visible = false

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
