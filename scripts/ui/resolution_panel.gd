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
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_list.add_child(row)
	total_label.text = "预测结算：%d" % report.total
