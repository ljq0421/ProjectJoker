class_name AreaPresentationCatalog
extends RefCounted

const PRESENTATIONS := {
	&"gold_corridor": {
		"primary": Color("#e7b84b"),
		"secondary": Color("#55e7c5"),
		"background": Color("#07121c"),
		"pattern": &"parallel_ledger",
		"sigil": &"abacus",
		"eyebrow": "LEDGER / PARALLEL PROOF",
	},
	&"mirror_hall": {
		"primary": Color("#79d8ff"),
		"secondary": Color("#b57aff"),
		"background": Color("#090b24"),
		"pattern": &"mirror_axis",
		"sigil": &"mirror",
		"eyebrow": "REFLECTION / REVERSE ORDER",
	},
	&"faceless_hub": {
		"primary": Color("#ff71b7"),
		"secondary": Color("#65eedb"),
		"background": Color("#15091d"),
		"pattern": &"three_nodes",
		"sigil": &"faceless",
		"eyebrow": "PROTOCOL / THREE OPEN SEATS",
	},
}

func find(area_id: StringName) -> Dictionary:
	if not PRESENTATIONS.has(area_id):
		return {}
	return PRESENTATIONS[area_id].duplicate(true)
