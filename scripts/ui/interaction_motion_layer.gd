class_name InteractionMotionLayer
extends Control

const CARD_SCENE := preload("res://scenes/components/card_token.tscn")
const FeedbackCueModel := preload("res://scripts/ui/feedback_cue.gd")
const GLASS_CYAN := Color(0.68, 1.0, 0.96, 1.0)
const GLASS_VIOLET := Color(0.92, 0.72, 1.0, 1.0)
const RULE_SUCCESS := Color(0.56, 1.0, 0.72, 1.0)
const RULE_FAILURE := Color(1.0, 0.38, 0.48, 1.0)
const RULE_NEUTRAL := Color(0.68, 0.72, 0.82, 1.0)
const DIE_CONTACT_SCALE := Vector2(1.06, 1.06)
const RESPONSE_STEP_SECONDS := 0.08
const RULE_EVALUATION_STEP_SECONDS := 0.08

var _reduce_flashes := false
var _reduce_motion := false
var _response_tween: Tween
var _rule_evaluation_tween: Tween
var _climax_tween: Tween
var _climax_overlay: Control
var _climax_finished := Callable()
var _feedback_queue: Array[Dictionary] = []
var _active_feedback
var _area_id: StringName = &"gold_corridor"


func configure(accessibility: Dictionary) -> void:
	_reduce_flashes = bool(accessibility.get("reduce_flashes", false))
	_reduce_motion = bool(accessibility.get("disable_distortion", false))
	set_meta("motion_reduced", _reduce_motion)
	set_meta("flashes_reduced", _reduce_flashes)

func set_area_id(area_id: StringName) -> void:
	_area_id = area_id

func enqueue_feedback(cue, runner: Callable) -> void:
	if cue == null or not runner.is_valid():
		return
	_feedback_queue.append({"cue": cue, "runner": runner})
	_feedback_queue.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return int(left["cue"].priority) > int(right["cue"].priority)
	)
	set_meta("feedback_queue_size", _feedback_queue.size())
	_start_next_feedback()

func active_feedback_priority() -> int:
	return int(_active_feedback.priority) if _active_feedback != null else -1

func finish_active_feedback() -> void:
	if _climax_overlay != null and is_instance_valid(_climax_overlay):
		finish_resolution_climax_for_test()
		return
	if _response_tween != null and _response_tween.is_valid():
		_response_tween.kill()
	if _rule_evaluation_tween != null and _rule_evaluation_tween.is_valid():
		_rule_evaluation_tween.kill()
	_complete_active_feedback()

func cancel_rare_highlights() -> void:
	var retained: Array[Dictionary] = []
	for entry in _feedback_queue:
		if int(entry["cue"].priority) != FeedbackCueModel.Priority.RARE_HIGHLIGHT:
			retained.append(entry)
	_feedback_queue = retained
	set_meta("feedback_queue_size", _feedback_queue.size())
	if (
		_active_feedback != null
		and int(_active_feedback.priority) == FeedbackCueModel.Priority.RARE_HIGHLIGHT
	):
		finish_active_feedback()

func show_score_delta(target: Control, delta: int, prefix := "预测") -> void:
	if target == null or not target.is_inside_tree() or delta == 0:
		return
	var badge := Label.new()
	badge.name = "PredictedDelta"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = "%s %+d" % [prefix, delta]
	badge.add_theme_font_size_override("font_size", 18)
	badge.add_theme_color_override(
		"font_color",
		RULE_SUCCESS if delta > 0 else RULE_FAILURE
	)
	badge.position = _local_point(target.get_global_rect().get_center()) + Vector2(18.0, -26.0)
	badge.z_index = 12
	add_child(badge)
	if _reduce_motion:
		badge.modulate.a = 0.88
		get_tree().create_timer(0.3).timeout.connect(badge.queue_free)
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(badge, "position:y", badge.position.y - 22.0, 0.3)
	tween.tween_property(badge, "modulate:a", 0.0, 0.3).set_delay(0.08)
	tween.chain().tween_callback(badge.queue_free)

func _start_next_feedback() -> void:
	if _active_feedback != null or _feedback_queue.is_empty():
		return
	var entry: Dictionary = _feedback_queue.pop_front()
	_active_feedback = entry["cue"]
	set_meta("active_feedback_kind", _active_feedback.kind)
	set_meta("active_feedback_priority", _active_feedback.priority)
	set_meta("feedback_queue_size", _feedback_queue.size())
	(entry["runner"] as Callable).call()

