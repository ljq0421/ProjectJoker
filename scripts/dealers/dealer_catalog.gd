class_name DealerCatalog
extends RefCounted

const IRON_ABACUS_PATH := "res://resources/dealers/stage5/dealer_iron_abacus.tres"
const MIRROR_LADY_PATH := "res://resources/dealers/mirror_hall/dealer_mirror_lady.tres"
const FACELESS_MASTER_PATH := "res://resources/dealers/faceless_hub/dealer_faceless_master.tres"

var _iron_abacus: DealerDefinition
var _mirror_lady: DealerDefinition
var _faceless_master: DealerDefinition
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
	resource = load(FACELESS_MASTER_PATH)
	if resource is DealerDefinition:
		_faceless_master = resource
	else:
		_load_errors.append("failed to load dealer resource: %s" % FACELESS_MASTER_PATH)

func iron_abacus() -> DealerDefinition:
	return _iron_abacus

func mirror_lady() -> DealerDefinition:
	return _mirror_lady

func faceless_master() -> DealerDefinition:
	return _faceless_master

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
	if _faceless_master != null:
		dealers.append(_faceless_master)
	return dealers

func validate() -> Array[String]:
	var errors: Array[String] = _load_errors.duplicate()
	errors.append_array(ContentValidator.new().validate_dealers(all_dealers()))
	if all_dealers().size() != 3:
		errors.append("dealer catalog must contain exactly three dealers")
	return errors
