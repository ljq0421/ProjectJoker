class_name CardFaceContent
extends Control

const Formatter = preload("res://scripts/ui/card_display_formatter.gd")

const COLOR_CYAN := Color("59e6db")
const COLOR_VIOLET := Color("d27be5")
const COLOR_IVORY := Color("f4f0ff")
const COLOR_EMPTY := Color(0.34, 0.31, 0.47, 0.82)

var _selected := false
var _unavailable := false
var _emphasized := false


func bind_card(
	card: CardDefinition,
	context_copy: String = "",
	price: int = -1,
	shop_layout: bool = false
) -> void:
	var formatter := Formatter.new()
	%CardIdentity.text = formatter.compact_identity_copy(card)
	%CardName.text = card.display_name
	%EffectSummary.text = formatter.effect_short_copy(card)
	%EffectDetail.text = formatter.effect_detail_copy(card)
	%EffectDetail.visible = not %EffectDetail.text.is_empty()
	%TargetIcon.texture = load(formatter.target_icon_path(card.target_type))
	%TargetCopy.text = formatter.target_copy_for(card)

	var uses_complete_face := formatter.has_card_face_art(card)
	%FullCardArtwork.visible = uses_complete_face
	%FallbackMargin.visible = not uses_complete_face
	if uses_complete_face:
		%FullCardArtwork.texture = load(formatter.card_art_path(card))
	else:
		%Artwork.texture = load(formatter.card_art_path(card))
		%Artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		%ArtworkFrame.custom_minimum_size = (
			Vector2(88, 88) if shop_layout else Vector2(76, 78)
		)

	%CommerceRow.visible = not uses_complete_face and shop_layout and (
		not context_copy.is_empty() or price >= 0
	)
	%ContextCopy.text = context_copy
	%ContextCopy.visible = not context_copy.is_empty()
	%PriceCopy.text = "%d 情报券" % price if price >= 0 else ""
	%PriceCopy.visible = price >= 0
	%DynamicPriceCopy.text = "%d 情报券" % price if price >= 0 else ""
	%DynamicPriceBadge.visible = uses_complete_face and shop_layout and price >= 0
	_configure_complete_face_layout(uses_complete_face and shop_layout)
	_set_rarity_track(card.rarity)


func set_interaction_state(selected: bool, unavailable: bool) -> void:
	_selected = selected
	_unavailable = unavailable
	_refresh_selection_frame()
	var content_modulate := Color(1, 1, 1, 0.46 if unavailable else 1.0)
	%FullCardArtwork.modulate = content_modulate
	%FallbackMargin.modulate = content_modulate
	%DynamicPriceBadge.modulate = content_modulate


func set_emphasized(emphasized: bool) -> void:
	_emphasized = emphasized
	_refresh_selection_frame()


func is_complete_card_face() -> bool:
	return %FullCardArtwork.visible and %FullCardArtwork.texture != null


func _configure_complete_face_layout(shop_complete_face: bool) -> void:
	%FullCardArtwork.offset_bottom = -23.0 if shop_complete_face else 0.0
	%SelectionFrame.offset_bottom = -25.0 if shop_complete_face else -2.0


func _refresh_selection_frame() -> void:
	%SelectionFrame.visible = (_selected or _emphasized) and not _unavailable


func visible_copy() -> String:
	var lines: PackedStringArray = [
		"%s %s" % [%CardIdentity.text, %CardName.text],
		%EffectSummary.text,
	]
	if %EffectDetail.visible:
		lines.append(%EffectDetail.text)
	lines.append(%TargetCopy.text)
	if %CommerceRow.visible:
		var commerce_parts: PackedStringArray = []
		if %ContextCopy.visible:
			commerce_parts.append(%ContextCopy.text)
		if %PriceCopy.visible:
			commerce_parts.append(%PriceCopy.text)
		lines.append(" · ".join(commerce_parts))
	return "\n".join(lines)


func rarity_track_copy() -> String:
	return "%s%s%s" % [
		%RaritySlot1.text,
		%RaritySlot2.text,
		%RaritySlot3.text,
	]


func _set_rarity_track(rarity: CardDefinition.Rarity) -> void:
	var filled_slots := clampi(int(rarity) + 1, 1, 3)
	var filled_color := COLOR_CYAN
	if rarity == CardDefinition.Rarity.UNCOMMON:
		filled_color = COLOR_VIOLET
	elif rarity == CardDefinition.Rarity.RARE:
		filled_color = COLOR_IVORY
	var slots: Array[Label] = [%RaritySlot1, %RaritySlot2, %RaritySlot3]
	for index in range(slots.size()):
		var slot := slots[index]
		var filled := index < filled_slots
		slot.text = "◆" if filled else "◇"
		slot.add_theme_color_override(
			"font_color",
			filled_color if filled else COLOR_EMPTY
		)
		slot.add_theme_constant_override(
			"outline_size",
			2 if rarity == CardDefinition.Rarity.RARE and filled else 0
		)
		slot.add_theme_color_override("font_outline_color", COLOR_VIOLET)