func _complete_active_feedback() -> void:
	_active_feedback = null
	set_meta("active_feedback_kind", &"")
	set_meta("active_feedback_priority", -1)
	_start_next_feedback()


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
	tween.tween_property(ghost, "position", midpoint, 0.11)
	tween.parallel().tween_property(ghost, "scale", first_scale, 0.11)
	tween.parallel().tween_property(ghost, "rotation", -0.08 if returning else 0.08, 0.11)
	tween.tween_property(ghost, "position", target_position, 0.11).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(ghost, "size", to_rect.size, 0.11)
	tween.parallel().tween_property(ghost, "scale", DIE_CONTACT_SCALE, 0.11)
	tween.parallel().tween_property(ghost, "rotation", 0.0, 0.11)
	tween.tween_property(ghost, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.08)
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
	tween.tween_property(ghost, "position", midpoint, 0.11)
	tween.parallel().tween_property(ghost, "scale", Vector2(1.08, 1.08), 0.11)
	tween.parallel().tween_property(ghost, "rotation", -0.035, 0.11)
	tween.tween_property(ghost, "position", target_position, 0.11).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(ghost, "scale", Vector2(0.54, 0.54), 0.11)
	tween.parallel().tween_property(ghost, "rotation", 0.025, 0.11)
	tween.parallel().tween_property(ghost, "modulate", GLASS_VIOLET, 0.11)
	tween.tween_property(ghost, "scale", Vector2(0.28, 0.78), 0.07)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.07)
	tween.tween_callback(ghost.queue_free)


func pulse_target(
	target: Control,
	emphasis: StringName = &"standard",
	peak_override: Color = Color.TRANSPARENT,
	suppress_color_flash := false
) -> void:
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
	var peak_color: Color = peak_override if peak_override.a > 0.0 else (
		GLASS_VIOLET
		if emphasis in [&"impact", &"climax"]
		else GLASS_CYAN
	)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not _reduce_motion:
		target.scale = peak_scale
		tween.tween_property(target, "scale", original_scale, 0.28)
	if not _reduce_flashes and not suppress_color_flash:
		target.modulate = peak_color
		tween.tween_property(target, "modulate", original_modulate, 0.3)


func play_response_sequence(stages: Array, initial_delay := 0.0) -> void:
	if _response_tween != null and _response_tween.is_valid():
		_response_tween.kill()
	var valid_stages: Array[Dictionary] = []
	var roles: Array[StringName] = []
	var tones: Array[StringName] = []
	for raw_stage in stages:
		if raw_stage is not Dictionary:
			continue
		var target := raw_stage.get("target") as Control
		if target == null or not is_instance_valid(target):
			continue
		var role: StringName = raw_stage.get("role", &"affected")
		var tone: StringName = raw_stage.get("tone", &"neutral")
		valid_stages.append({
			"instance_id": target.get_instance_id(),
			"role": role,
			"tone": tone,
		})
		roles.append(role)
		tones.append(tone)
	set_meta("last_response_sequence", roles)
	set_meta("last_response_tones", tones)
	if valid_stages.is_empty() or not is_inside_tree():
		return
	var cue = FeedbackCueModel.new(
		&"response_sequence",
		null,
		null,
		0,
		&"neutral",
		FeedbackCueModel.Priority.OPERATION_CONFIRMATION
	)
	enqueue_feedback(
		cue,
		_start_response_sequence.bind(valid_stages, initial_delay)
	)

func _start_response_sequence(valid_stages: Array[Dictionary], initial_delay: float) -> void:
	_spawn_contract_trace(valid_stages)
	_response_tween = create_tween()
	if initial_delay > 0.0:
		_response_tween.tween_interval(initial_delay)
	for index in range(valid_stages.size()):
		var stage := valid_stages[index]
		_response_tween.tween_callback(
			_pulse_response_stage.bind(
				int(stage["instance_id"]),
				stage["role"] as StringName,
				stage["tone"] as StringName
			)
		)
		if index + 1 < valid_stages.size():
			_response_tween.tween_interval(RESPONSE_STEP_SECONDS)
	_response_tween.tween_callback(_complete_active_feedback)

