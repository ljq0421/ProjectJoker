class_name AreaPresentationCatalog
extends RefCounted

const PRESENTATIONS := {
	&"gold_corridor": {
		"primary": Color("#e7b84b"),
		"secondary": Color("#55e7c5"),
		"background": Color("#07121c"),
		"pattern": &"parallel_ledger",
		"sigil": &"abacus",
		"eyebrow": "LEDGER / PARALLEL PROOF",
		"route_code": "区域 01",
		"route_instruction": "公开比较单轮条件、目标与现有牌组呼应；选定后以一次定案检验。",
		"ordinary_eyebrow": "区域规则 / LEDGER-01",
		"ordinary_title": "金线监理",
		"ordinary_rule": "本区重点\n精确点数、奇偶与基础关系。先满足条件，再比较三张规则台的系数收益。",
		"directive_title": "金线契约",
		"gauge": "筹码刻度",
		"contract": "联保契据",
		"seat": "席位账页",
		"mechanism": "金线机关",
	},
	&"mirror_hall": {
		"primary": Color("#79d8ff"),
		"secondary": Color("#b57aff"),
		"background": Color("#090b24"),
		"pattern": &"mirror_axis",
		"sigil": &"mirror",
		"eyebrow": "REFLECTION / REVERSE ORDER",
		"route_code": "区域 02",
		"route_instruction": "公开比较镜像条件与结算方向；选定后进入三轮反照解析。",
		"ordinary_eyebrow": "区域规则 / MIRROR-02",
		"ordinary_title": "镜面监理",
		"ordinary_rule": "本区重点\n结算方向与镜像副本会改变桌间牌的先后。先读方向，再安排原牌与倒影。",
		"directive_title": "反照法则",
		"gauge": "镜值刻度",
		"contract": "双生牌面",
		"seat": "反照席位",
		"mechanism": "回折机关",
	},
	&"faceless_hub": {
		"primary": Color("#ff71b7"),
		"secondary": Color("#65eedb"),
		"background": Color("#15091d"),
		"pattern": &"three_nodes",
		"sigil": &"faceless",
		"eyebrow": "PROTOCOL / THREE OPEN SEATS",
		"route_code": "区域 03",
		"route_instruction": "公开比较复合条件与首轮限制；选定后进入三轮议程审议。",
		"ordinary_eyebrow": "区域规则 / PROTOCOL-03",
		"ordinary_title": "无名协议",
		"ordinary_rule": "本区重点\n复合条件与公开限制会共同约束布局。先确认协议，再决定骰子和手法牌。",
		"directive_title": "无名协议",
		"gauge": "无名刻度",
		"contract": "协议链",
		"seat": "索引阵",
		"mechanism": "异常终端",
	},
}

func find(area_id: StringName) -> Dictionary:
	if not PRESENTATIONS.has(area_id):
		return {}
	return PRESENTATIONS[area_id].duplicate(true)
