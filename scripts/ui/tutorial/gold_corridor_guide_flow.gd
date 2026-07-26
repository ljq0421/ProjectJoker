class_name GoldCorridorGuideFlow
extends RefCounted

const CHECKPOINT_ORDER: Array[StringName] = [
	&"route",
	&"shop",
	&"dealer",
	&"engraving",
]

const CARD_SPECS := {
	&"route": {
		"id": &"route",
		"progress_label": "鍖哄煙鎻愮ず",
		"progress_index": 1,
		"progress_total": 4,
		"title": "鍏堟瘮杈冿紝鍐嶉€夋嫨",
		"instruction": (
			"姣忎釜鎴块棿鐢ㄤ笁杞叡鍚屽畬鎴愮疮璁＄洰鏍囥€傜洰鏍囥€佹儏鎶ュ埜濂栧姳銆?"
			+ "涓夋潯瑙勫垯涓庡綋鍓嶇墝缁勫懠搴斿潎宸插叕寮€锛涢€夋嫨鏇撮€傚悎褰撳墠鏋勭瓚鐨勮矾绾裤€?"
			+ "涓夎疆鍏卞悓瀹屾垚绱鐩爣"
		),
		"target_ids": [&"route_left", &"route_right"],
	},
	&"shop": {
		"id": &"shop",
		"progress_label": "鍖哄煙鎻愮ず",
		"progress_index": 2,
		"progress_total": 4,
		"title": "鏇挎崲浼氬奖鍝嶅悗缁暣涓尯鍩?",
		"instruction": (
			"姣忔鑺辫垂 1 寮犳儏鎶ュ埜锛岀敤涓€寮犲€欓€夌墝鏇挎崲涓€寮犳棫鐗岋紱"
			+ "鐗岀粍濮嬬粓淇濇寔鍗佷簩寮犮€傜搴楀悗鐨勭墝缁勪笌浣欓浼氬甫鍏ョ浜屼釜鎴块棿"
			+ "鍜岄搧绠楃洏锛屼篃鍙互涓嶈喘涔扮洿鎺ョ寮€銆?"
			+ "绗簩涓埧闂村拰閾佺畻鐩?"
			+ "涓嶈喘涔扮洿鎺ョ寮€"
		),
		"target_ids": [&"shop_tickets", &"shop_deck", &"shop_offers"],
	},
	&"dealer": {
		"id": &"dealer",
		"progress_label": "鍖哄煙鎻愮ず",
		"progress_index": 3,
		"progress_total": 4,
		"title": "瀹屾暣鍒嗛厤浼氫繚浣忓浐瀹氬鍔?",
		"instruction": (
			"閾佺畻鐩樼殑涓夎疆绱鐩爣涓?150銆傛瘡杞浐瀹氬鍔变粠 12 寮€濮嬶紝"
			+ "姣忛鏈垎閰嶉瀛愪娇濂栧姳鍑忓皯 2锛屾渶浣庝负 0锛?"
			+ "褰撳墠缁撴灉浼氬湪缁撶畻杞ㄨ抗涓疄鏃舵樉绀恒€?"
		),
		"target_ids": [&"dealer_panel", &"resolution_panel"],
	},
	&"engraving": {
		"id": &"engraving",
		"progress_label": "鍖哄煙鎻愮ず",
		"progress_index": 4,
		"progress_total": 4,
		"title": "杩欐瀹夎灏嗗皝瀛樺尯鍩?",
		"instruction": (
			"渚濇閫夋嫨涓€绉嶅埢鍗般€佷竴棰楅瀛愬拰瀹冪殑 1鈥? 闈紱"
			+ "瀹夎鍓嶅彲浠ヨ嚜鐢变慨鏀逛笁椤归€夋嫨銆傛寮忓尯鍩熷畨瑁呭悗鐩存帴杩涘叆"
			+ "瀹屾垚璐︾洰锛屼笉鍐嶈繘鍏ュ埢鍗伴獙璇佸眬銆?"
			+ "涓嶅啀杩涘叆鍒诲嵃楠岃瘉灞€"
		),
		"target_ids": [&"reward_offers", &"reward_dice", &"reward_faces"],
	},
}

var _requested: Dictionary = {}

func checkpoint_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(CHECKPOINT_ORDER)
	return result

func card_spec(checkpoint_id: StringName) -> Dictionary:
	if not CARD_SPECS.has(checkpoint_id):
		return {}
	var spec: Dictionary = CARD_SPECS[checkpoint_id]
	return spec.duplicate(true)

func should_present(
	checkpoint_id: StringName,
	progress_snapshot: Dictionary
) -> bool:
	if not CARD_SPECS.has(checkpoint_id):
		return false
	if bool(progress_snapshot.get("dismissed", false)):
		return false
	if bool(progress_snapshot.get("seen_%s" % checkpoint_id, false)):
		return false
	return not _requested.has(checkpoint_id)

func mark_requested(checkpoint_id: StringName) -> bool:
	if not CARD_SPECS.has(checkpoint_id):
		return false
	_requested[checkpoint_id] = true
	return true