func _spawn_contract_trace(valid_stages: Array[Dictionary]) -> void:
	if valid_stages.size() < 2 or _reduce_flashes:
		return
	var previous := get_node_or_null("ContractTrace")
	if previous != null:
		previous.queue_free()
	var trace := Line2D.new()
	trace.name = "ContractTrace"
	trace.width = 2.0
	trace.default_color = _area_trace_color()
	trace.antialiased = true
	trace.z_index = 5
	for stage in valid_stages:
		var instance_id := int(stage.get("instance_id", 0))
		if not is_instance_id_valid(instance_id):
			continue
		var target := instance_from_id(instance_id) as Control
		if target != null and target.is_inside_tree():
			trace.add_point(_local_point(target.get_global_rect().get_center()))
	if trace.get_point_count() < 2:
		trace.free()
		return
	add_child(trace)
	var tween := create_tween()
	tween.tween_property(trace, "modulate:a", 0.0, 0.3).set_delay(0.12)
	tween.tween_callback(trace.queue_free)

func _area_trace_color() -> Color:
	return {
		&"gold_corridor": Color("e7b84b"),
		&"mirror_hall": Color("79d8ff"),
		&"faceless_hub": Color("ff71b7"),
	}.get(_area_id, GLASS_CYAN)


func play_rule_evaluation_feedback(entries: Array) -> void:
	if _rule_evaluation_tween != null and _rule_evaluation_tween.is_valid():
		_rule_evaluation_tween.kill()
	var valid_entries: Array[Dictionary] = []
	var target_ids: Array[int] = []
	var tones: Array[StringName] = []
	var seen_targets: Dictionary = {}
	for raw_entry in entries:
		if raw_entry is not Dictionary:
			continue
		var target := raw_entry.get("target") as Control
		if target == null or not is_instance_valid(target):
			continue
		var instance_id := target.get_instance_id()
		if seen_targets.has(instance_id):
			continue
		seen_targets[instance_id] = true
		var tone: StringName = raw_entry.get("tone", &"neutral")
		valid_entries.append({
			"instance_id": instance_id,
			"tone": tone,
		})
		target_ids.append(instance_id)
		tones.append(tone)
	set_meta("last_rule_evaluation_targets", target_ids)
	set_meta("last_rule_evaluation_tones", tones)
	if valid_entries.is_empty() or not is_inside_tree():
		return
	var cue = FeedbackCueModel.new(
		&"rule_evaluation",
		null,
		null,
		0,
		&"neutral",
		FeedbackCueModel.Priority.AMBIENT_STATE
	)
	enqueue_feedback(cue, _start_rule_evaluation.bind(valid_entries))

func _start_rule_evaluation(valid_entries: Array[Dictionary]) -> void:
	_rule_evaluation_tween = create_tween()
	for index in range(valid_entries.size()):
		var entry := valid_entries[index]
		_rule_evaluation_tween.tween_callback(
			_pulse_rule_evaluation_stage.bind(
				int(entry["instance_id"]),
				entry["tone"] as StringName
			)
		)
		if index + 1 < valid_entries.size():
			_rule_evaluation_tween.tween_interval(
				RULE_EVALUATION_STEP_SECONDS
			)
	_rule_evaluation_tween.tween_callback(_complete_active_feedback)


func play_resolution_climax(
	total: int,
	on_finished: Callable = Callable()
) -> void:
	play_rare_highlight(&"storm", total, _area_id, on_finished)

func play_rare_highlight(
	kind: StringName,
	total: int,
	area_id: StringName = &"",
	on_finished: Callable = Callable()
) -> void:
	var cue = FeedbackCueModel.new(
		kind,
		null,
		null,
		0,
		&"rare",
		FeedbackCueModel.Priority.RARE_HIGHLIGHT,
		true
	)
	enqueue_feedback(
		cue,
		_start_resolution_climax.bind(
			total,
			kind,
			area_id if area_id != &"" else _area_id,
			on_finished
		)
	)

