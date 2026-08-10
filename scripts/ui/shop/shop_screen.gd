class_name ShopScreen
extends Control

signal leave_requested
signal intel_view_requested(snapshot: ShopIntelSnapshot)
signal state_changed
signal remove_card_requested(card_id: StringName)
signal engraving_transfer_requested(
	source_die_id: StringName,
	target_die_id: StringName,
	target_face: int
)

const CARD_SCENE = preload("res://scenes/components/shop_card_token.tscn")
const CardFormatter = preload("res://scripts/ui/card_display_formatter.gd")
const AreaPresentation = preload(
	"res://scripts/ui/area_presentation_catalog.gd"
)

@export var content_top_inset := 0.0

@onready var deck_grid: GridContainer = %DeckGrid
@onready var offer_column: VBoxContainer = %OfferColumn
@onready var ticket_label: Label = %TicketLabel
@onready var selection_label: Label = %ShopSelectionLabel
@onready var card_detail_panel: PanelContainer = %ShopCardDetailPanel
@onready var card_detail_text: Label = %ShopCardDetailText
@onready var service_status_label: Label = %ShopServiceStatusLabel
@onready var error_label: Label = %ShopErrorLabel
@onready var confirm_button: Button = %ConfirmReplacementButton
@onready var refresh_button: Button = %RefreshOffersButton
@onready var intel_button: Button = %PurchaseIntelButton
@onready var leave_button: Button = %LeaveShopButton
@onready var formal_service_panel: PanelContainer = %FormalServicePanel
@onready var remove_card_button: Button = %RemoveCardButton
@onready var engraving_source_choice: OptionButton = %EngravingSourceChoice
@onready var engraving_target_choice: OptionButton = %EngravingTargetChoice
@onready var engraving_face_choice: OptionButton = %EngravingFaceChoice
@onready var transfer_engraving_button: Button = %TransferEngravingButton
@onready var refresh_dialog: ConfirmationDialog = %RefreshConfirmationDialog
@onready var safe_area: MarginContainer = $SafeArea
@onready var background: ColorRect = $Background
@onready var area_atmosphere: Control = %AreaAtmosphere
@onready var area_identity_bar: ColorRect = %AreaIdentityBar
@onready var area_stage_label: Label = %AreaStageLabel

var shop_session: ShopSession
var catalog: CardCatalog
var selected_offer_id: StringName = &""
var selected_deck_id: StringName = &""
var _formal_profiles: Array[DieState] = []
var _engraving_catalog: EngravingCatalog
var _formal_context_bound := false

func _ready() -> void:
	safe_area.offset_top += content_top_inset
	visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	intel_button.pressed.connect(_on_intel_pressed)
	leave_button.pressed.connect(func() -> void: leave_requested.emit())
	remove_card_button.pressed.connect(_on_remove_card_pressed)
	transfer_engraving_button.pressed.connect(_on_transfer_engraving_pressed)
	refresh_dialog.confirmed.connect(_on_refresh_confirmed)
	for face in range(1, 7):
		engraving_face_choice.add_item("%d 面" % face)
		engraving_face_choice.set_item_metadata(
			engraving_face_choice.item_count - 1,
			face
		)

func apply_area_presentation(area_id: StringName, area_name: String) -> void:
	var presentation: Dictionary = AreaPresentation.new().find(area_id)
	if presentation.is_empty():
		return
	background.color = presentation["background"]
	area_identity_bar.color = presentation["primary"]
	area_stage_label.text = "%s / %s" % [
		presentation["eyebrow"],
		area_name,
	]
	area_stage_label.add_theme_color_override(
		"font_color",
		presentation["secondary"]
	)
	area_atmosphere.configure(area_id)

func bind_session(p_session: ShopSession, p_catalog: CardCatalog) -> void:
	shop_session = p_session
	catalog = p_catalog
	selected_offer_id = &""
	selected_deck_id = &""
	_formal_profiles.clear()
	_engraving_catalog = null
	_formal_context_bound = false
	error_label.text = ""
	visible = true
	_refresh()

