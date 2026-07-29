class_name ShopIntelSnapshot
extends RefCounted

enum Kind {
	ROUTE_PAIR,
	DEALER,
}

var kind: Kind = Kind.ROUTE_PAIR
var route_ids: Array[StringName] = []
var dealer_id: StringName = &""
var dealer_target := 0

static func routes(ids: Array[StringName]) -> ShopIntelSnapshot:
	var snapshot := ShopIntelSnapshot.new()
	snapshot.kind = Kind.ROUTE_PAIR
	snapshot.route_ids.assign(ids)
	return snapshot

static func dealer(id: StringName, target: int) -> ShopIntelSnapshot:
	var snapshot := ShopIntelSnapshot.new()
	snapshot.kind = Kind.DEALER
	snapshot.dealer_id = id
	snapshot.dealer_target = target
	return snapshot

func structural_error() -> String:
	match kind:
		Kind.ROUTE_PAIR:
			if route_ids.size() != 2:
				return "路线情报必须包含两个房间"
			if route_ids[0] == &"" or route_ids[1] == &"":
				return "路线情报包含空房间 ID"
			if route_ids[0] == route_ids[1]:
				return "路线情报包含重复房间"
			if dealer_id != &"" or dealer_target != 0:
				return "路线情报不能包含庄家字段"
		Kind.DEALER:
			if not route_ids.is_empty():
				return "庄家情报不能包含路线字段"
			if dealer_id == &"":
				return "庄家情报缺少庄家 ID"
			if dealer_target <= 0:
				return "庄家情报目标必须大于零"
		_:
			return "情报类型无效"
	return ""

func validate(
	area_definition: AreaDefinition,
	dealer_catalog: DealerCatalog
) -> String:
	var shape_error := structural_error()
	if not shape_error.is_empty():
		return shape_error
	if area_definition == null:
		return "情报缺少区域定义"
	if dealer_catalog == null:
		return "情报缺少庄家目录"
	if kind == Kind.ROUTE_PAIR:
		var expected_ids := area_definition.second_route_ids
		for room_id in route_ids:
			if room_id not in expected_ids or area_definition.find_room(room_id) == null:
				return "路线情报包含未知房间：%s" % room_id
		return ""
	if dealer_id != area_definition.dealer_id:
		return "庄家情报与区域庄家不一致"
	if dealer_catalog.find_dealer(dealer_id) == null:
		return "庄家情报包含未知庄家：%s" % dealer_id
	if dealer_target != area_definition.dealer_target:
		return "庄家情报目标与区域定义不一致"
	return ""
