class_name CardDefinition
extends Resource

enum TargetType {
	DIE,
	TABLE,
	GAP,
	GLOBAL,
	DICE_PAIR,
}

enum Suit {
	CLUBS,
	HEARTS,
	DIAMONDS,
	SPADES,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
}

@export var id: StringName
@export var display_name: String
@export_multiline var rule_text: String
@export var tags: PackedStringArray = []
@export var target_type: TargetType = TargetType.DIE
@export var suit: Suit = Suit.CLUBS
@export var rank_label: String
@export var rarity: Rarity = Rarity.COMMON
@export var effects: Array[EffectSpec] = []
@export var mirror_effects: Array[EffectSpec] = []

func suit_copy() -> String:
	return suit_copy_for(suit)

static func suit_copy_for(p_suit: Suit) -> String:
	match p_suit:
		Suit.CLUBS:
			return "♣ 梅花"
		Suit.HEARTS:
			return "♥ 红桃"
		Suit.DIAMONDS:
			return "♦ 方片"
		Suit.SPADES:
			return "♠ 黑桃"
	return "未知花色"

func rarity_copy() -> String:
	match rarity:
		Rarity.COMMON:
			return "普通"
		Rarity.UNCOMMON:
			return "进阶"
		Rarity.RARE:
			return "稀有"
	return "未知稀有度"
