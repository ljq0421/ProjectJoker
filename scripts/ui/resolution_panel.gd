class_name ResolutionPanel
extends PanelContainer

@onready var event_list: VBoxContainer = %EventList
@onready var total_label: Label = %Total

func bind_report(report: ResolutionReport) -> void:
	for child in event_list.get_children():
		child.queue_free()
	for event in report.events:
		var row := Label.new()
		row.text = "%s　%+d　→ %d" % [event.label, event.delta, event.running_total]
		row.set_meta("is_mirror_copy", event.is_mirror_copy)
		row.set_meta("source_card_id", event.source_card_id)
		row.set_meta("source_slot_id", event.source_slot_id)
		row.set_meta("mirror_slot_id", event.mirror_slot_id)
		if event.is_mirror_copy:
			row.add_theme_color_override("font_color", Color(0.68, 1.0, 0.96, 1.0))
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_list.add_child(row)
	total_label.text = "预测结算：%d" % report.total