func _start_resolution_climax(
	total: int,
	kind: StringName,
	area_id: StringName,
	on_finished: Callable = Callable()
) -> void:
	if _climax_overlay != null and is_instance_valid(_climax_overlay):
		_finish_resolution_climax()
	_climax_finished = on_finished
	set_meta("last_resolution_climax_total", total)
	set_meta("last_rare_highlight_kind", kind)
	set_meta("last_rare_highlight_area", area_id)
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
	var trace_texture := load(_area_trace_path(area_id)) as Texture2D
	if trace_texture != null:
		var trace := TextureRect.new()
		trace.name = "ContractTrace"
		trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trace.texture = trace_texture
		trace.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trace.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		trace.modulate.a = 0.54 if not _reduce_flashes else 0.24
		overlay.add_child(trace)
		trace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
	var seal_texture := load(_rare_seal_path(kind)) as Texture2D
	if seal_texture != null:
		var seal := TextureRect.new()
		seal.name = "RareSeal"
		seal.custom_minimum_size = Vector2(78.0, 78.0)
		seal.texture = seal_texture
		seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content.add_child(seal)

	var kicker := Label.new()
	kicker.text = _rare_title(kind)
	kicker.text = "本轮最终结算"
	kicker.text = _rare_title(kind)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_color_override("font_color", GLASS_CYAN)
	kicker.add_theme_font_size_override("font_size", 30)
	content.add_child(kicker)

	var total_label := Label.new()
	total_label.name = "ClimaxTotal"
	total_label.text = "★" if kind == &"achievement" else str(total)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_color_override("font_color", Color.WHITE)
	total_label.add_theme_font_size_override("font_size", 112)
	total_label.pivot_offset = total_label.size * 0.5
	content.add_child(total_label)

	var caption := Label.new()
	caption.text = "契据已入账"
	caption.text = "最终总分"
	caption.text = "契据已入账"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.text = "档案已解锁" if kind == &"achievement" else "契据已入账"
	caption.add_theme_color_override("font_color", GLASS_VIOLET)
	caption.add_theme_font_size_override("font_size", 24)
	content.add_child(caption)

	overlay.modulate.a = 0.0
	panel.scale = Vector2.ONE if _reduce_motion else Vector2(0.72, 0.72)
	_climax_tween = create_tween()
	_climax_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_climax_tween.tween_interval(0.06)
	_climax_tween.tween_callback(
		func() -> void: SfxAccess.play(self, _rare_sfx_cue(area_id))
	)
	_climax_tween.tween_property(overlay, "modulate:a", 1.0, 0.12)
	if not _reduce_motion:
		_climax_tween.parallel().tween_property(
			panel,
			"scale",
			Vector2(1.08, 1.08),
			0.24
		)
	_climax_tween.tween_interval(0.20)
	if not _reduce_motion:
		_climax_tween.tween_property(panel, "scale", Vector2.ONE, 0.10)
	_climax_tween.tween_interval(0.16)
	_climax_tween.tween_property(overlay, "modulate:a", 0.0, 0.16)
	_climax_tween.tween_callback(_finish_resolution_climax)


func finish_resolution_climax_for_test() -> void:
	if _climax_tween != null and _climax_tween.is_valid():
		_climax_tween.kill()
	_finish_resolution_climax()


func _pulse_response_stage(
	target_instance_id: int,
	role: StringName,
	tone: StringName = &"neutral"
) -> void:
	if not is_instance_id_valid(target_instance_id):
		return
	var target := instance_from_id(target_instance_id) as Control
	if target == null or not target.is_inside_tree():
		return
	target.set_meta("last_response_role", role)
	target.set_meta("last_response_tone", tone)
	var emphasis: StringName = {
		&"source": &"standard",
		&"affected": &"impact",
		&"rule": &"climax",
		&"prediction": &"climax",
	}.get(role, &"standard")
	var semantic_color := _rule_tone_color(tone) if role == &"rule" else Color.TRANSPARENT
	if role != &"rule":
		pulse_target(target, emphasis, semantic_color)
	_spawn_response_ring(target, role, tone)


func _pulse_rule_evaluation_stage(
	target_instance_id: int,
	tone: StringName
) -> void:
	if not is_instance_id_valid(target_instance_id):
		return
	var target := instance_from_id(target_instance_id) as Control
	if target == null or not target.is_inside_tree():
		return
	target.set_meta("last_response_role", &"rule")
	target.set_meta("last_response_tone", tone)
	_spawn_response_ring(target, &"rule", tone, true)


