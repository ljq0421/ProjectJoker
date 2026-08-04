extends "res://tests/test_case.gd"

const ROOT := "res://resources/ui/dream_glass/card_faces/prototypes/"
const SOURCE_ROOT := "res://resources/ui/dream_glass/card_faces/sources/"
const SUIT_IDENTITY_COLORS := {
	CardDefinition.Suit.CLUBS: "#65D6A6",
	CardDefinition.Suit.HEARTS: "#FF5C8A",
	CardDefinition.Suit.DIAMONDS: "#FFB547",
	CardDefinition.Suit.SPADES: "#8EA7FF",
}
const CARD_FACE_IDS := [
	"starter_nudge_down_1",
	"shop_precision_map",
	"starter_link",
	"starter_reverse",
	"faceless_copy_value",
	"faceless_lock_bonus",
	"starter_nudge_up_1",
	"starter_nudge_down_2",
	"starter_nudge_up_2",
	"starter_map_1",
	"starter_map_2",
	"starter_repeat_1",
	"starter_repeat_2",
	"starter_stable_repeat",
	"starter_amplified_repeat",
	"shop_triple_repeat",
	"shop_long_push",
	"shop_deep_drop",
	"mirror_folded_map",
	"mirror_soft_echo",
	"mirror_hinged_bridge",
	"mirror_double_exposure",
	"mirror_deep_echo",
	"mirror_silver_bridge",
	"shop_amplified_chain",
	"shop_reverse_backup",
	"faceless_swap_values",
	"faceless_flip_value",
	"faceless_refund_calibration",
	"faceless_exact_tolerance",
	"faceless_even_tolerance",
	"faceless_sequence_tolerance",
	"faceless_table_receipt",
	"faceless_full_allocation",
	"faceless_three_seats",
	"faceless_complete_dossier",
	"faceless_strict_mapping",
	"faceless_reverse_replay",
	"faceless_compressed_repeat",
	"faceless_closed_circuit",
]

func run() -> void:
	assert_equal(
		CARD_FACE_IDS.size(),
		CardCatalog.new().all_cards().size(),
		"complete card-face set should cover the entire card catalog"
	)
	for catalog_card in CardCatalog.new().all_cards():
		assert_true(
			String(catalog_card.id) in CARD_FACE_IDS,
			"%s should be included in the complete card-face set" % catalog_card.id
		)
	for card_id in CARD_FACE_IDS:
		var path := "%s%s.svg" % [ROOT, card_id]
		assert_true(
			FileAccess.file_exists(path),
			"%s should have a deterministic card-face SVG" % card_id
		)
		assert_true(
			FileAccess.file_exists(path + ".import"),
			"%s should keep its Godot SVG import sidecar" % card_id
		)
		assert_true(
			FileAccess.file_exists("%s%s.svg.txt" % [SOURCE_ROOT, card_id]),
			"%s should keep an editable SVG source" % card_id
		)
		assert_true(
			ResourceLoader.exists(path),
			"%s card-face SVG should be imported" % card_id
		)
		var card := CardCatalog.new().find_card(StringName(card_id))
		assert_true(card != null, "%s should resolve through the card catalog" % card_id)
		if card != null:
			var formatter := CardDisplayFormatter.new()
			assert_equal(
				formatter.card_art_path(card),
				path,
				"%s should map to its runtime artwork path" % card_id
			)
		if not FileAccess.file_exists(path):
			continue
		var source := FileAccess.get_file_as_string(path)
		assert_true(
			'viewBox="0 0 300 200"' in source,
			"%s should use the shared 3:2 composition canvas" % card_id
		)
		assert_false(
			"<text" in source,
			"%s should convert all visible copy to vector paths" % card_id
		)
		assert_true(
			'data-card-face="complete-v1"' in source,
			"%s should identify itself as a complete card face" % card_id
		)
		for required_group in [
			'id="card-identity"',
			'id="card-name"',
			'id="rarity-track"',
			'id="effect-artwork"',
			'id="effect-summary"',
			'id="effect-detail"',
			'id="target-icon"',
			'id="target-copy"',
		]:
			assert_true(
				required_group in source,
				"%s should contain complete-card group %s"
				% [card_id, required_group]
			)
		if card != null:
			var identity_start := source.find('id="card-identity"')
			var identity_end := source.find("</g>", identity_start)
			var identity_group := source.substr(
				identity_start,
				identity_end - identity_start
			)
			var expected_color: String = SUIT_IDENTITY_COLORS[card.suit]
			assert_true(
				'fill="%s"' % expected_color in identity_group,
				"%s should color its %s identity with %s"
				% [card_id, card.suit_copy(), expected_color]
			)
