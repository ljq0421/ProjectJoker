extends SceneTree

const Formatter = preload("res://scripts/ui/card_display_formatter.gd")
const CARD_IDS := [
	&"starter_nudge_down_1",
	&"shop_precision_map",
	&"starter_link",
	&"starter_reverse",
	&"faceless_copy_value",
	&"faceless_lock_bonus",
	&"starter_nudge_up_1",
	&"starter_nudge_down_2",
	&"starter_nudge_up_2",
	&"starter_map_1",
	&"starter_map_2",
	&"starter_repeat_1",
	&"starter_repeat_2",
	&"starter_stable_repeat",
	&"starter_amplified_repeat",
	&"shop_triple_repeat",
	&"shop_long_push",
	&"shop_deep_drop",
	&"mirror_folded_map",
	&"mirror_soft_echo",
	&"mirror_hinged_bridge",
	&"mirror_double_exposure",
	&"mirror_deep_echo",
	&"mirror_silver_bridge",
	&"shop_amplified_chain",
	&"shop_reverse_backup",
	&"shop_dice_index",
	&"shop_chain_index",
	&"faceless_swap_values",
	&"faceless_flip_value",
	&"faceless_refund_calibration",
	&"faceless_exact_tolerance",
	&"faceless_even_tolerance",
	&"faceless_sequence_tolerance",
	&"faceless_table_receipt",
	&"faceless_full_allocation",
	&"faceless_three_seats",
	&"faceless_complete_dossier",
	&"faceless_strict_mapping",
	&"faceless_reverse_replay",
	&"faceless_compressed_repeat",
	&"faceless_closed_circuit",
	&"stage7_fault_die",
	&"stage7_all_in",
	&"stage7_insurance_draft",
	&"stage7_burned_rewrite",
]

var output_path := (
	"res://resources/ui/dream_glass/card_faces/card_face_manifest.json"
)


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	call_deferred("_export")


func _export() -> void:
	var catalog := CardCatalog.new()
	var formatter := Formatter.new()
	var cards: Array[Dictionary] = []
	for card_id in CARD_IDS:
		var card := catalog.find_card(card_id)
		if card == null:
			push_error("card-face export cannot find %s" % card_id)
			quit(1)
			return
		cards.append({
			"id": String(card.id),
			"identity": formatter.compact_identity_copy(card),
			"name": card.display_name,
			"effect": formatter.effect_short_copy(card),
			"detail": formatter.effect_detail_copy(card),
			"target": formatter.target_copy_for(card),
			"target_type": int(card.target_type),
			"rarity": int(card.rarity),
			"rarity_name": card.rarity_copy(),
		})
	var payload := {
		"schema": "project-joker.card-face-manifest.v1",
		"canvas": [300, 200],
		"cards": cards,
	}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("cannot write card-face manifest: %s" % output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(payload, "  ", false) + "\n")
	file.close()
	print("EXPORTED %d card-face records -> %s" % [cards.size(), output_path])
	quit(0)
