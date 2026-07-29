class_name RuleArchiveCatalog
extends RefCounted

const PATHS := [
	"res://resources/rule_archive/archive_01_point_thresholds.tres",
	"res://resources/rule_archive/archive_02_set_relations.tres",
	"res://resources/rule_archive/archive_03_parity.tres",
	"res://resources/rule_archive/archive_04_sequences.tres",
	"res://resources/rule_archive/archive_05_positions.tres",
	"res://resources/rule_archive/archive_06_distortions.tres",
]

var _entries: Array[RuleArchiveDefinition] = []
var _load_errors: Array[String] = []

func _init() -> void:
	for path in PATHS:
		var resource := load(path)
		if resource is RuleArchiveDefinition:
			_entries.append(resource)
		else:
			_load_errors.append("failed to load rule archive: %s" % path)

func all_entries() -> Array[RuleArchiveDefinition]:
	return _entries.duplicate()

func find_entry(archive_id: StringName) -> RuleArchiveDefinition:
	for entry in _entries:
		if entry.id == archive_id:
			return entry
	return null

func validate(card_catalog: CardCatalog = null) -> Array[String]:
	var errors: Array[String] = _load_errors.duplicate()
	var catalog := card_catalog if card_catalog != null else CardCatalog.new()
	if _entries.size() != 6:
		errors.append("rule archive catalog must contain exactly six entries")
	var seen_entries: Dictionary = {}
	var seen_templates: Dictionary = {}
	for entry in _entries:
		if entry.id == &"":
			errors.append("rule archive entry has an empty ID")
		elif seen_entries.has(entry.id):
			errors.append("duplicate rule archive ID: %s" % entry.id)
		else:
			seen_entries[entry.id] = true
		if entry.display_name.strip_edges().is_empty():
			errors.append("rule archive %s has no display name" % entry.id)
		if entry.summary.strip_edges().is_empty():
			errors.append("rule archive %s has no summary" % entry.id)
		if entry.explanation.strip_edges().is_empty():
			errors.append("rule archive %s has no explanation" % entry.id)
		if entry.encounter == null:
			errors.append("rule archive %s has no encounter" % entry.id)
			continue
		errors.append_array(
			ContentValidator.new().validate(entry.encounter.rules, [])
		)
		var total_slots := 0
		for rule in entry.encounter.rules:
			total_slots += rule.slot_count
			if rule.template == null:
				errors.append(
					"rule archive %s contains an untemplated rule" % entry.id
				)
			elif seen_templates.has(rule.template.id):
				errors.append(
					"rule archive repeats template: %s" % rule.template.id
				)
			else:
				seen_templates[rule.template.id] = true
		if total_slots != 6:
			errors.append(
				"rule archive %s must contain exactly six slots" % entry.id
			)
		if entry.dice_values.size() != 6:
			errors.append(
				"rule archive %s must expose exactly six dice" % entry.id
			)
		for value in entry.dice_values:
			if value < 1 or value > 6:
				errors.append(
					"rule archive %s has a die outside 1..6" % entry.id
				)
		if entry.calibration_points != 2:
			errors.append(
				"rule archive %s must start with two calibration points"
				% entry.id
			)
		for card_id in entry.hand_ids:
			if catalog.find_card(card_id) == null:
				errors.append(
					"rule archive %s has unknown card: %s"
					% [entry.id, card_id]
				)
	if seen_templates.size() != 18:
		errors.append("rule archive must cover all eighteen templates exactly once")
	return errors
