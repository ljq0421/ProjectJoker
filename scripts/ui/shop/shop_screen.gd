class_name ShopScreen
extends Control

signal leave_requested

const CARD_SCENE = preload("res://scenes/components/shop_card_token.tscn")

@onready var deck_grid: GridContainer = %DeckGrid
@onready var offer_column: VBoxContainer = %OfferColumn
@onready var ticket_label: Label = %TicketLabel
@onready var selection_label: Label = %ShopSelectionLabel
@onready var error_label: Label = %ShopErrorLabel
@onready var confirm_button: Button = %ConfirmReplacementButton
@onready var leave_button: Button = %LeaveShopButton

var shop_session: ShopSession
var catalog: CardCatalog
var selected_offer_id: StringName = &""
var selected_deck_id: StringName = &""

func _ready() -> void:
	visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)
	leave_button.pressed.connect(func() -> void: leave_requested.emit())

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
	if role == &"offer":
		selected_offer_id = card_id
	elif role == &"deck":
		selected_deck_id = card_id
	error_label.text = ""
	_refresh()

func _on_confirm_pressed() -> void:
	var result := shop_session.purchase(selected_offer_id, selected_deck_id)
	error_label.text = result.reason
	if result.accepted:
		selected_offer_id = &""
		selected_deck_id = &""
	_refresh()

func _card_name(card_id: StringName) -> String:
	if card_id == &"":
		return "未选择"
	var card := catalog.find_card(card_id)
	return "未知" if card == null else card.display_name
