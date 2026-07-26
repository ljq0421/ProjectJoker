class_name ShopPurchaseRecord
extends RefCounted

var offer_id: StringName
var replaced_id: StringName
var price: int

func _init(
	p_offer_id: StringName,
	p_replaced_id: StringName,
	p_price: int
) -> void:
	offer_id = p_offer_id
	replaced_id = p_replaced_id
	price = p_price

func clone() -> ShopPurchaseRecord:
	return ShopPurchaseRecord.new(offer_id, replaced_id, price)
