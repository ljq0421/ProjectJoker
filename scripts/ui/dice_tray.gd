class_name DiceTray
extends HBoxContainer

signal die_return_requested(die_id: StringName)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "die"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	die_return_requested.emit(data.get("die_id"))
