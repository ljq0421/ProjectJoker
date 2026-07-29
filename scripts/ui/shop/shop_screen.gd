class_name ShopScreen
extends Control

signal leave_requested
signal intel_view_requested(snapshot: ShopIntelSnapshot)
signal state_changed

const CARD_SCENE = preload("res://scenes/components/shop_card_token.tscn")

@onready var deck_grid: GridContainer = %DeckGrid
@onready var offer_column: VBoxContainer = %OfferColumn
@onready var ticket_label: Label = %TicketLabel
@onready var selection_label: Label = %ShopSelectionLabel
@onready var service_status_label: Label = %ShopServiceStatusLabel
@onready var error_label: Label = %ShopErrorLabel
@onready var confirm_button: Button = %ConfirmReplacementButton
@onready var refresh_button: Button = %RefreshOffersButton
@onready var intel_button: Button = %PurchaseIntelButton
@onready var leave_button: Button = %LeaveShopButton
@onready var refresh_dialog: ConfirmationDialog = %RefreshConfirmationDialog

var shop_session: ShopSession
var catalog: CardCatalog
var selected_offer_id: StringName = &""
var selected_deck_id: StringName = &""

func _ready() -> void:
	visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	intel_button.pressed.connect(_on_intel_pressed)
	leave_button.pressed.connect(func() -> void: leave_requested.emit())
	refresh_dialog.confirmed.connect(_on_refresh_confirmed)

func bind_session(p_session: ShopSession, p_catalog: CardCatalog) -> void:
	shop_session = p_session
	catalog = p_catalog
	selected_offer_id = &""
	selected_deck_id = &""
	error_label.text = ""
	visible = true
	_refresh()

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
			ShopSession.CARD_PRICE
		)

	ticket_label.text = "情报券：%d" % shop_session.intel_tickets
	selection_label.text = "候选：%s　替换：%s" % [
		_card_name(selected_offer_id),
		_card_name(selected_deck_id),
	]
	confirm_button.disabled = selected_offer_id == &"" or selected_deck_id == &""
	var show_services := shop_session.services_enabled
	service_status_label.visible = show_services
	refresh_button.visible = show_services
	intel_button.visible = show_services
	if show_services:
		var intel_name := _intel_name()
		service_status_label.text = "刷新：%s　%s：%s" % [
			"已使用" if shop_session.refresh_used else "可用",
			intel_name,
			"已购" if shop_session.intel_unlocked else "未购",
		]
		refresh_button.disabled = shop_session.refresh_used
		intel_button.text = (
			"查看已购%s" % intel_name
			if shop_session.intel_unlocked
			else "购买%s（%d 情报券）" % [intel_name, ShopSession.INTEL_PRICE]
		)

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
	parent.add_child(token)
	token.bind_card(card, selected, disabled, role, price)
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
