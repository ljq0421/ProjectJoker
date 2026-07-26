class_name EngravingInstallationService
extends RefCounted

class InstallationResult extends RefCounted:
	var accepted: bool
	var reason: String
	var profiles: Array[DieState]

	func _init(
		p_accepted: bool,
		p_reason: String = "",
		p_profiles: Array[DieState] = []
	) -> void:
		accepted = p_accepted
		reason = p_reason
		profiles = p_profiles

func install(
	profiles: Array[DieState],
	offer_ids: Array[StringName],
	selected_id: StringName,
	die_id: StringName,
	face: int,
	catalog: EngravingCatalog
) -> InstallationResult:
	if selected_id not in offer_ids:
		return InstallationResult.new(false, "待安装刻印不在本次候选中")
	if catalog == null or catalog.find_engraving(selected_id) == null:
		return InstallationResult.new(false, "待安装刻印定义不存在")
	if not _is_die_id(die_id):
		return InstallationResult.new(false, "刻印目标骰子不存在")
	if face < 1 or face > 6:
		return InstallationResult.new(false, "刻印骰面必须在 1 到 6 之间")
	var profile_error := _profiles_error(profiles, catalog)
	if not profile_error.is_empty():
		return InstallationResult.new(false, profile_error)

	var copies: Array[DieState] = []
	for profile in profiles:
		copies.append(profile.clone())
	var target := _find_profile(copies, die_id)
	if target == null:
		return InstallationResult.new(false, "刻印目标骰子配置不存在")
	if target.engraving_id != &"":
		return InstallationResult.new(false, "这颗骰子已经安装刻印")
	target.engraving_id = selected_id
	target.engraved_face = face
	return InstallationResult.new(true, "", copies)

func _profiles_error(
	profiles: Array[DieState],
	catalog: EngravingCatalog
) -> String:
	if profiles.size() != 6:
		return "骰子配置必须包含 d1 到 d6 六颗骰子"
	var seen: Dictionary = {}
	for profile in profiles:
		if profile == null:
			return "骰子配置包含无效条目"
		if not _is_die_id(profile.id) or seen.has(profile.id):
			return "骰子配置包含未知或重复骰子"
		seen[profile.id] = true
		if profile.engraving_id == &"":
			if profile.engraved_face != 0:
				return "未刻印骰子的刻印面必须为 0"
		elif (
			catalog.find_engraving(profile.engraving_id) == null
			or profile.engraved_face < 1
			or profile.engraved_face > 6
		):
			return "骰子配置包含未知刻印或非法刻印面"
	return ""

func _find_profile(
	profiles: Array[DieState],
	die_id: StringName
) -> DieState:
	for profile in profiles:
		if profile.id == die_id:
			return profile
	return null

func _is_die_id(die_id: StringName) -> bool:
	return die_id in [&"d1", &"d2", &"d3", &"d4", &"d5", &"d6"]
