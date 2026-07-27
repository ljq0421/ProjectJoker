class_name DealerCatalog
extends RefCounted

const IRON_ABACUS_PATH := "res://resources/dealers/stage5/dealer_iron_abacus.tres"

var _iron_abacus: DealerDefinition
var _load_errors: Array[String] = []

func _init() -> void:
	var resource := load(IRON_ABACUS_PATH)
	if resource is DealerDefinition:
		_iron_abacus = resource
	else:
		_load_errors.append("failed to load dealer resource: %s" % IRON_ABACUS_PATH)

func iron_abacus() -> DealerDefinition:
	return _iron_abacus

func find_dealer(dealer_id: StringName) -> DealerDefinition:
	for dealer in all_dealers():
		if dealer.id == dealer_id:
			return dealer
	return null

func all_dealers() -> Array[DealerDefinition]:
	var dealers: Array[DealerDefinition] = []
	if _iron_abacus != null:
		dealers.append(_iron_abacus)
	return dealers

func validate() -> Array[String]:
	var errors: Array[String] = _load_errors.duplicate()
	errors.append_array(ContentValidator.new().validate_dealers(all_dealers()))
	if all_dealers().size() != 1:
		errors.append("dealer catalog must contain exactly one dealer")
	return errors