func bind_formal_context(
	profiles: Array[DieState],
	p_engraving_catalog: EngravingCatalog
) -> void:
	_formal_profiles.clear()
	for profile in profiles:
		_formal_profiles.append(profile.clone())
	_engraving_catalog = p_engraving_catalog
	_formal_context_bound = true
	_refresh_formal_service_choices()
	_refresh()

func refresh_from_session(clear_deck_selection := false) -> void:
	if clear_deck_selection:
		selected_deck_id = &""
	_refresh()

func show_service_error(message: String) -> void:
	error_label.text = message
	if not message.is_empty():
		SfxAccess.play(self, &"error")

func _refresh() -> void:
	for child in deck_grid.get_children():
		child.queue_free()
	for child in offer_column.get_children():
		child.queue_free()

	for card_id in shop_session.deck_ids:
		_add_card(deck_grid, card_id, &"deck", selected_deck_id == card_id, false, -1)
	for card_id in shop_session.offer_ids:
		_add_card(
			offer_column,
			card_id,
			&"offer",
			selected_offer_id == card_id,
			card_id in shop_session.sold_offer_ids,
			shop_session.card_price(card_id)
		)

	ticket_label.text = "情报券：%d" % shop_session.intel_tickets
	get_node("%DeckTitle").text = "当前牌组 · %d / %d" % [
		shop_session.deck_ids.size(),
		CardDeck.MAX_DECK_SIZE if shop_session.append_purchases else shop_session.deck_ids.size(),
	]
	selection_label.text = (
		"候选：%s　牌组：%d / %d　整备所选：%s" % [
			_card_name(selected_offer_id),
			shop_session.deck_ids.size(),
			CardDeck.MAX_DECK_SIZE,
			_card_name(selected_deck_id),
		]
		if shop_session.append_purchases
		else "候选：%s　替换：%s" % [
			_card_name(selected_offer_id),
			_card_name(selected_deck_id),
		]
	)
	_refresh_card_detail()
	confirm_button.disabled = (
		selected_offer_id == &""
		or (
			shop_session.append_purchases
			and shop_session.deck_ids.size() >= CardDeck.MAX_DECK_SIZE
		)
		or (not shop_session.append_purchases and selected_deck_id == &"")
	)
	confirm_button.text = (
		"购入候选（%d 情报券）" % shop_session.card_price(selected_offer_id)
		if shop_session.append_purchases
		else "确认替换（%d 情报券）" % shop_session.card_price(selected_offer_id)
	)
	var show_services := shop_session.services_enabled
	service_status_label.visible = show_services
	refresh_button.visible = show_services
	intel_button.visible = show_services
	formal_service_panel.visible = show_services and _formal_context_bound
	if show_services:
		var intel_name := _intel_name()
		refresh_button.text = (
			"候选已刷新"
			if shop_session.refresh_used
			else "刷新候选（%d 情报券）" % shop_session.refresh_price()
		)
		service_status_label.text = "刷新：%s　%s：%s" % [
			"已使用" if shop_session.refresh_used else "可用",
			intel_name,
			"已购" if shop_session.intel_unlocked else "未购",
		]
		refresh_button.disabled = shop_session.refresh_used
		intel_button.text = (
			"查看已购%s" % intel_name
			if shop_session.intel_unlocked
			else "购买%s（%d 情报券）" % [intel_name, shop_session.intel_price()]
		)
	_refresh_formal_service_status()

func _refresh_card_detail() -> void:
	var has_offer := selected_offer_id != &""
	var has_deck := selected_deck_id != &""
	card_detail_panel.visible = has_offer or has_deck
	if not card_detail_panel.visible:
		card_detail_text.text = ""
		return
	var formatter := CardFormatter.new()
	var lines: PackedStringArray = []
	if has_offer:
		lines.append(formatter.comparison_copy(
			"候选",
			catalog.find_card(selected_offer_id)
		))
	if has_deck:
		lines.append(formatter.comparison_copy(
			"整备所选" if shop_session.append_purchases else "替换",
			catalog.find_card(selected_deck_id)
		))
	card_detail_text.text = "\n".join(lines)

