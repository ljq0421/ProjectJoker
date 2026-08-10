class_name MirrorCopyResolver
extends RefCounted

const Modifiers = preload("res://scripts/run/area_run_modifier_catalog.gd")

func resolve(
	original: PlayedCard,
	state: RoundState,
	encounter: EncounterDefinition,
	context: ResolutionContext = null
) -> MirrorCopyResult:
	if original == null or original.definition == null:
		return MirrorCopyResult.new(false, false, null, "镜像来源手法牌缺失")
	if original.is_mirror_copy:
		return MirrorCopyResult.new(true)
	if encounter == null or encounter.rule_profile == null:
		return MirrorCopyResult.new(true)
	var profile := encounter.rule_profile
	if (
		not profile.mirror_first_table_card
		or profile.mirror_limit_per_round <= 0
		or original.definition.target_type != CardDefinition.TargetType.GAP
		or original.definition.mirror_effects.is_empty()
	):
		return MirrorCopyResult.new(true)
	if state == null:
		return MirrorCopyResult.new(false, false, null, "镜像回合状态缺失")
	var existing_copies := 0
	for played_card in state.played_cards:
		if played_card is PlayedCard and played_card.is_mirror_copy:
			existing_copies += 1
	if existing_copies >= profile.mirror_limit_per_round:
		return MirrorCopyResult.new(true)

	var targets := _reflected_targets(
		original.primary_target,
		original.secondary_target
	)
	if targets.is_empty():
		return MirrorCopyResult.new(
			false,
			false,
			null,
			"镜像桌间槽必须连接相邻规则轨"
		)

	var copy := PlayedCard.new(
		original.definition,
		targets[0],
		targets[1]
	)
	copy.play_id = (
		StringName("%s_mirror" % original.play_id)
		if original.play_id != &""
		else &"mirror_copy"
	)
	copy.is_mirror_copy = true
	copy.source_card_id = original.definition.id
	copy.source_play_id = original.play_id
	copy.source_slot_id = _source_slot_id(
		original.primary_target,
		original.secondary_target
	)
	var copy_effects := original.definition.mirror_effects
	if (
		context != null
		and context.has_area_modifier(Modifiers.MIRROR_TWIN_ECHO)
	):
		copy_effects = original.definition.effects
	for effect in copy_effects:
		copy.runtime_effects.append(_clone_effect(effect))
	return MirrorCopyResult.new(true, true, copy)

func _reflected_targets(
	primary: StringName,
	secondary: StringName
) -> Array[StringName]:
	if primary == &"left" and secondary == &"middle":
		return [&"right", &"middle"]
	if primary == &"middle" and secondary == &"right":
		return [&"middle", &"left"]
	return []

func _source_slot_id(
	primary: StringName,
	secondary: StringName
) -> StringName:
	if primary == &"left" and secondary == &"middle":
		return &"left_gap"
	if primary == &"middle" and secondary == &"right":
		return &"right_gap"
	return &""

func _clone_effect(effect: EffectSpec) -> EffectSpec:
	var copy := EffectSpec.new()
	copy.operation = effect.operation
	copy.amount = effect.amount
	return copy
