class_name InteractionMotionLayer
extends Control

const CARD_SCENE := preload("res://scenes/components/card_token.tscn")
const GLASS_CYAN := Color(0.68, 1.0, 0.96, 1.0)
const GLASS_VIOLET := Color(0.92, 0.72, 1.0, 1.0)
const DIE_CONTACT_SCALE := Vector2(1.06, 1.06)
const RESPONSE_STEP_SECONDS := 0.16

var _reduce_flashes := false
var _reduce_motion := false
var _response_tween: Tween
var _climax_tween: Tween
var _climax_overlay: Control
var _climax_finished := Callable()


func configure(accessibility: Dictionary) -> void:
	_reduce_flashes = bool(accessibility.get("reduce_flashes", false))
	_reduce_motion = bool(accessibility.get("disable_distortion", false))
	set_meta("motion_reduced", _reduce_motion)
	set_meta("flashes_reduced", _reduce_flashes)


func fly_die(
	texture: Texture2D,
	from_rect: Rect2,
	to_rect: Rect2,
	returning := false,
	on_arrival: Callable = Callable()
) -> void:
	set_meta("last_motion_kind", &"die_return" if returning else &"die_land")
	if _reduce_motion or texture == null or not is_inside_tree():
		if on_arrival.is_valid():
			on_arrival.call()
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
	tween.parallel().tween_property(ghost, "scale", DIE_CONTACT_SCALE, 0.11)
	tween.parallel().tween_property(ghost, "rotation", 0.0, 0.11)
	tween.tween_property(ghost, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.09)
	tween.tween_callback(ghost.queue_free)
	if on_arrival.is_valid():
		tween.tween_callback(on_arrival)


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
		&"muted": Vector2(1.025, 1.025),
		&"standard": Vector2(1.065, 1.065),
		&"impact": Vector2(1.1, 1.1),
		&"climax": Vector2(1.16, 1.16),
	}.get(emphasis, Vector2(1.065, 1.065))
	var peak_color: Color = (
		GLASS_VIOLET
		if emphasis in [&"impact", &"climax"]
		else GLASS_CYAN
	)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not _reduce_motion:
		target.scale = peak_scale
		tween.tween_property(target, "scale", original_scale, 0.28)
	if not _reduce_flashes:
		target.modulate = peak_color
		tween.tween_property(target, "modulate", original_modulate, 0.3)


func play_response_sequence(stages: Array, initial_delay := 0.0) -> void:
	if _response_tween != null and _response_tween.is_valid():
		_response_tween.kill()
	var valid_stages: Array[Dictionary] = []
	var roles: Array[StringName] = []
	for raw_stage in stages:
		if raw_stage is not Dictionary:
			continue
		var target := raw_stage.get("target") as Control
		if target == null or not is_instance_valid(target):
			continue
		var role: StringName = raw_stage.get("role", &"affected")
		valid_stages.append({
			"instance_id": target.get_instance_id(),
			"role": role,
		})
		roles.append(role)
	set_meta("last_response_sequence", roles)
	if valid_stages.is_empty() or not is_inside_tree():
		return
	_response_tween = create_tween()
	if initial_delay > 0.0:
		_response_tween.tween_interval(initial_delay)
	for index in range(valid_stages.size()):
		var stage := valid_stages[index]
		_response_tween.tween_callback(
			_pulse_response_stage.bind(
				int(stage["instance_id"]),
				stage["role"] as StringName
			)
		)
		if index + 1 < valid_stages.size():
			_response_tween.tween_interval(RESPONSE_STEP_SECONDS)


func play_resolution_climax(
	total: int,
	on_finished: Callable = Callable()
) -> void:
	if _climax_overlay != null and is_instance_valid(_climax_overlay):
		_finish_resolution_climax()
	_climax_finished = on_finished
	set_meta("last_resolution_climax_total", total)
	set_meta("resolution_climax_active", true)

	var overlay := Control.new()
	overlay.name = "ResolutionClimaxOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_climax_overlay = overlay

	var backdrop := ColorRect.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.color = Color(0.015, 0.01, 0.06, 0.82)
	overlay.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-280.0, -170.0)
	panel.size = Vector2(560.0, 340.0)
	panel.pivot_offset = panel.size * 0.5
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.025, 0.14, 0.96)
	panel_style.border_color = GLASS_VIOLET
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(28)
	panel_style.shadow_color = Color(0.55, 0.18, 0.85, 0.52)
	panel_style.shadow_size = 28
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var kicker := Label.new()
	kicker.text = "本轮最终结算"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_color_override("font_color", GLASS_CYAN)
	kicker.add_theme_font_size_override("font_size", 30)
	content.add_child(kicker)

	var total_label := Label.new()
	total_label.name = "ClimaxTotal"
	total_label.text = str(total)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_color_override("font_color", Color.WHITE)
	total_label.add_theme_font_size_override("font_size", 112)
	total_label.pivot_offset = total_label.size * 0.5
	content.add_child(total_label)

	var caption := Label.new()
	caption.text = "最终总分"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", GLASS_VIOLET)
	caption.add_theme_font_size_override("font_size", 24)
	content.add_child(caption)

	overlay.modulate.a = 0.0
	panel.scale = Vector2.ONE if _reduce_motion else Vector2(0.72, 0.72)
	_climax_tween = create_tween()
	_climax_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_climax_tween.tween_interval(0.24)
	_climax_tween.tween_callback(
		func() -> void: SfxAccess.play(self, &"resolution_climax")
	)
	_climax_tween.tween_property(overlay, "modulate:a", 1.0, 0.18)
	if not _reduce_motion:
		_climax_tween.parallel().tween_property(
			panel,
			"scale",
			Vector2(1.08, 1.08),
			0.34
		)
	_climax_tween.tween_interval(0.42)
	if not _reduce_motion:
		_climax_tween.tween_property(panel, "scale", Vector2.ONE, 0.14)
	_climax_tween.tween_interval(0.34)
	_climax_tween.tween_property(overlay, "modulate:a", 0.0, 0.22)
	_climax_tween.tween_callback(_finish_resolution_climax)