func _add_card(
	parent: Control,
	card_id: StringName,
	role: StringName,
	selected: bool,
	disabled: bool,
	price: int
) -> void:
	var card := catalog.find_card(card_id)
	if card == null:
		error_label.text = "卡牌定义不存在：%s" % card_id
		return
	var token: ShopCardToken = CARD_SCENE.instantiate()
	var compact_face := role == &"deck"
	if compact_face:
		token.custom_minimum_size = Vector2(190, 132)
	parent.add_child(token)
	token.bind_card(card, selected, disabled, role, price, compact_face)
	token.card_selected.connect(_on_card_selected)

func _on_card_selected(card_id: StringName, role: StringName) -> void:
	var selection_changed := false
	if role == &"offer":
		selection_changed = selected_offer_id != card_id
		selected_offer_id = card_id
	elif role == &"deck":
		selection_changed = selected_deck_id != card_id
		selected_deck_id = card_id
	if selection_changed:
		SfxAccess.play(self, &"card_select")
	error_label.text = ""
	_refresh()

func _on_confirm_pressed() -> void:
	var result := shop_session.purchase(selected_offer_id, selected_deck_id)
	error_label.text = result.reason
	if result.accepted:
		selected_offer_id = &""
		selected_deck_id = &""
		SfxAccess.play(self, &"shop_purchase")
		state_changed.emit()
	elif not result.reason.is_empty():
		SfxAccess.play(self, &"error")
	_refresh()

func _on_refresh_pressed() -> void:
	if shop_session == null:
		return
	if shop_session.refresh_used:
		error_label.text = "本店已经刷新过候选"
		SfxAccess.play(self, &"error")
		return
	refresh_dialog.popup_centered(Vector2i(560, 220))

func _on_refresh_confirmed() -> void:
	refresh_dialog.hide()
	var result := shop_session.refresh_offers()
	error_label.text = result.reason
	if result.accepted:
		selected_offer_id = &""
		selected_deck_id = &""
		SfxAccess.play(self, &"shop_purchase")
		state_changed.emit()
	elif not result.reason.is_empty():
		SfxAccess.play(self, &"error")
	_refresh()

func _on_intel_pressed() -> void:
	if shop_session == null or shop_session.intel_snapshot == null:
		error_label.text = "当前商店没有可查看的未来情报"
		SfxAccess.play(self, &"error")
		return
	if not shop_session.intel_unlocked:
		var result := shop_session.purchase_intel()
		error_label.text = result.reason
		if not result.accepted:
			SfxAccess.play(self, &"error")
			_refresh()
			return
		SfxAccess.play(self, &"shop_purchase")
		state_changed.emit()
	error_label.text = ""
	_refresh()
	intel_view_requested.emit(shop_session.intel_snapshot)

func _on_remove_card_pressed() -> void:
	if selected_deck_id == &"":
		show_service_error("请先在当前牌组中选择一张要移除的牌")
		return
	remove_card_requested.emit(selected_deck_id)

func _on_transfer_engraving_pressed() -> void:
	var source_id := _selected_die_id(engraving_source_choice)
	var target_id := _selected_die_id(engraving_target_choice)
	var target_face := (
		int(engraving_face_choice.get_selected_metadata())
		if engraving_face_choice.selected >= 0
		else 0
	)
	engraving_transfer_requested.emit(source_id, target_id, target_face)

