class_name DealerSigil
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
	var sigil_rect := _watermark_rect()
	match _presentation["sigil"]:
		&"abacus":
			_draw_abacus(sigil_rect, primary, secondary)
		&"mirror":
			_draw_mirror(sigil_rect, primary, secondary)
		&"faceless":
			_draw_faceless(sigil_rect, primary, secondary)

func _watermark_rect() -> Rect2:
	var extent := minf(116.0, size.x * 0.58)
	var center := Vector2(size.x * 0.5, size.y * 0.58)
	return Rect2(center - Vector2.ONE * extent * 0.5, Vector2.ONE * extent)

func _draw_abacus(rect: Rect2, primary: Color, secondary: Color) -> void:
	var left := rect.position.x + rect.size.x * 0.12
	var right := rect.end.x - rect.size.x * 0.12
	for index in range(3):
		var y := rect.position.y + rect.size.y * (0.28 + index * 0.22)
		draw_line(Vector2(left, y), Vector2(right, y), Color(primary, 0.72), 3.0)
		for bead in range(index + 2):
			var x := lerpf(left, right, float(bead + 1) / float(index + 3))
			draw_circle(Vector2(x, y), 7.0, Color(secondary, 0.9))

func _draw_mirror(rect: Rect2, primary: Color, secondary: Color) -> void:
	var center := rect.get_center()
	var points := PackedVector2Array([
		Vector2(center.x, rect.position.y + rect.size.y * 0.12),
		Vector2(rect.position.x + rect.size.x * 0.78, center.y),
		Vector2(center.x, rect.position.y + rect.size.y * 0.88),
		Vector2(rect.position.x + rect.size.x * 0.22, center.y),
		Vector2(center.x, rect.position.y + rect.size.y * 0.12),
	])
	draw_polyline(points, Color(primary, 0.9), 3.0)
	draw_line(
		Vector2(center.x, rect.position.y + rect.size.y * 0.12),
		Vector2(center.x, rect.position.y + rect.size.y * 0.88),
		Color(secondary, 0.9),
		2.0
	)
	draw_arc(
		center,
		rect.size.y * 0.19,
		-PI * 0.5,
		PI * 0.5,
		24,
		Color(primary, 0.5),
		2.0
	)
	draw_arc(
		center,
		rect.size.y * 0.19,
		PI * 0.5,
		PI * 1.5,
		24,
		Color(secondary, 0.5),
		2.0
	)

func _draw_faceless(rect: Rect2, primary: Color, secondary: Color) -> void:
	var center := rect.get_center()
	draw_arc(
		center,
		rect.size.y * 0.34,
		0.0,
		TAU,
		48,
		Color(primary, 0.88),
		3.0
	)
	draw_arc(
		center,
		rect.size.y * 0.19,
		0.0,
		TAU,
		36,
		Color(secondary, 0.46),
		2.0
	)
	for angle in [-PI * 0.5, PI / 6.0, PI * 5.0 / 6.0]:
		var point := center + Vector2.from_angle(angle) * rect.size.y * 0.34
		draw_circle(point, 6.0, Color(secondary, 0.95))
