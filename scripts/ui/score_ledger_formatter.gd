class_name ScoreLedgerFormatter
extends RefCounted

const ORDER: Array[int] = [
	ResolutionEvent.ScoreSource.BASE,
	ResolutionEvent.ScoreSource.COEFFICIENT,
	ResolutionEvent.ScoreSource.CARD,
	ResolutionEvent.ScoreSource.RULE_CHAIN,
	ResolutionEvent.ScoreSource.ENGRAVING,
	ResolutionEvent.ScoreSource.AREA_MODIFIER,
	ResolutionEvent.ScoreSource.LUCK,
	ResolutionEvent.ScoreSource.DEALER,
]

static func source_name(source: int) -> String:
	match source:
		ResolutionEvent.ScoreSource.BASE:
			return "基础分"
		ResolutionEvent.ScoreSource.COEFFICIENT:
			return "原生系数"
		ResolutionEvent.ScoreSource.CARD:
			return "卡牌效果"
		ResolutionEvent.ScoreSource.RULE_CHAIN:
			return "规则连锁/共鸣"
		ResolutionEvent.ScoreSource.ENGRAVING:
			return "刻印"
		ResolutionEvent.ScoreSource.AREA_MODIFIER:
			return "区域异变"
		ResolutionEvent.ScoreSource.LUCK:
			return "幸运"
		ResolutionEvent.ScoreSource.DEALER:
			return "庄家奖励"
	return "未分类"

static func compact_copy(report: ResolutionReport) -> String:
	if report == null:
		return "八段账本｜暂无结算"
	var values := report.score_breakdown.duplicate()
	var categorized_total := 0
	for source in ORDER:
		categorized_total += int(values.get(source, 0))
	if categorized_total != report.total:
		values[ResolutionEvent.ScoreSource.BASE] = int(
			values.get(ResolutionEvent.ScoreSource.BASE, 0)
		) + report.total - categorized_total
	var rows: Array[String] = []
	for start in [0, 4]:
		var parts: Array[String] = []
		for index in range(start, start + 4):
			var source: int = ORDER[index]
			parts.append("%s %+d" % [source_name(source), int(values.get(source, 0))])
		rows.append(" · ".join(parts))
	return "八段账本｜%s\n%s" % [rows[0], rows[1]]
