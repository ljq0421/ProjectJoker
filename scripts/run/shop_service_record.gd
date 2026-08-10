class_name ShopServiceRecord
extends RefCounted

enum ServiceType {
	REFRESH,
	INTEL,
	REMOVE_CARD,
	TRANSFER_ENGRAVING,
}

var shop_index: int
var service_type: ServiceType
var price: int
var intel_kind: int
var target_card_id: StringName
var source_die_id: StringName
var target_die_id: StringName
var target_face: int

func _init(
	p_shop_index: int,
	p_service_type: ServiceType,
	p_price: int,
	p_intel_kind: int = -1,
	p_target_card_id: StringName = &"",
	p_source_die_id: StringName = &"",
	p_target_die_id: StringName = &"",
	p_target_face: int = 0
) -> void:
	shop_index = p_shop_index
	service_type = p_service_type
	price = p_price
	intel_kind = p_intel_kind
	target_card_id = p_target_card_id
	source_die_id = p_source_die_id
	target_die_id = p_target_die_id
	target_face = p_target_face

func clone() -> ShopServiceRecord:
	return ShopServiceRecord.new(
		shop_index,
		service_type,
		price,
		intel_kind,
		target_card_id,
		source_die_id,
		target_die_id,
		target_face
	)
