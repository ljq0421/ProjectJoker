class_name ShopServiceRecord
extends RefCounted

enum ServiceType {
	REFRESH,
	INTEL,
}

var shop_index: int
var service_type: ServiceType
var price: int
var intel_kind: int

func _init(
	p_shop_index: int,
	p_service_type: ServiceType,
	p_price: int,
	p_intel_kind: int = -1
) -> void:
	shop_index = p_shop_index
	service_type = p_service_type
	price = p_price
	intel_kind = p_intel_kind
