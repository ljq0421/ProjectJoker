class_name DealerCatalog
extends RefCounted

const IRON_ABACUS_PATH := "res://resources/dealers/stage5/dealer_iron_abacus.tres"
const MIRROR_LADY_PATH := "res://resources/dealers/mirror_hall/dealer_mirror_lady.tres"

var _iron_abacus: DealerDefinition
var _mirror_lady: DealerDefinition
var _load_errors: Array[String] = []

func _init() -> void:
	var resource := load(IRON_ABACUS_PATH)
	if resource is DealerDefinition:
		_iron_abacus = resource
	else:
		_load_errors.append("failed to load dealer resource: %s" % IRON_ABACUS_PATH)
	resource = load(MIRROR_LADY_PATH)
	if resource is DealerDefinition:
		_mirror_lady = resource
	else:
		_load_errors.append("failed to load dealer resource: %s" % MIRROR_LADY_PATH)

func iron_abacus() -> DealerDefinition:
	return _iron_abacus

func mirror_lady() -> DealerDefinition:
	return _mirror_lady

func find_dealer(dealer_id: StringName) -> DealerDefinition:
	for dealer in all_dealers():
		if dealer.id == dealer_id:
			return dealer
	return null

func all_dealers() -> Array[DealerDefinition]:
	var dealers: Array[DealerDefinition] = []
	if _iron_abacus != null:
		dealers.append(_iron_abacus)
	if _mirror_lady != null:
		dealers.append(_mirror_lady)
	return dealers

func validate() -> Array[String]:
	var errors: Array[String] = _load_errors.duplicate()
	errors.append_array(ContentValidator.new().validate_dealers(all_dealers()))
	if all_dealers().size() != 2:
		errors.append("dealer catalog must contain exactly two dealers")
	return errors
