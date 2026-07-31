class_name AreaAtmosphere
extends Control

const AreaPresentation = preload(
	"res://scripts/ui/area_presentation_catalog.gd"
)

var _presentation: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(area_id: StringName) -> void:
	_presentation = AreaPresentation.new().find(area_id)
	queue_redraw()

func _draw() -> void:
	if _presentation.is_empty():
		return
	var primary: Color = _presentation["primary"]
	var secondary: Color = _presentation["secondary"]
	match _presentation["pattern"]:
		&"parallel_ledger":
			_draw_parallel_ledger(primary, secondary)
		&"mirror_axis":
			_draw_mirror_axis(primary, secondary)
		&"three_nodes":
			_draw_three_nodes(primary, secondary)

func _draw_parallel_ledger(primary: Color, secondary: Color) -> void:
	for index in range(9):
		var y := size.y * (0.12 + index * 0.095)
		draw_line(
			Vector2(size.x * 0.05, y),
			Vector2(size.x * 0.95, y),
			Color(primary, 0.055 if index % 2 == 0 else 0.025),
			2.0
		)
	for index in range(5):
		var x := size.x * (0.18 + index * 0.16)
		draw_circle(
			Vector2(x, size.y * (0.18 + index * 0.13)),
			5.0,
			Color(secondary, 0.18)
		)

func _draw_mirror_axis(primary: Color, secondary: Color) -> void:
	var center_x := size.x * 0.5
	draw_line(
		Vector2(center_x, size.y * 0.05),
		Vector2(center_x, size.y * 0.95),
		Color(primary, 0.14),
		2.0
	)
	for index in range(1, 7):
		var spread := size.x * 0.065 * index
		var top := size.y * (0.08 + index * 0.055)
		var bottom := size.y * (0.92 - index * 0.045)
		draw_line(
			Vector2(center_x - spread, top),
			Vector2(center_x - spread * 0.42, bottom),
			Color(secondary, 0.045),
			2.0
		)
		draw_line(
			Vector2(center_x + spread, top),
			Vector2(center_x + spread * 0.42, bottom),
			Color(primary, 0.045),
			2.0
		)

func _draw_three_nodes(primary: Color, secondary: Color) -> void:
	var center := size * 0.5
	for radius in [size.y * 0.12, size.y * 0.22, size.y * 0.34]:
		draw_arc(center, radius, 0.0, TAU, 72, Color(primary, 0.035), 2.0)
	for angle in [-PI * 0.5, PI / 6.0, PI * 5.0 / 6.0]:
		var point := center + Vector2.from_angle(angle) * size.y * 0.28
		draw_line(center, point, Color(secondary, 0.055), 2.0)
		draw_circle(point, 7.0, Color(primary, 0.18))
