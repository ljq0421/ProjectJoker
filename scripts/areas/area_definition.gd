class_name AreaDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var expedition_entry_title: String
@export_multiline var expedition_entry_text: String

var _first_route_ids: Array[StringName] = []
@export var first_route_ids: Array[StringName]:
	get:
		return _first_route_ids.duplicate()
	set(value):
		_first_route_ids.assign(value)

var _second_route_ids: Array[StringName] = []
@export var second_route_ids: Array[StringName]:
	get:
		return _second_route_ids.duplicate()
	set(value):
		_second_route_ids.assign(value)

@export var rooms: Array[RoomDefinition] = []
@export var starting_deck_ids: Array[StringName] = []
@export var starting_intel_tickets := 0
@export var initial_engraving_id: StringName = &""
@export var initial_engraving_die_id: StringName = &""
@export_range(0, 6, 1) var initial_engraving_face := 0
@export var dealer_id: StringName
@export var dealer_encounter: EncounterDefinition
@export var dealer_round_schedule: DealerRoundSchedule
@export var dealer_target := 0
@export var shop_offer_ids: Array[StringName] = []
@export var engraving_offer_ids: Array[StringName] = []

func find_room(room_id: StringName) -> RoomDefinition:
	for room in rooms:
		if room != null and room.id == room_id:
			return room
	return null

func validate(
	card_catalog: CardCatalog,
	dealer_catalog: DealerCatalog,
	engraving_catalog: EngravingCatalog
) -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("area ID is empty")
	if display_name.strip_edges().is_empty():
		errors.append("area %s has no display name" % id)
	if expedition_entry_title.strip_edges().is_empty():
		errors.append("area %s has no expedition entry title" % id)
	if expedition_entry_text.strip_edges().is_empty():
		errors.append("area %s has no expedition entry text" % id)
	if card_catalog == null or dealer_catalog == null or engraving_catalog == null:
		errors.append("area %s validation catalogs are unavailable" % id)
		return errors

	errors.append_array(ContentValidator.new().validate_rooms(rooms))
	if rooms.size() != 4:
		errors.append("area %s must contain exactly four rooms" % id)
	_validate_routes(errors)
	_validate_deck(errors, card_catalog)
	_validate_initial_engraving(errors, engraving_catalog)
	_validate_dealer(errors, dealer_catalog)
	_validate_shop_pool(errors, card_catalog)
	_validate_engraving_pool(errors, engraving_catalog)
	if starting_intel_tickets < 0:
		errors.append("area %s starting tickets cannot be negative" % id)
	return errors

func _validate_routes(errors: Array[String]) -> void:
	var seen: Dictionary = {}
	for route_name in ["first", "second"]:
		var ids: Array[StringName] = (
			_first_route_ids
			if route_name == "first"
			else _second_route_ids
		)
		if ids.size() != 2:
			errors.append("area %s %s route must contain exactly two rooms" % [id, route_name])
		for room_id in ids:
			if find_room(room_id) == null:
				errors.append("area %s route contains unknown room: %s" % [id, room_id])
			if seen.has(room_id):
				errors.append("area %s routes contain duplicate room: %s" % [id, room_id])
			else:
				seen[room_id] = true

func _validate_deck(errors: Array[String], card_catalog: CardCatalog) -> void:
	if starting_deck_ids.size() != 12:
		errors.append("area %s starting deck must contain exactly twelve cards" % id)
	var seen: Dictionary = {}
	for card_id in starting_deck_ids:
		if card_catalog.find_card(card_id) == null:
			errors.append("area %s starting deck contains unknown card: %s" % [id, card_id])
		if seen.has(card_id):
			errors.append("area %s starting deck contains duplicate card: %s" % [id, card_id])
		else:
			seen[card_id] = true

func _validate_initial_engraving(
	errors: Array[String],
	engraving_catalog: EngravingCatalog
) -> void:
	if initial_engraving_id == &"":
		if initial_engraving_die_id != &"" or initial_engraving_face != 0:
			errors.append("area %s empty initial engraving must not select a die or face" % id)
		return
	if engraving_catalog.find_engraving(initial_engraving_id) == null:
		errors.append("area %s initial engraving is unknown: %s" % [id, initial_engraving_id])
	if initial_engraving_die_id not in [&"d1", &"d2", &"d3", &"d4", &"d5", &"d6"]:
		errors.append("area %s initial engraving die is invalid" % id)
	if initial_engraving_face < 1 or initial_engraving_face > 6:
		errors.append("area %s initial engraving face is invalid" % id)

func _validate_dealer(
	errors: Array[String],
	dealer_catalog: DealerCatalog
) -> void:
	if dealer_catalog.find_dealer(dealer_id) == null:
		errors.append("area %s dealer is unknown: %s" % [id, dealer_id])
	if dealer_round_schedule != null:
		errors.append_array(
			ContentValidator.new().validate_round_schedule(
				dealer_round_schedule
			)
		)
	elif dealer_encounter == null:
		errors.append("area %s has no dealer encounter or round schedule" % id)
	else:
		errors.append_array(
			ContentValidator.new().validate(dealer_encounter.rules, [])
		)
	if dealer_target <= 0:
		errors.append("area %s dealer target must be positive" % id)

func _validate_shop_pool(
	errors: Array[String],
	card_catalog: CardCatalog
) -> void:
	if shop_offer_ids.size() < 6:
		errors.append("area %s shop pool must contain at least six cards" % id)
	var seen: Dictionary = {}
	var outside_deck := 0
	for card_id in shop_offer_ids:
		if card_catalog.find_card(card_id) == null:
			errors.append("area %s shop pool contains unknown card: %s" % [id, card_id])
		if seen.has(card_id):
			errors.append("area %s shop pool contains duplicate card: %s" % [id, card_id])
		else:
			seen[card_id] = true
		if card_id not in starting_deck_ids:
			outside_deck += 1
	if outside_deck < 6:
		errors.append(
			"area %s market must contain at least six cards outside the starting deck" % id
		)

func _validate_engraving_pool(
	errors: Array[String],
	engraving_catalog: EngravingCatalog
) -> void:
	if engraving_offer_ids.size() < 3:
		errors.append("area %s engraving pool must contain at least three entries" % id)
	var seen: Dictionary = {}
	for engraving_id in engraving_offer_ids:
		if engraving_catalog.find_engraving(engraving_id) == null:
			errors.append(
				"area %s engraving pool contains unknown entry: %s"
				% [id, engraving_id]
			)
		if seen.has(engraving_id):
			errors.append(
				"area %s engraving pool contains duplicate entry: %s"
				% [id, engraving_id]
			)
		else:
			seen[engraving_id] = true