func finish_resolution_climax_for_test() -> void:
	if _climax_tween != null and _climax_tween.is_valid():
		_climax_tween.kill()
	_finish_resolution_climax()


func _pulse_response_stage(target_instance_id: int, role: StringName) -> void:
	if not is_instance_id_valid(target_instance_id):
		return
	var target := instance_from_id(target_instance_id) as Control
	if target == null or not target.is_inside_tree():
		return
	target.set_meta("last_response_role", role)
	var emphasis: StringName = {
		&"source": &"standard",
		&"affected": &"impact",
		&"rule": &"climax",
		&"prediction": &"climax",
	}.get(role, &"standard")
	pulse_target(target, emphasis)
	_spawn_response_ring(target, role)


func _spawn_response_ring(target: Control, role: StringName) -> void:
	if target == null or not target.is_inside_tree() or _reduce_flashes:
		return
	var node_name := "ResponsePulse_%s" % String(role)
	var previous := get_node_or_null(NodePath(node_name))
	if previous != null:
		previous.free()
	var color: Color = {
		&"source": GLASS_CYAN,
		&"affected": GLASS_VIOLET,
		&"rule": Color(1.0, 0.76, 0.34, 1.0),
		&"prediction": Color(1.0, 0.9, 1.0, 1.0),
	}.get(role, GLASS_CYAN)
	var role_copy: String = {
		&"source": "来源",
		&"affected": "命中",
		&"rule": "规则响应",
		&"prediction": "预测更新",
	}.get(role, "响应")
	var is_rule_response := role == &"rule"
	var target_rect := _response_target_rect(target).grow(
		18.0 if is_rule_response else 10.0
	)
	var ring := Panel.new()
	ring.name = node_name
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = _local_point(target_rect.position)
	ring.size = target_rect.size
	ring.pivot_offset = ring.size * 0.5
	ring.z_index = 6
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		color.r,
		color.g,
		color.b,
		0.18 if is_rule_response else 0.08
	)
	style.border_color = color
	style.set_border_width_all(8 if is_rule_response else 5)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(
		color.r,
		color.g,
		color.b,
		0.78 if is_rule_response else 0.48
	)
	style.shadow_size = 26 if is_rule_response else 14
	ring.add_theme_stylebox_override("panel", style)
	add_child(ring)

	var badge := Label.new()
	badge.name = "ResponseBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = "规则台已响应" if is_rule_response else role_copy
	if is_rule_response:
		badge.set_anchors_preset(Control.PRESET_TOP_WIDE)
		badge.offset_left = 34.0
		badge.offset_top = 14.0
		badge.offset_right = -34.0
		badge.offset_bottom = 52.0
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(0.12, 0.055, 0.03, 0.94)
		badge_style.border_color = color
		badge_style.set_border_width_all(2)
		badge_style.set_corner_radius_all(12)
		badge.add_theme_stylebox_override("normal", badge_style)
	else:
		badge.position = Vector2(10.0, -30.0)
	badge.add_theme_color_override("font_color", color)
	badge.add_theme_color_override(
		"font_outline_color",
		Color(0.03, 0.015, 0.08, 0.96)
	)
	badge.add_theme_constant_override("outline_size", 5 if is_rule_response else 3)
	badge.add_theme_font_size_override("font_size", 24 if is_rule_response else 16)
	ring.add_child(badge)

	ring.scale = Vector2.ONE if _reduce_motion else Vector2(0.9, 0.9)
	var duration := 0.78 if is_rule_response else 0.48
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not _reduce_motion:
		tween.tween_property(
			ring,
			"scale",
			Vector2(1.13, 1.13) if is_rule_response else Vector2(1.08, 1.08),
			duration
		)
	tween.tween_property(ring, "modulate:a", 0.0, duration).set_delay(
		0.22 if is_rule_response else 0.0
	)
	tween.chain().tween_callback(ring.queue_free)


func _response_target_rect(target: Control) -> Rect2:
	var die_token := target.get_parent() as DieToken
	if die_token != null and die_token.get_parent() is RuleSlot:
		return (die_token.get_parent() as Control).get_global_rect()
	return target.get_global_rect()


func _finish_resolution_climax() -> void:
	_climax_tween = null
	if _climax_overlay != null and is_instance_valid(_climax_overlay):
		_climax_overlay.free()
	_climax_overlay = null
	set_meta("resolution_climax_active", false)
	var finished := _climax_finished
	_climax_finished = Callable()
	if finished.is_valid():
		finished.call()


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
