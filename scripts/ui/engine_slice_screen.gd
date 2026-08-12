class_name EngineSliceScreen
extends Control

const EngineSliceRunSession = preload("res://scripts/engine_slice/engine_slice_run_session.gd")
const EngineSliceSaveStore = preload("res://scripts/engine_slice/engine_slice_save_store.gd")
const EngineSliceCatalog = preload("res://scripts/engine_slice/engine_slice_catalog.gd")
const EngineBattleState = preload("res://scripts/engine_slice/engine_battle_state.gd")
const OperationResult = preload("res://scripts/run/operation_result.gd")

const MAIN_MENU_SCENE := "res://scenes/run/main_menu_screen.tscn"
const DEFAULT_SAVE_PATH := "user://gold_engine_slice_v1.cfg"

@onready var phase_label: Label = %PhaseLabel
@onready var health_label: Label = %HealthLabel
@onready var intel_label: Label = %IntelLabel
@onready var glossary_button: Button = %GlossaryButton
@onready var home_button: Button = %HomeButton
@onready var setup_panel: Control = %SetupPanel
@onready var route_panel: Control = %RoutePanel
@onready var battle_panel: Control = %BattlePanel
@onready var reward_panel: Control = %RewardPanel
@onready var shop_panel: Control = %ShopPanel
@onready var result_panel: Control = %ResultPanel
@onready var dice_control_button: Button = %DiceControlButton
@onready var table_chain_button: Button = %TableChainButton
@onready var seed_input: LineEdit = %SeedInput
@onready var continue_button: Button = %ContinueButton
@onready var discard_button: Button = %DiscardButton
@onready var start_button: Button = %StartButton
@onready var route_title: Label = %RouteTitle
@onready var route_buttons: HBoxContainer = %RouteButtons
@onready var enemy_portrait: TextureRect = %EnemyPortrait
@onready var enemy_name: Label = %EnemyName
@onready var enemy_subtitle: Label = %EnemySubtitle
@onready var enemy_health: ProgressBar = %EnemyHealth
@onready var enemy_health_label: Label = %EnemyHealthLabel
@onready var intent_title: Label = %IntentTitle
@onready var intent_description: Label = %IntentDescription
@onready var attack_rule_label: Label = %AttackRuleLabel
@onready var guard_rule_label: Label = %GuardRuleLabel
@onready var engine_rule_label: Label = %EngineRuleLabel
@onready var engine_charge_label: Label = %EngineChargeLabel
@onready var attack_slots: HBoxContainer = %AttackSlots
@onready var guard_slots: HBoxContainer = %GuardSlots
@onready var engine_slots: HBoxContainer = %EngineSlots
@onready var preview_label: Label = %PreviewLabel
@onready var dice_row: HBoxContainer = %DiceRow
@onready var technique_row: HBoxContainer = %TechniqueRow
@onready var tactic_row: HBoxContainer = %TacticRow
@onready var error_label: Label = %ErrorLabel
@onready var undo_button: Button = %UndoButton
@onready var commit_button: Button = %CommitButton
@onready var next_turn_button: Button = %NextTurnButton
@onready var reward_buttons: HBoxContainer = %RewardButtons
@onready var reward_choice_row: HBoxContainer = %RewardChoiceRow
@onready var reward_replace_option: OptionButton = %RewardReplaceOption
@onready var reward_a_button: Button = %RewardAButton
@onready var reward_b_button: Button = %RewardBButton
@onready var reward_confirm_button: Button = %RewardConfirmButton
@onready var shop_status: Label = %ShopStatus
@onready var heal_button: Button = %HealButton
@onready var buy_tactic_button: Button = %BuyTacticButton
@onready var upgrade_option: OptionButton = %UpgradeOption
@onready var shop_upgrade_a_button: Button = %ShopUpgradeAButton
@onready var shop_upgrade_b_button: Button = %ShopUpgradeBButton
@onready var remove_option: OptionButton = %RemoveOption
@onready var remove_button: Button = %RemoveButton
@onready var leave_shop_button: Button = %LeaveShopButton
@onready var result_title: Label = %ResultTitle
@onready var result_description: Label = %ResultDescription
@onready var build_summary: Label = %BuildSummary
@onready var restart_button: Button = %RestartButton
@onready var new_run_button: Button = %NewRunButton