func _refresh_formal_service_choices() -> void:
	var previous_source := _selected_die_id(engraving_source_choice)
	var previous_target := _selected_die_id(engraving_target_choice)
	engraving_source_choice.clear()
	engraving_target_choice.clear()
	for profile in _formal_profiles:
		if profile.engraving_id != &"":
			engraving_source_choice.add_item(_profile_copy(profile, true))
			engraving_source_choice.set_item_metadata(
				engraving_source_choice.item_count - 1,
				profile.id
			)
		else:
			engraving_target_choice.add_item(_profile_copy(profile, false))
			engraving_target_choice.set_item_metadata(
				engraving_target_choice.item_count - 1,
				profile.id
			)
	_select_metadata(engraving_source_choice, previous_source)
	_select_metadata(engraving_target_choice, previous_target)

func _refresh_formal_service_status() -> void:
	if not _formal_context_bound or shop_session == null:
		formal_service_panel.visible = false
		return
	var remove_reason := _remove_block_reason()
	remove_card_button.disabled = not remove_reason.is_empty()
	remove_card_button.text = (
		"删牌已使用"
		if shop_session.remove_card_used
		else "移除所选牌（%d 情报）" % shop_session.remove_card_price()
	)
	remove_card_button.tooltip_text = (
		remove_reason
		if not remove_reason.is_empty()
		else "移除 %s；本店限一次，消费立即保存"
			% _card_name(selected_deck_id)
	)
	var transfer_reason := _transfer_block_reason()
	transfer_engraving_button.disabled = not transfer_reason.is_empty()
	transfer_engraving_button.text = (
		"刻印转移已使用"
		if shop_session.transfer_engraving_used
		else "转移刻印（%d 情报）" % shop_session.transfer_engraving_price()
	)
	transfer_engraving_button.tooltip_text = (
		transfer_reason
		if not transfer_reason.is_empty()
		else "将来源刻印转移到目标骰子的指定面；本店限一次，消费立即保存"
	)

func _remove_block_reason() -> String:
	if shop_session.remove_card_used:
		return "本店已经使用过删牌服务"
	if shop_session.deck_ids.size() <= CardDeck.MIN_DECK_SIZE:
		return "牌组必须保留至少十二张牌"
	if selected_deck_id == &"":
		return "请先在当前牌组中选择一张要移除的牌"
	if shop_session.intel_tickets < shop_session.remove_card_price():
		return "情报不足：删牌需要 %d 情报" % shop_session.remove_card_price()
	return ""

func _transfer_block_reason() -> String:
	if shop_session.transfer_engraving_used:
		return "本店已经使用过刻印转移服务"
	if engraving_source_choice.item_count == 0:
		return "当前没有拥有刻印的来源骰子"
	if engraving_target_choice.item_count == 0:
		return "当前没有未刻印的目标骰子"
	if shop_session.intel_tickets < shop_session.transfer_engraving_price():
		return "情报不足：刻印转移需要 %d 情报" % shop_session.transfer_engraving_price()
	return ""

func _selected_die_id(choice: OptionButton) -> StringName:
	if choice == null or choice.selected < 0 or choice.item_count == 0:
		return &""
	return StringName(choice.get_selected_metadata())

func _select_metadata(choice: OptionButton, value: StringName) -> void:
	if value == &"":
		return
	for index in range(choice.item_count):
		if StringName(choice.get_item_metadata(index)) == value:
			choice.select(index)
			return

func _profile_copy(profile: DieState, include_engraving: bool) -> String:
	var base := String(profile.id).to_upper()
	if not include_engraving or _engraving_catalog == null:
		return base
	var engraving := _engraving_catalog.find_engraving(profile.engraving_id)
	return "%s · %s" % [
		base,
		"未知刻印" if engraving == null else engraving.display_name,
	]

func _intel_name() -> String:
	if (
		shop_session == null
		or shop_session.intel_snapshot == null
		or shop_session.intel_snapshot.kind == ShopIntelSnapshot.Kind.ROUTE_PAIR
	):
		return "路线情报"
	return "庄家情报"

func _card_name(card_id: StringName) -> String:
	if card_id == &"":
		return "未选择"
	var card := catalog.find_card(card_id)
	return "未知" if card == null else card.display_name
