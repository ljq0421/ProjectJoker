class_name InteractionMotionLayer
extends Control

const CARD_SCENE := preload("res://scenes/components/card_token.tscn")
const GLASS_CYAN := Color(0.68, 1.0, 0.96, 1.0)
const GLASS_VIOLET := Color(0.92, 0.72, 1.0, 1.0)

var _reduce_flashes := false
var _reduce_motion := false


func configure(accessibility: Dictionary) -> void:
	_reduce_flashes = bool(accessibility.get("reduce_flashes", false))
	_reduce_motion = bool(accessibility.get("disable_distortion", false))
	set_meta("motion_reduced", _reduce_motion)
	set_meta("flashes_reduced", _reduce_flashes)


func fly_die(
	texture: Texture2D,
	from_rect: Rect2,
	to_rect: Rect2,
	returning := false
) -> void:
	set_meta("last_motion_kind", &"die_return" if returning else &"die_land")
	if _reduce_motion or texture == null or not is_inside_tree():
		return
	var ghost := TextureRect.new()
	ghost.name = "ReturningDieGhost" if returning else "LandingDieGhost"
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.texture = texture
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.position = _local_point(from_rect.position)
	ghost.size = from_rect.size
	ghost.pivot_offset = ghost.size * 0.5
	ghost.z_index = 2
	add_child(ghost)

	var target_position := _local_point(to_rect.position)
	var travel := target_position - ghost.position
	var arc_lift := minf(42.0, maxf(18.0, travel.length() * 0.12))
	var midpoint := ghost.position + travel * 0.52 + Vector2(0.0, -arc_lift)
	var first_scale := Vector2(1.14, 1.14) if not returning else Vector2(0.92, 0.92)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "position", midpoint, 0.12)
	tween.parallel().tween_property(ghost, "scale", first_scale, 0.12)
	tween.parallel().tween_property(ghost, "rotation", -0.08 if returning else 0.08, 0.12)
	tween.tween_property(ghost, "position", target_position, 0.11).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(ghost, "size", to_rect.size, 0.11)
	tween.parallel().tween_property(ghost, "scale", Vector2(1.08, 0.9), 0.11)
	tween.parallel().tween_property(ghost, "rotation", 0.0, 0.11)
	tween.tween_property(ghost, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.09)
	tween.tween_callback(ghost.queue_free)


func fly_card(
	definition: CardDefinition,
	from_rect: Rect2,
	to_rect: Rect2
) -> void:
	set_meta("last_motion_kind", &"card_commit")
	if _reduce_motion or definition == null or not is_inside_tree():
		return
	var ghost: CardToken = CARD_SCENE.instantiate()
	ghost.name = "CommittedCardGhost"
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.position = _local_point(from_rect.position)
	ghost.size = from_rect.size
	ghost.custom_minimum_size = Vector2.ZERO
	ghost.z_index = 3
	add_child(ghost)
	ghost.bind_card(0, definition, false, false)
	ghost.set_motion_reduced(true)
	ghost.pivot_offset = ghost.size * 0.5

	var target_position := _local_point(to_rect.position + to_rect.size * 0.5)
	target_position -= ghost.size * 0.5
	var midpoint := ghost.position.lerp(target_position, 0.58) + Vector2(0.0, -34.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "position", midpoint, 0.13)
	tween.parallel().tween_property(ghost, "scale", Vector2(1.08, 1.08), 0.13)
	tween.parallel().tween_property(ghost, "rotation", -0.035, 0.13)
	tween.tween_property(ghost, "position", target_position, 0.12).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(ghost, "scale", Vector2(0.54, 0.54), 0.12)
	tween.parallel().tween_property(ghost, "rotation", 0.025, 0.12)
	tween.parallel().tween_property(ghost, "modulate", GLASS_VIOLET, 0.12)
	tween.tween_property(ghost, "scale", Vector2(0.28, 0.78), 0.08)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.08)
	tween.tween_callback(ghost.queue_free)


func pulse_target(target: Control, emphasis: StringName = &"standard") -> void:
	set_meta("last_target_emphasis", emphasis)
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return
	target.set_meta("last_motion_emphasis", emphasis)
	if _reduce_motion and _reduce_flashes:
		return
	var original_scale := target.scale
	var original_modulate := target.modulate
	target.pivot_offset = target.size * 0.5
	var peak_scale: Vector2 = {
		&"muted": Vector2(1.01, 1.01),
		&"standard": Vector2(1.035, 1.035),
		&"impact": Vector2(1.065, 1.065),
		&"climax": Vector2(1.1, 1.1),
	}.get(emphasis, Vector2(1.035, 1.035))
	var peak_color: Color = (
		GLASS_VIOLET
		if emphasis in [&"impact", &"climax"]
		else GLASS_CYAN
	)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not _reduce_motion:
		target.scale = peak_scale
		tween.tween_property(target, "scale", original_scale, 0.2)
	if not _reduce_flashes:
		target.modulate = peak_color
		tween.tween_property(target, "modulate", original_modulate, 0.24)


func reject_target(target: Control) -> void:
	set_meta("last_motion_kind", &"rejected")
	if target == null or _reduce_motion or not target.is_inside_tree():
		return
	target.pivot_offset = target.size * 0.5
	var tween := create_tween()
	tween.tween_property(target, "rotation", -0.025, 0.045)
	tween.tween_property(target, "rotation", 0.025, 0.065)
	tween.tween_property(target, "rotation", -0.012, 0.055)
	tween.tween_property(target, "rotation", 0.0, 0.045)


func _local_point(global_point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_point
