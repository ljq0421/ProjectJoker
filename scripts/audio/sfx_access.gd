class_name SfxAccess
extends RefCounted

static func play(context: Node, cue_id: StringName) -> bool:
	if context == null or not context.is_inside_tree():
		return false
	var service := context.get_tree().root.get_node_or_null("SfxService")
	if service == null or not service.has_method("play"):
		return false
	return bool(service.play(cue_id))