func _spawn_response_ring(
	target: Control,
	role: StringName,
	tone: StringName = &"neutral",
	unique_per_target := false
) -> void:
	if target == null or not target.is_inside_tree() or _reduce_flashes:
		return
	var node_name := "ResponsePulse_%s" % String(role)
	if unique_per_target:
		node_name += "_%d" % target.get_instance_id()
	var previous := get_node_or_null(NodePath(node_name))
	if previous != null:
		previous.free()
	var color: Color = _rule_tone_color(tone) if role == &"rule" else {
		&"source": GLASS_CYAN,
		&"affected": GLASS_VIOLET,
		&"prediction": Color(1.0, 0.9, 1.0, 1.0),
	}.get(role, GLASS_CYAN)
	var role_copy: String = {
		&"source": "来源",
		&"affected": "命中",
		&"prediction": "预测更新",
	}.get(role, "响应")
	var is_rule_response := role == &"rule"
	if is_rule_response:
		role_copy = {
			&"success": "规则满足",
			&"failure": "规则未满足",
			&"neutral": "规则更新",
		}.get(tone, "规则更新")
	var target_rect := _response_target_rect(target).grow(
		6.0 if is_rule_response else 4.0
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
		0.0 if is_rule_response else 0.08
	)
	style.border_color = color
	style.set_border_width_all(3 if is_rule_response else 2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(
		color.r,
		color.g,
		color.b,
		0.0 if is_rule_response else 0.48
	)
	style.shadow_size = 0 if is_rule_response else 8
	ring.add_theme_stylebox_override("panel", style)
	add_child(ring)

	var badge := Label.new()
	badge.name = "ResponseBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = role_copy
	if is_rule_response:
		badge.set_anchors_preset(Control.PRESET_TOP_WIDE)
		badge.offset_left = 24.0
		badge.offset_top = 8.0
		badge.offset_right = -24.0
		badge.offset_bottom = 38.0
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(
			color.r * 0.12,
			color.g * 0.12,
			color.b * 0.12,
			0.94
		)
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
	badge.add_theme_constant_override("outline_size", 3 if is_rule_response else 2)
	badge.add_theme_font_size_override("font_size", 16 if is_rule_response else 13)
	ring.add_child(badge)

	ring.scale = Vector2.ONE if _reduce_motion else Vector2(0.9, 0.9)
	var duration := 0.3 if is_rule_response else 0.24
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not _reduce_motion:
		tween.tween_property(
			ring,
			"scale",
			Vector2(1.035, 1.035) if is_rule_response else Vector2(1.05, 1.05),
			duration
		)
	tween.tween_property(ring, "modulate:a", 0.0, duration).set_delay(
		0.08 if is_rule_response else 0.0
	)
	tween.chain().tween_callback(ring.queue_free)

func _rule_tone_color(tone: StringName) -> Color:
	match tone:
		&"success":
			return RULE_SUCCESS
		&"failure":
			return RULE_FAILURE
	return RULE_NEUTRAL


func _response_target_rect(target: Control) -> Rect2:
	var die_token := target.get_parent() as DieToken
	if die_token != null and die_token.get_parent() is RuleSlot:
		return (die_token.get_parent() as Control).get_global_rect()
	return target.get_global_rect()

func _rare_title(kind: StringName) -> String:
	return {
		&"storm": "风暴契印",
		&"resonance": "同调共鸣",
		&"lucky": "满台幸运",
		&"engraving_set": "刻印套装",
		&"dealer_complete": "庄家契约完成",
		&"achievement": "新成就",
	}.get(kind, "稀有契印")

func _area_trace_path(area_id: StringName) -> String:
	return {
		&"gold_corridor": "res://resources/ui/dream_glass/feedback/trace_gold_corridor.svg",
		&"mirror_hall": "res://resources/ui/dream_glass/feedback/trace_mirror_hall.svg",
		&"faceless_hub": "res://resources/ui/dream_glass/feedback/trace_faceless_hub.svg",
	}.get(area_id, "res://resources/ui/dream_glass/feedback/trace_gold_corridor.svg")

func _rare_seal_path(kind: StringName) -> String:
	return "res://resources/ui/dream_glass/feedback/seal_%s.svg" % {
		&"storm": "storm",
		&"resonance": "resonance",
		&"lucky": "lucky",
		&"engraving_set": "engraving_set",
		&"dealer_complete": "dealer",
		&"achievement": "achievement",
	}.get(kind, "achievement")

func _rare_sfx_cue(area_id: StringName) -> StringName:
	return {
		&"gold_corridor": &"feedback_gold_highlight",
		&"mirror_hall": &"feedback_mirror_highlight",
		&"faceless_hub": &"feedback_faceless_highlight",
	}.get(area_id, &"resolution_climax")


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
	_complete_active_feedback()


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