var session := EngineSliceRunSession.new()
var save_store := EngineSliceSaveStore.new(DEFAULT_SAVE_PATH)
var selected_build_id: StringName = EngineSliceCatalog.DICE_CONTROL
var selected_die_id: StringName = &""
var selected_technique_id: StringName = &""
var pending_reward_index := -1
var _compact_layout := false
var _glossary_dialog: AcceptDialog

func _ready() -> void:
	var root := get_tree().root
	var save_path := String(root.get_meta("engine_slice_save_path", DEFAULT_SAVE_PATH))
	save_store = EngineSliceSaveStore.new(save_path)
	home_button.pressed.connect(_on_home_pressed)
	glossary_button.pressed.connect(_on_glossary_pressed)
	dice_control_button.pressed.connect(_select_build.bind(EngineSliceCatalog.DICE_CONTROL))
	table_chain_button.pressed.connect(_select_build.bind(EngineSliceCatalog.TABLE_CHAIN))
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	undo_button.pressed.connect(_on_undo_pressed)
	commit_button.pressed.connect(_on_commit_pressed)
	next_turn_button.pressed.connect(_on_next_turn_pressed)
	reward_a_button.pressed.connect(_on_reward_branch.bind(&"a"))
	reward_b_button.pressed.connect(_on_reward_branch.bind(&"b"))
	reward_confirm_button.pressed.connect(_on_reward_replace_confirmed)
	heal_button.pressed.connect(_run_shop_action.bind(&"heal"))
	buy_tactic_button.pressed.connect(_run_shop_action.bind(&"tactic"))
	shop_upgrade_a_button.pressed.connect(_run_shop_action.bind(&"upgrade_a"))
	shop_upgrade_b_button.pressed.connect(_run_shop_action.bind(&"upgrade_b"))
	upgrade_option.item_selected.connect(_on_shop_upgrade_selected)
	remove_button.pressed.connect(_run_shop_action.bind(&"remove"))
	leave_shop_button.pressed.connect(_run_shop_action.bind(&"leave"))
	restart_button.pressed.connect(_on_restart_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	seed_input.text = str(Time.get_unix_time_from_system() as int)
	_apply_responsive_layout()
	_select_build(selected_build_id)
	_refresh()

func _on_glossary_pressed() -> void:
	if _glossary_dialog == null:
		_glossary_dialog = AcceptDialog.new()
		_glossary_dialog.title = "金线引擎术语"
		_glossary_dialog.dialog_text = (
			"破绽：满足规则后，对敌人造成骰值和 × 倍率的伤害。\n\n"
			+ "护契：满足规则后获得格挡；敌方攻击后按实际吸收量反击。保留格挡只参与下一回合一次。\n\n"
			+ "引擎：充能在本场遭遇内保留；每满3点在敌方行动前自动爆破15伤害。\n\n"
			+ "常驻手法：整场可见，每回合默认一次；每张都有独立且互斥的 A/B 分支。\n\n"
			+ "临时战术：每回合抽两张，最多使用一张，之后进入弃牌堆。"
		)
		_glossary_dialog.ok_button_text = "明白"
		add_child(_glossary_dialog)
	_glossary_dialog.popup_centered(Vector2i(720, 500))
	SfxAccess.play(self, &"panel_open")

func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	_compact_layout = viewport_size.x <= 1400.0 or viewport_size.y <= 800.0
	var root_box: VBoxContainer = $SafeArea/Root
	var header: HBoxContainer = $SafeArea/Root/Header
	var enemy_panel: Control = $SafeArea/Root/BattlePanel/EnemyPanel
	var enemy_row: HBoxContainer = $SafeArea/Root/BattlePanel/EnemyPanel/EnemyRow
	var lane_row: HBoxContainer = $SafeArea/Root/BattlePanel/LaneRow
	root_box.add_theme_constant_override("separation", 4 if _compact_layout else 12)
	battle_panel.add_theme_constant_override("separation", 4 if _compact_layout else 10)
	header.custom_minimum_size.y = 44 if _compact_layout else 60
	enemy_panel.custom_minimum_size.y = 126 if _compact_layout else 205
	enemy_row.add_theme_constant_override("separation", 8 if _compact_layout else 18)
	enemy_portrait.custom_minimum_size = Vector2(150, 116) if _compact_layout else Vector2(230, 175)
	lane_row.custom_minimum_size.y = 148 if _compact_layout else 250
	lane_row.add_theme_constant_override("separation", 8 if _compact_layout else 14)
	preview_label.custom_minimum_size.y = 28 if _compact_layout else 40
	dice_row.custom_minimum_size.y = 52 if _compact_layout else 72
	technique_row.custom_minimum_size.y = 68 if _compact_layout else 100
	tactic_row.custom_minimum_size.y = 52 if _compact_layout else 68
	phase_label.visible = not _compact_layout
	if session.phase == EngineSliceRunSession.Phase.BATTLE:
		_refresh_battle()

func _select_build(build_id: StringName) -> void:
	selected_build_id = build_id
	dice_control_button.button_pressed = build_id == EngineSliceCatalog.DICE_CONTROL
	table_chain_button.button_pressed = build_id == EngineSliceCatalog.TABLE_CHAIN
	var build := session.catalog.build_definition(build_id)
	error_label.text = String(build.get("description", ""))

func _on_start_pressed() -> void:
	if not seed_input.text.is_valid_int():
		_show_error("种子必须是正整数。")
		return
	var result := session.start_new(seed_input.text.to_int(), selected_build_id)
	if _accept(result):
		_save_session()
		_refresh()

func _on_continue_pressed() -> void:
	var loaded: Dictionary = save_store.load_snapshot()
	if not loaded.get("ok", false):
		_show_error(String(loaded.get("reason", "没有可继续的引擎切片。")))
		return
	var result := session.restore_snapshot(loaded["snapshot"])
	if _accept(result):
		selected_build_id = session.build_id
		_refresh()

func _on_discard_pressed() -> void:
	save_store.clear_save()
	session = EngineSliceRunSession.new()
	_refresh()

func _on_home_pressed() -> void:
	SfxAccess.play(self, &"ui_back")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _refresh() -> void:
	for panel in [setup_panel, route_panel, battle_panel, reward_panel, shop_panel, result_panel]:
		panel.visible = false
	phase_label.text = _phase_copy()
	health_label.text = "生命 %d / %d" % [session.player_health, EngineSliceRunSession.PLAYER_MAX_HEALTH]
	intel_label.text = "情报 %d" % session.intel
	match session.phase:
		EngineSliceRunSession.Phase.SETUP:
			setup_panel.visible = true
			_refresh_setup()
		EngineSliceRunSession.Phase.ROUTE:
			route_panel.visible = true
			_refresh_route()
		EngineSliceRunSession.Phase.BATTLE:
			battle_panel.visible = true
			_refresh_battle()
		EngineSliceRunSession.Phase.REWARD:
			reward_panel.visible = true
			_refresh_rewards()
		EngineSliceRunSession.Phase.SHOP:
			shop_panel.visible = true
			_refresh_shop()
		EngineSliceRunSession.Phase.RESULT:
			result_panel.visible = true
			_refresh_result()

func _refresh_setup() -> void:
	continue_button.disabled = not save_store.has_save()
	discard_button.visible = save_store.has_save()
	_select_build(selected_build_id)

func _refresh_route() -> void:
	_clear_children(route_buttons)
	route_title.text = "第一组路线 · 建立引擎" if session.route_stage == 0 else "第二组路线 · 压力校核"
	for enemy_id in session.route_options():
		var enemy := session.catalog.enemy(enemy_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(410, 190)
		button.text = "%s\n%s\n生命 %d  ·  狂暴 R%d\n破绽：%s\n护契：%s\n引擎：%s" % [
			enemy.display_name,
			enemy.subtitle,
			enemy.max_health,
			enemy.enrage_turn,
			enemy.attack_rule.get("display_name", ""),
			enemy.guard_rule.get("display_name", ""),
			enemy.engine_rule.get("display_name", ""),
		]
		button.pressed.connect(_on_route_selected.bind(enemy_id))
		route_buttons.add_child(button)

func _on_route_selected(enemy_id: StringName) -> void:
	if _accept(session.choose_route(enemy_id)):
		SfxAccess.play(self, &"route_select")
		_save_session()
		_refresh()

func _refresh_battle() -> void:
	var enemy := session.current_enemy()
	var intent := session.current_intent()
	var state := session.battle.state
	enemy_name.text = enemy.display_name
	var phase_copy := "阶段 II" if not enemy.phase_two_intent_ids.is_empty() and state.enemy_health <= ceili(float(enemy.max_health) * enemy.phase_two_threshold) else "阶段 I"
	enemy_subtitle.text = "%s  ·  %s  ·  回合 %d  ·  狂暴从 R%d 开始" % [enemy.subtitle, phase_copy, state.turn, enemy.enrage_turn]
	enemy_health.max_value = enemy.max_health
	enemy_health.value = state.enemy_health
	enemy_health_label.text = "对手 %d / %d" % [state.enemy_health, enemy.max_health]
	if not enemy.portrait_path.is_empty() and ResourceLoader.exists(enemy.portrait_path):
		enemy_portrait.texture = load(enemy.portrait_path)
	else:
		enemy_portrait.texture = null
	intent_title.text = "%s  ·  基础伤害 %d" % [intent.display_name, intent.damage]
	intent_description.text = intent.description
	attack_rule_label.text = "%s · 骰值和 ×%d" % [enemy.attack_rule.get("display_name", ""), state.attack_multiplier]
	guard_rule_label.text = "%s · 骰值和 ×%d" % [enemy.guard_rule.get("display_name", ""), state.guard_multiplier]
	engine_rule_label.text = "%s · 下轮额外骰" % enemy.engine_rule.get("display_name", "")
	engine_charge_label.text = "充能 %d/3 · 满3爆破15" % state.engine_charge
	_render_slots(attack_slots, &"attack", 2)
	_render_slots(guard_slots, &"guard", 2)
	_render_slots(engine_slots, &"engine", 1)
	_render_dice()
	_render_techniques()
	_render_tactics()
	var report := session.battle.preview(enemy, intent)
	preview_label.text = "行动前：破绽 %d + 爆破 %d  ·  护契 %d（预计吸收%d）· 充能 %d→%d  ·  行动后反击 %d" % [
		report.attack_damage, report.engine_damage, report.block, report.block_absorbed,
		report.engine_charge_before, report.engine_charge_after, report.counter_damage
	]
	var can_build := state.phase == EngineBattleState.Phase.BUILD
	commit_button.disabled = not can_build
	undo_button.disabled = not can_build
	next_turn_button.visible = state.phase == EngineBattleState.Phase.RESOLVED
	if state.phase == EngineBattleState.Phase.RESOLVED and session.last_report != null:
		error_label.text = session.last_report.summary()
	elif can_build:
		error_label.text = _selection_hint()

func _render_slots(container: HBoxContainer, lane_id: StringName, capacity: int) -> void:
	_clear_children(container)
	var assigned: Array = session.battle.state.assignments.get(lane_id, [])
	for index in capacity:
		var button := Button.new()
		button.custom_minimum_size = Vector2(82, 58) if _compact_layout else Vector2(112, 74)
		if index < assigned.size():
			var die_id: StringName = assigned[index]
			var die := session.battle.state.find_die(die_id)
			button.text = "%s\n%d" % [String(die_id).to_upper(), die.value]
			button.pressed.connect(_on_unassign_die.bind(die_id))
		else:
			button.text = "+\n投入骰子"
			button.disabled = selected_die_id == &"" or session.battle.state.phase != EngineBattleState.Phase.BUILD
			button.pressed.connect(_on_assign_selected.bind(lane_id))
		container.add_child(button)

func _render_dice() -> void:
	_clear_children(dice_row)
	for die in session.battle.state.dice:
		var button := Button.new()
		button.custom_minimum_size = Vector2(68, 50) if _compact_layout else Vector2(86, 72)
		var lane := session.battle.state.assigned_lane(die.id)
		var consumed := die.id in session.battle.state.consumed_die_ids
		button.text = "%s\n%d%s" % [String(die.id).to_upper(), die.value, " · %s" % lane if lane != &"" else ""]
		button.disabled = consumed or lane != &"" or session.battle.state.phase != EngineBattleState.Phase.BUILD
		button.button_pressed = die.id == selected_die_id
		button.toggle_mode = true
		if consumed:
			button.text = "%s\n已消耗" % String(die.id).to_upper()
		button.pressed.connect(_on_die_pressed.bind(die.id))
		dice_row.add_child(button)

func _render_techniques() -> void:
	_clear_children(technique_row)
	for technique_id in session.battle.state.technique_ids:
		var definition := session.catalog.technique(technique_id)
		var branch: StringName = session.battle.state.technique_upgrades.get(technique_id, &"")
		var button := Button.new()
		button.custom_minimum_size = Vector2(184, 64) if _compact_layout else Vector2(230, 110)
		button.clip_text = _compact_layout
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if _compact_layout else TextServer.OVERRUN_NO_TRIMMING
		button.toggle_mode = true
		button.button_pressed = selected_technique_id == technique_id
		var branch_copy := definition.branch_description(branch)
		button.text = "%s%s\n[%s · %s]%s" % [
			definition.display_name,
			" · %s" % String(branch).to_upper() if branch != &"" else "",
			definition.socket_copy(),
			definition.lane_tag_copy(),
			"" if _compact_layout else " " + branch_copy,
		]
		button.tooltip_text = branch_copy
		button.disabled = (
			technique_id == session.battle.state.locked_technique_id
			or int(session.battle.state.technique_uses.get(technique_id, 0)) >= 1
			or session.battle.state.phase != EngineBattleState.Phase.BUILD
		)
		button.pressed.connect(_on_technique_pressed.bind(technique_id))
		technique_row.add_child(button)

func _render_tactics() -> void:
	_clear_children(tactic_row)
	for tactic_id in session.battle.state.tactic_hand:
		var definition := session.catalog.tactic(tactic_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 48) if _compact_layout else Vector2(270, 82)
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.text = "%s%s" % [definition.display_name, "" if _compact_layout else "\n" + definition.description]
		button.tooltip_text = definition.description
		button.disabled = session.battle.state.tactic_used_id != &"" or session.battle.state.phase != EngineBattleState.Phase.BUILD
		button.pressed.connect(_on_tactic_pressed.bind(tactic_id))
		tactic_row.add_child(button)

func _on_die_pressed(die_id: StringName) -> void:
	var activated_technique := false
	if selected_technique_id != &"":
		var result := session.battle.activate_technique(selected_technique_id, die_id)
		if _accept(result):
			SfxAccess.play(self, &"card_play")
			activated_technique = true
			selected_technique_id = &""
			selected_die_id = &""
	else:
		selected_die_id = &"" if selected_die_id == die_id else die_id
		SfxAccess.play(self, &"die_select")
	_refresh_battle()
	if activated_technique and session.battle.state.is_available(die_id):
		error_label.text = "手法已处理骰子；现在选择这颗骰子，再投入上方规则台形成连锁。"

func _on_technique_pressed(technique_id: StringName) -> void:
	selected_technique_id = &"" if selected_technique_id == technique_id else technique_id
	selected_die_id = &""
	_refresh_battle()

func _on_tactic_pressed(tactic_id: StringName) -> void:
	if _accept(session.battle.activate_tactic(tactic_id)):
		SfxAccess.play(self, &"card_play")
		selected_die_id = &""
		selected_technique_id = &""
	_refresh_battle()

func _on_assign_selected(lane_id: StringName) -> void:
	if selected_die_id == &"":
		return
	if _accept(session.battle.assign_die(selected_die_id, lane_id)):
		SfxAccess.play(self, &"die_place")
		selected_die_id = &""
	_refresh_battle()

func _on_unassign_die(die_id: StringName) -> void:
	_accept(session.battle.unassign_die(die_id))
	_refresh_battle()

func _on_undo_pressed() -> void:
	if _accept(session.battle.undo()):
		SfxAccess.play(self, &"undo")
		selected_die_id = &""
		selected_technique_id = &""
	_refresh_battle()

func _on_commit_pressed() -> void:
	var report := session.commit_turn()
	if not report.valid:
		_show_error(report.reason)
		return
	SfxAccess.play(self, &"resolution_climax" if report.enemy_defeated else &"round_commit")
	_save_session()
	_refresh()
	if session.phase == EngineSliceRunSession.Phase.BATTLE:
		error_label.text = report.summary()

func _on_next_turn_pressed() -> void:
	if _accept(session.start_next_turn()):
		selected_die_id = &""
		selected_technique_id = &""
		_save_session()
		_refresh()

func _refresh_rewards() -> void:
	pending_reward_index = -1
	reward_choice_row.visible = false
	_clear_children(reward_buttons)
	for index in session.reward_options.size():
		var option := session.reward_options[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(340, 190)
		button.text = _reward_copy(option)
		button.pressed.connect(_on_reward_selected.bind(index))
		reward_buttons.add_child(button)

func _reward_copy(option: Dictionary) -> String:
	var kind := StringName(option["kind"])
	if kind == &"tactic":
		var tactic := session.catalog.tactic(option["id"])
		return "临时战术\n%s\n\n%s" % [tactic.display_name, tactic.description]
	var technique := session.catalog.technique(option["id"])
	if kind == &"upgrade":
		return "A / B 升级\n%s\n\nA · %s：%s\nB · %s：%s" % [technique.display_name, technique.branch_name(&"a"), technique.branch_description(&"a"), technique.branch_name(&"b"), technique.branch_description(&"b")]
	return "新常驻手法\n%s\n[%s]\n%s" % [technique.display_name, technique.socket_copy(), technique.description]

func _on_reward_selected(index: int) -> void:
	pending_reward_index = index
	var option := session.reward_options[index]
	var kind := StringName(option["kind"])
	reward_choice_row.visible = true
	reward_replace_option.visible = false
	reward_confirm_button.visible = false
	reward_a_button.visible = false
	reward_b_button.visible = false
	if kind == &"upgrade":
		var technique := session.catalog.technique(option["id"])
		reward_a_button.text = "A · %s" % technique.branch_name(&"a")
		reward_b_button.text = "B · %s" % technique.branch_name(&"b")
		reward_a_button.tooltip_text = technique.branch_description(&"a")
		reward_b_button.tooltip_text = technique.branch_description(&"b")
		reward_a_button.visible = true
		reward_b_button.visible = true
	elif kind == &"technique" and session.technique_ids.size() >= EngineSliceRunSession.MAX_TECHNIQUES:
		_populate_technique_option(reward_replace_option, session.technique_ids)
		reward_replace_option.visible = true
		reward_confirm_button.visible = true
	else:
		_finish_reward(index)

func _on_reward_branch(branch: StringName) -> void:
	_finish_reward(pending_reward_index, branch)

func _on_reward_replace_confirmed() -> void:
	if reward_replace_option.selected < 0:
		return
	var replace_id: StringName = reward_replace_option.get_item_metadata(reward_replace_option.selected)
	_finish_reward(pending_reward_index, &"", replace_id)

func _finish_reward(index: int, branch: StringName = &"", replace_id: StringName = &"") -> void:
	if _accept(session.choose_reward(index, branch, replace_id)):
		SfxAccess.play(self, &"card_select")
		_save_session()
		_refresh()

func _refresh_shop() -> void:
	shop_status.text = "生命 %d / 40 · 情报 %d。消费立即生效，离店后进入第二组路线。" % [session.player_health, session.intel]
	var upgradeable: Array[StringName] = []
	for technique_id in session.technique_ids:
		if not session.technique_upgrades.has(technique_id):
			upgradeable.append(technique_id)
	_populate_technique_option(upgrade_option, upgradeable)
	_populate_tactic_option(remove_option, session.tactic_ids)
	_refresh_shop_upgrade_copy()
	heal_button.disabled = session.intel < 2 or session.player_health >= EngineSliceRunSession.PLAYER_MAX_HEALTH
	buy_tactic_button.disabled = session.intel < 2
	shop_upgrade_a_button.disabled = session.intel < 3 or upgradeable.is_empty()
	shop_upgrade_b_button.disabled = shop_upgrade_a_button.disabled
	remove_button.disabled = session.intel < 1 or session.tactic_ids.size() <= 4

func _on_shop_upgrade_selected(_index: int) -> void:
	_refresh_shop_upgrade_copy()

func _refresh_shop_upgrade_copy() -> void:
	if upgrade_option.selected < 0 or upgrade_option.item_count == 0:
		shop_upgrade_a_button.text = "A · 无可升级手法"
		shop_upgrade_b_button.text = "B · 无可升级手法"
		return
	var technique_id: StringName = upgrade_option.get_item_metadata(upgrade_option.selected)
	var technique := session.catalog.technique(technique_id)
	shop_upgrade_a_button.text = "A · %s" % technique.branch_name(&"a")
	shop_upgrade_b_button.text = "B · %s" % technique.branch_name(&"b")
	shop_upgrade_a_button.tooltip_text = technique.branch_description(&"a")
	shop_upgrade_b_button.tooltip_text = technique.branch_description(&"b")

func _run_shop_action(action: StringName) -> void:
	var result: OperationResult
	match action:
		&"heal":
			result = session.buy_heal()
		&"tactic":
			result = session.buy_tactic()
		&"upgrade_a", &"upgrade_b":
			if upgrade_option.selected < 0:
				_show_error("没有可升级的常驻手法。")
				return
			var technique_id: StringName = upgrade_option.get_item_metadata(upgrade_option.selected)
			result = session.buy_upgrade(technique_id, &"a" if action == &"upgrade_a" else &"b")
		&"remove":
			if remove_option.selected < 0:
				_show_error("没有可移除的临时战术。")
				return
			var tactic_id: StringName = remove_option.get_item_metadata(remove_option.selected)
			result = session.remove_tactic(tactic_id)
		&"leave":
			result = session.leave_shop()
		_:
			return
	if _accept(result):
		SfxAccess.play(self, &"shop_purchase" if action != &"leave" else &"ui_confirm")
		_save_session()
		_refresh()

func _refresh_result() -> void:
	var won := session.player_health > 0 and session.current_enemy_id == &"dealer_iron_abacus_engine"
	result_title.text = "总账清零" if won else "金线断裂"
	result_description.text = session.result_copy
	var techniques: Array[String] = []
	for technique_id in session.technique_ids:
		var definition := session.catalog.technique(technique_id)
		var branch := String(session.technique_upgrades.get(technique_id, &""))
		techniques.append("%s%s" % [definition.display_name, "(%s)" % branch.to_upper() if not branch.is_empty() else ""])
	build_summary.text = "种子 %d · %s\n常驻手法：%s\n临时战术：%d 张 · 剩余生命：%d" % [
		session.seed_value,
		session.catalog.build_definition(session.build_id).get("display_name", ""),
		" / ".join(techniques),
		session.tactic_ids.size(),
		session.player_health,
	]

func _on_restart_pressed() -> void:
	var result := session.start_new(session.seed_value, session.build_id)
	if _accept(result):
		_save_session()
		_refresh()

func _on_new_run_pressed() -> void:
	save_store.clear_save()
	session = EngineSliceRunSession.new()
	seed_input.text = str(Time.get_unix_time_from_system() as int)
	_refresh()

func _populate_technique_option(option: OptionButton, ids: Array[StringName]) -> void:
	option.clear()
	for technique_id in ids:
		var definition := session.catalog.technique(technique_id)
		option.add_item(definition.display_name)
		option.set_item_metadata(option.item_count - 1, technique_id)

func _populate_tactic_option(option: OptionButton, ids: Array[StringName]) -> void:
	option.clear()
	for tactic_id in ids:
		var definition := session.catalog.tactic(tactic_id)
		option.add_item(definition.display_name)
		option.set_item_metadata(option.item_count - 1, tactic_id)

func _selection_hint() -> String:
	if selected_technique_id != &"":
		return "已选择手法：再点一颗符合插槽的骰子。"
	if selected_die_id != &"":
		return "已选择骰子：投入上方规则台，或再点一次取消。"
	return "先处理骰值，再分配到破绽、护契与引擎；提交前可逐步撤销。"

func _phase_copy() -> String:
	match session.phase:
		EngineSliceRunSession.Phase.SETUP:
			return "试玩配置"
		EngineSliceRunSession.Phase.ROUTE:
			return "路线二选一"
		EngineSliceRunSession.Phase.BATTLE:
			return "战斗"
		EngineSliceRunSession.Phase.REWARD:
			return "战后成长"
		EngineSliceRunSession.Phase.SHOP:
			return "商店 / 休整"
		EngineSliceRunSession.Phase.RESULT:
			return "结算"
	return ""

func _save_session() -> void:
	var result: OperationResult = save_store.save_snapshot(session.to_snapshot())
	if not result.accepted:
		_show_error(result.reason)

func _accept(result: OperationResult) -> bool:
	if result == null or not result.accepted:
		_show_error(result.reason if result != null else "操作未完成。")
		return false
	return true

func _show_error(message: String) -> void:
	error_label.text = message
	shop_status.text = message
	SfxAccess.play(self, &"error")

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
