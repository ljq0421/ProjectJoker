class_name EngineTechniqueDefinition
extends Resource

enum SocketType { ANY, ODD, EVEN, EXACT }

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var socket_type: SocketType = SocketType.ANY
@export var socket_value := 0
@export var lane_tags: Array[StringName] = []
@export var base_profile: Dictionary = {}
@export var upgrade_a_profile: Dictionary = {}
@export var upgrade_b_profile: Dictionary = {}

func accepts(value: int) -> bool:
	match socket_type:
		SocketType.ODD:
			return value % 2 == 1
		SocketType.EVEN:
			return value % 2 == 0
		SocketType.EXACT:
			return value == socket_value
		_:
			return value >= 1 and value <= 6

func socket_copy() -> String:
	match socket_type:
		SocketType.ODD:
			return "奇数骰"
		SocketType.EVEN:
			return "偶数骰"
		SocketType.EXACT:
			return "点数 %d" % socket_value
		_:
			return "任意骰"

func profile_for(branch: StringName) -> Dictionary:
	if branch == &"a":
		return upgrade_a_profile
	if branch == &"b":
		return upgrade_b_profile
	return base_profile

func returns_die_for(branch: StringName) -> bool:
	return bool(profile_for(branch).get("returns_die", true))

func branch_name(branch: StringName) -> String:
	return String(profile_for(branch).get("name", display_name))

func branch_description(branch: StringName) -> String:
	return String(profile_for(branch).get("description", description))

func lane_tag_copy() -> String:
	var labels: Array[String] = []
	for lane_id in lane_tags:
		match lane_id:
			&"attack":
				labels.append("破绽")
			&"guard":
				labels.append("护契")
			&"engine":
				labels.append("引擎")
	return " / ".join(labels)
