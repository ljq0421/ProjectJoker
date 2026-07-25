# Single-Encounter Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add a first-run, skippable, replayable onboarding flow that teaches the complete deterministic 44→51→44→51 single-encounter solution through real player actions.

**Architecture:** Keep persistence in a small `RefCounted` store and tutorial decisions in a pure `SingleEncounterTutorialFlow`. A scene-backed overlay renders instructions and focus rings, while `SingleEncounterScreen` remains the only adapter that calls `SingleEncounterSession`; it guards requested UI actions and reports only accepted actions to the tutorial.

**Tech Stack:** Godot 4.6.1, typed GDScript, `.tscn` scene composition, `ConfigFile`, existing dependency-free test runner, asynchronous headless scene checks using real `InputEventMouseMotion` and `InputEventMouseButton` objects.

## Global Constraints

- Use `D:\Godot\Godot_v4.6.1-stable_win64_console.exe` for automated checks.
- Every headless Godot command passes `--log-file` to a writable path under `$env:TEMP`.
- Treat `SCRIPT ERROR` or `Failed to load script` as failure even when Godot exits `0`.
- Preserve the 1920×1080 logical viewport, 1280×720 display override, Mobile renderer, and `canvas_items + keep` stretch settings.
- The default persistence path is exactly `user://onboarding.cfg`.
- Automated tests inject a unique file under `OS.get_temp_dir()` and never read or overwrite real onboarding state.
- Completion and skip persist `done=true`; replay persists `done=false` before resetting the teaching encounter.
- Skip never grants a reward and does not itself mutate the encounter.
- Tutorial replay resets the encounter through `SingleEncounterFixture`; tutorial code never mutates `RoundState`.
- Only `RoundResolver.resolve()` calculates prediction and committed score.
- The prescribed tutorial sequence reaches 44, 51, 44, 51 and commits at 51.
- Existing layout and input checks instantiate the screen with `tutorial_auto_start=false`.
- Real-input checks use `Window.push_input()`; do not manually emit component signals.
- Documentation remains staged and uncommitted.
- Code commits use `git commit --only` with explicit code/test paths so staged documentation is excluded.

## File Map

```text
res://
  scenes/
    components/
      single_encounter_tutorial.tscn
    run/
      single_encounter_screen.tscn
  scripts/
    ui/
      single_encounter_screen.gd
      tutorial/
        single_encounter_tutorial.gd
        single_encounter_tutorial_flow.gd
        tutorial_progress_store.gd
  tests/
    single_encounter_input_self_check.gd
    single_encounter_layout_self_check.gd
    single_encounter_tutorial_flow_test.gd
    tutorial_input_self_check.gd
    tutorial_layout_self_check.gd
    tutorial_progress_store_test.gd
    ui_component_contract_test.gd
```

---

### Task 1: Tutorial Progress Store

**Files:**
- Create: `scripts/ui/tutorial/tutorial_progress_store.gd`
- Create: `tests/tutorial_progress_store_test.gd`

**Interfaces:**
- Consumes: Godot `ConfigFile` and a configurable absolute or `user://` path.
- Produces: `TutorialProgressStore.new(path)`, `is_done() -> bool`, `mark_done() -> Error`, and `reset() -> Error`.

- [x] **Step 1: Write the failing persistence test**

Create `tests/tutorial_progress_store_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const StoreScript = preload("res://scripts/ui/tutorial/tutorial_progress_store.gd")

func run() -> void:
	var path := OS.get_temp_dir().path_join(
		"project-joker-onboarding-store-%d.cfg" % Time.get_ticks_usec()
	)
	DirAccess.remove_absolute(path)

	var first = StoreScript.new(path)
	assert_false(first.is_done(), "missing onboarding config should default to not done")
	assert_equal(first.mark_done(), OK, "mark_done should save successfully")
	assert_true(StoreScript.new(path).is_done(), "done state should persist across instances")
	assert_equal(first.reset(), OK, "reset should save successfully")
	assert_false(StoreScript.new(path).is_done(), "reset should persist not-done state")

	DirAccess.remove_absolute(path)
```

- [x] **Step 2: Run the suite and verify the store is missing**

```powershell
$task1Log = Join-Path $env:TEMP 'project-joker-tutorial-task1-red.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $task1Log -s res://tests/run_all.gd
```

Expected: `tutorial_progress_store.gd` preload failure.

- [x] **Step 3: Implement the progress store**

Create `scripts/ui/tutorial/tutorial_progress_store.gd`:

```gdscript
class_name TutorialProgressStore
extends RefCounted

const SECTION := "onboarding"
const DONE_KEY := "done"

var config_path: String

func _init(path: String = "user://onboarding.cfg") -> void:
	config_path = path

func is_done() -> bool:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return false
	return bool(config.get_value(SECTION, DONE_KEY, false))

func mark_done() -> Error:
	return _save(true)

func reset() -> Error:
	return _save(false)

func _save(value: bool) -> Error:
	var config := ConfigFile.new()
	config.set_value(SECTION, DONE_KEY, value)
	return config.save(config_path)
```

- [x] **Step 4: Import and run all synchronous tests**

```powershell
$task1ImportLog = Join-Path $env:TEMP 'project-joker-tutorial-task1-import.log'
$task1TestLog = Join-Path $env:TEMP 'project-joker-tutorial-task1.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $task1ImportLog --import
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $task1TestLog -s res://tests/run_all.gd
```

Expected: the new store test passes and both logs contain no script errors.

- [x] **Step 5: Commit store and test only**

```powershell
git add scripts/ui/tutorial/tutorial_progress_store.gd scripts/ui/tutorial/tutorial_progress_store.gd.uid tests/tutorial_progress_store_test.gd tests/tutorial_progress_store_test.gd.uid
git commit --only scripts/ui/tutorial/tutorial_progress_store.gd scripts/ui/tutorial/tutorial_progress_store.gd.uid tests/tutorial_progress_store_test.gd tests/tutorial_progress_store_test.gd.uid -m "feat: persist onboarding completion"
```

---

### Task 2: Pure Tutorial Flow

**Files:**
- Create: `scripts/ui/tutorial/single_encounter_tutorial_flow.gd`
- Create: `tests/single_encounter_tutorial_flow_test.gd`

**Interfaces:**
- Consumes: `SingleEncounterSession`, accepted semantic UI actions, and action payload dictionaries.
- Produces: `start()`, `allows(action, payload, session)`, `record_accepted_action(action, payload, session)`, `continue_step(session)`, `instruction(session)`, `target_specs(session)`, and `can_finish(session)`.

- [x] **Step 1: Write the failing full-flow test**

Create `tests/single_encounter_tutorial_flow_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const FlowScript = preload("res://scripts/ui/tutorial/single_encounter_tutorial_flow.gd")

func run() -> void:
	var flow = FlowScript.new()
	var session := SingleEncounterSession.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand()
	)
	flow.start()
	assert_equal(flow.step_index, 0, "tutorial should start at welcome")
	assert_false(
		flow.allows(&"select_die", {"die_id": &"d6"}, session),
		"welcome should block gameplay"
	)
	assert_true(flow.continue_step(session), "welcome continue should advance")

	_accept(
		flow,
		session,
		&"drag_assign",
		{"die_id": &"d1", "table_id": &"left"},
		func() -> bool: return session.assign_dropped_die(&"d1", &"left")
	)
	_accept(
		flow,
		session,
		&"select_die",
		{"die_id": &"d6"},
		func() -> bool: return session.activate_die(&"d6")
	)
	_accept(
		flow,
		session,
		&"click_assign",
		{"die_id": &"d6", "table_id": &"left"},
		func() -> bool: return session.activate_table(&"left")
	)

	for die_id in [&"d2", &"d3", &"d4"]:
		_accept(
			flow,
			session,
			&"select_die",
			{"die_id": die_id},
			func() -> bool: return session.activate_die(die_id)
		)
		_accept(
			flow,
			session,
			&"click_assign",
			{"die_id": die_id, "table_id": &"middle"},
			func() -> bool: return session.activate_table(&"middle")
		)

	_accept(
		flow,
		session,
		&"select_die",
		{"die_id": &"d5"},
		func() -> bool: return session.activate_die(&"d5")
	)
	_accept(
		flow,
		session,
		&"calibrate",
		{"die_id": &"d5", "delta": -1},
		func() -> bool: return session.calibrate_die(&"d5", -1)
	)
	_accept(
		flow,
		session,
		&"click_assign",
		{"die_id": &"d5", "table_id": &"right"},
		func() -> bool: return session.activate_table(&"right")
	)
	assert_equal(session.preview().total, 44, "completed base placement should be 44")

	_play_mapping(flow, session)
	assert_equal(session.preview().total, 51, "mapping lesson should reach 51")
	assert_equal(flow.step_index, 6, "prediction lesson should follow card play")
	assert_true(flow.continue_step(session), "prediction continue should advance")

	_accept(
		flow,
		session,
		&"undo",
		{},
		func() -> bool: return session.undo()
	)
	assert_equal(session.preview().total, 44, "undo lesson should restore 44")

	_play_mapping(flow, session)
	assert_equal(session.preview().total, 51, "reapply lesson should return to 51")
	_accept(
		flow,
		session,
		&"commit",
		{},
		func() -> bool: return session.commit().valid
	)
	assert_equal(flow.step_index, 10, "valid 51 commit should reach completion")
	assert_true(flow.can_finish(session), "completion should be finishable")

func _play_mapping(flow, session) -> void:
	_accept(
		flow,
		session,
		&"select_card",
		{"card_index": 1},
		func() -> bool: return session.activate_card(1)
	)
	_accept(
		flow,
		session,
		&"card_table",
		{"card_index": 1, "table_id": &"left"},
		func() -> bool: return session.activate_table(&"left")
	)

func _accept(flow, session, action: StringName, payload: Dictionary, operation: Callable) -> void:
	assert_true(flow.allows(action, payload, session), "tutorial should allow %s" % action)
	assert_true(operation.call(), "session should accept %s" % action)
	flow.record_accepted_action(action, payload, session)
```

- [x] **Step 2: Run and verify the flow class is missing**

Run the synchronous suite with a writable `$env:TEMP` log.

Expected: preload failure for `single_encounter_tutorial_flow.gd`.

- [x] **Step 3: Implement the finite tutorial state machine**

Create `scripts/ui/tutorial/single_encounter_tutorial_flow.gd`:

```gdscript
class_name SingleEncounterTutorialFlow
extends RefCounted

const LAST_STEP := 10

var step_index: int = 0
var blocked_feedback: String = ""

func start() -> void:
	step_index = 0
	blocked_feedback = ""

func allows(action: StringName, payload: Dictionary, session: SingleEncounterSession) -> bool:
	var allowed := false
	match step_index:
		1:
			allowed = (
				action == &"drag_assign"
				and payload.get("die_id") == &"d1"
				and payload.get("table_id") == &"left"
			)
		2:
			allowed = (
				action == &"select_die" and payload.get("die_id") == &"d6"
			) or (
				action == &"click_assign"
				and payload.get("die_id") == &"d6"
				and payload.get("table_id") == &"left"
			)
		3:
			allowed = _allows_middle_action(action, payload)
		4:
			allowed = _allows_calibration_action(action, payload, session)
		5, 8:
			allowed = (
				action == &"select_card" and payload.get("card_index") == 1
			) or (
				action == &"card_table"
				and payload.get("card_index") == 1
				and payload.get("table_id") == &"left"
			)
		7:
			allowed = action == &"undo"
		9:
			allowed = action == &"commit"
	blocked_feedback = "" if allowed else _blocked_instruction()
	return allowed

func record_accepted_action(
	action: StringName,
	_payload: Dictionary,
	session: SingleEncounterSession
) -> void:
	blocked_feedback = ""
	match step_index:
		1:
			if action == &"drag_assign" and _contains(&"left", &"d1", session):
				step_index = 2
		2:
			if action == &"click_assign" and _contains(&"left", &"d6", session):
				step_index = 3
		3:
			if _has_exact(&"middle", [&"d2", &"d3", &"d4"], session):
				step_index = 4
		4:
			var d5 := session.controller.state.find_die(&"d5")
			if d5 != null and d5.value == 4 and _contains(&"right", &"d5", session):
				step_index = 5
		5:
			if session.is_card_used(1) and session.preview().total == 51:
				step_index = 6
		7:
			if not session.is_card_used(1) and session.preview().total == 44:
				step_index = 8
		8:
			if session.is_card_used(1) and session.preview().total == 51:
				step_index = 9
		9:
			if session.controller.committed and session.commit().total == 51:
				step_index = 10

func continue_step(session: SingleEncounterSession) -> bool:
	if step_index == 0:
		step_index = 1
		blocked_feedback = ""
		return true
	if step_index == 6 and session.preview().total == 51:
		step_index = 7
		blocked_feedback = ""
		return true
	blocked_feedback = "请先完成当前步骤"
	return false

func can_finish(session: SingleEncounterSession) -> bool:
	return (
		step_index == LAST_STEP
		and session.controller.committed
		and session.commit().total == 51
	)

func instruction(session: SingleEncounterSession) -> String:
	if not blocked_feedback.is_empty():
		return blocked_feedback
	match step_index:
		0:
			return "三条规则轨会按顺序解析；右侧会实时展示每一步得分。"
		1:
			return "按住骰子 1，把它拖到左侧“精确为 7”规则轨。"
		2:
			return "先点击骰子 6，再点击左侧规则轨。"
		3:
			return "把骰子 2、3、4 放入中间规则轨，凑成连续三数。"
		4:
			var d5 := session.controller.state.find_die(&"d5")
			if d5 != null and d5.value == 5:
				return "选择骰子 5，点击“点数 -1”把它校准为 4。"
			return "把校准后的骰子 4 放入右侧“单枚偶数”规则轨。"
		5:
			return "选择“映射”手法牌，再点击左侧规则轨。"
		6:
			return "右侧预测已达到 51。每个增量和累计值都在确认前可见。"
		7:
			return "点击“撤销”，观察手法牌返回且预测回到 44。"
		8:
			return "再次把“映射”用于左侧规则轨，让预测回到 51。"
		9:
			return "点击“确认结算”。正式结果必须与预测完全一致。"
		10:
			return "你已完成三轨教学：分配、校准、用牌、预览和撤销都由你控制。"
	return ""

func target_specs(session: SingleEncounterSession) -> Array[Dictionary]:
	match step_index:
		0:
			return [
				{"kind": &"lane", "id": &"left"},
				{"kind": &"lane", "id": &"middle"},
				{"kind": &"lane", "id": &"right"},
				{"kind": &"control", "id": &"ResolutionPanel"},
			]
		1:
			return [_die(&"d1"), _lane(&"left")]
		2:
			return [_die(&"d6"), _lane(&"left")]
		3:
			var targets: Array[Dictionary] = [_lane(&"middle")]
			for die_id in [&"d2", &"d3", &"d4"]:
				if not _contains(&"middle", die_id, session):
					targets.append(_die(die_id))
			return targets
		4:
			return [_die(&"d5"), _control(&"MinusButton"), _lane(&"right")]
		5, 8:
			return [_card(1), _lane(&"left")]
		6:
			return [_control(&"ResolutionPanel")]
		7:
			return [_control(&"UndoButton")]
		9:
			return [_control(&"ConfirmButton")]
	return []

func _allows_middle_action(action: StringName, payload: Dictionary) -> bool:
	var die_id: StringName = payload.get("die_id", &"")
	return (
		die_id in [&"d2", &"d3", &"d4"]
		and (
			action == &"select_die"
			or (
				action in [&"click_assign", &"drag_assign"]
				and payload.get("table_id") == &"middle"
			)
		)
	)

func _allows_calibration_action(
	action: StringName,
	payload: Dictionary,
	session: SingleEncounterSession
) -> bool:
	if payload.get("die_id") != &"d5":
		return false
	if action == &"select_die":
		return true
	if action == &"calibrate":
		return payload.get("delta") == -1
	if action in [&"click_assign", &"drag_assign"]:
		var d5 := session.controller.state.find_die(&"d5")
		return d5 != null and d5.value == 4 and payload.get("table_id") == &"right"
	return false

func _blocked_instruction() -> String:
	match step_index:
		0:
			return "先阅读三轨与结算轨迹，再点击“继续”。"
		1:
			return "这一步请把骰子 1 拖到左侧规则轨。"
		2:
			return "这一步先选择骰子 6，再点击左侧规则轨。"
		3:
			return "这一步只操作骰子 2、3、4 和中间规则轨。"
		4:
			return "这一步只校准并放置骰子 5。"
		5, 8:
			return "这一步只把“映射”用于左侧规则轨。"
		6:
			return "先查看右侧预测，再点击“继续”。"
		7:
			return "这一步请点击“撤销”。"
		9:
			return "预测为 51 后再点击“确认结算”。"
		10:
			return "点击“完成”关闭引导。"
	return "请按高亮目标操作。"

func _contains(table_id: StringName, die_id: StringName, session: SingleEncounterSession) -> bool:
	return die_id in session.controller.state.assignments.get(table_id, [])

func _has_exact(table_id: StringName, ids: Array, session: SingleEncounterSession) -> bool:
	var assigned: Array = session.controller.state.assignments.get(table_id, [])
	return assigned.size() == ids.size() and ids.all(
		func(id: StringName) -> bool: return id in assigned
	)

func _die(id: StringName) -> Dictionary:
	return {"kind": &"die", "id": id}

func _card(index: int) -> Dictionary:
	return {"kind": &"card", "id": index}

func _lane(id: StringName) -> Dictionary:
	return {"kind": &"lane", "id": id}

func _control(id: StringName) -> Dictionary:
	return {"kind": &"control", "id": id}
```

- [x] **Step 4: Import and run the synchronous suite**

Expected: the flow reaches steps `0→1→2→3→4→5→6→7→8→9→10`, with totals `44→51→44→51`.

- [x] **Step 5: Commit flow and test only**

```powershell
git add scripts/ui/tutorial/single_encounter_tutorial_flow.gd scripts/ui/tutorial/single_encounter_tutorial_flow.gd.uid tests/single_encounter_tutorial_flow_test.gd tests/single_encounter_tutorial_flow_test.gd.uid
git commit --only scripts/ui/tutorial/single_encounter_tutorial_flow.gd scripts/ui/tutorial/single_encounter_tutorial_flow.gd.uid tests/single_encounter_tutorial_flow_test.gd tests/single_encounter_tutorial_flow_test.gd.uid -m "feat: add onboarding flow model"
```

---

### Task 3: Tutorial Overlay Component

**Files:**
- Create: `scripts/ui/tutorial/single_encounter_tutorial.gd`
- Create: `scenes/components/single_encounter_tutorial.tscn`
- Modify: `tests/ui_component_contract_test.gd`

**Interfaces:**
- Consumes: `SingleEncounterTutorialFlow`, `TutorialProgressStore`, `SingleEncounterScreen.find_tutorial_target()`, and `SingleEncounterScreen.reset_teaching_encounter()`.
- Produces: `configure(screen, store)`, `maybe_start()`, `start(replay)`, `allows(action, payload)`, `record_accepted_action(action, payload)`, `refresh_targets()`, and `active`.

- [x] **Step 1: Add a failing component contract**

Append inside `tests/ui_component_contract_test.gd::run()`:

```gdscript
	var tutorial_scene = load("res://scenes/components/single_encounter_tutorial.tscn")
	assert_true(tutorial_scene != null, "tutorial overlay scene should load")
	if tutorial_scene != null:
		var tutorial = tutorial_scene.instantiate()
		assert_true(tutorial.has_method("configure"), "tutorial should accept screen and store")
		assert_true(tutorial.has_method("allows"), "tutorial should guard gameplay actions")
		tutorial.free()
```

- [x] **Step 2: Run and verify the component scene is missing**

Expected: scene load assertion fails.

- [x] **Step 3: Implement the overlay controller**

Create `scripts/ui/tutorial/single_encounter_tutorial.gd`:

```gdscript
class_name SingleEncounterTutorial
extends Control

signal persistence_warning(message: String)

@onready var dimmer: ColorRect = %TutorialDimmer
@onready var focus_rings: Control = %FocusRings
@onready var callout: PanelContainer = %TutorialCallout
@onready var title_label: Label = %TutorialTitle
@onready var instruction_label: Label = %TutorialInstruction
@onready var progress_label: Label = %TutorialProgress
@onready var warning_label: Label = %TutorialWarning
@onready var continue_button: Button = %TutorialContinueButton
@onready var skip_button: Button = %TutorialSkipButton
@onready var finish_button: Button = %TutorialFinishButton

var screen: SingleEncounterScreen
var progress_store: TutorialProgressStore
var flow := SingleEncounterTutorialFlow.new()
var active: bool = false

func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	finish_button.pressed.connect(_on_finish_pressed)

func configure(
	p_screen: SingleEncounterScreen,
	p_progress_store: TutorialProgressStore
) -> void:
	screen = p_screen
	progress_store = p_progress_store
	screen.view_refreshed.connect(refresh_targets)
	screen.ui_action_accepted.connect(record_accepted_action)

func maybe_start() -> void:
	if progress_store != null and not progress_store.is_done():
		start(false)

func start(replay: bool = false) -> void:
	if replay:
		_show_save_error(progress_store.reset())
		screen.reset_teaching_encounter()
	flow.start()
	active = true
	visible = true
	_refresh()

func allows(action: StringName, payload: Dictionary) -> bool:
	if not active:
		return true
	var accepted := flow.allows(action, payload, screen.session)
	if not accepted:
		_refresh()
	return accepted

func record_accepted_action(action: StringName, payload: Dictionary) -> void:
	if not active:
		return
	flow.record_accepted_action(action, payload, screen.session)
	_refresh()

func refresh_targets() -> void:
	if active:
		call_deferred("_rebuild_focus_rings")

func _refresh() -> void:
	title_label.text = _step_title(flow.step_index)
	instruction_label.text = flow.instruction(screen.session)
	progress_label.text = "%d / 11" % (flow.step_index + 1)
	continue_button.visible = flow.step_index in [0, 6]
	finish_button.visible = flow.step_index == 10
	call_deferred("_rebuild_focus_rings")

func _rebuild_focus_rings() -> void:
	if not active or not is_inside_tree():
		return
	for child in focus_rings.get_children():
		child.free()

	var target_rects: Array[Rect2] = []
	for spec in flow.target_specs(screen.session):
		var target := screen.find_tutorial_target(spec)
		if target == null:
			push_error("Tutorial target missing: %s" % spec)
			continue
		var target_rect := target.get_global_rect()
		target_rects.append(target_rect)
		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.position = target_rect.position - global_position - Vector2(5, 5)
		ring.size = target_rect.size + Vector2(10, 10)
		ring.add_theme_stylebox_override("panel", _focus_style())
		focus_rings.add_child(ring)
	_place_callout(target_rects)

func _place_callout(target_rects: Array[Rect2]) -> void:
	var viewport_size := size
	var callout_size := callout.size
	var candidates := [
		Vector2(32, 32),
		Vector2(viewport_size.x - callout_size.x - 32, 32),
		Vector2(32, viewport_size.y - callout_size.y - 32),
		Vector2(
			viewport_size.x - callout_size.x - 32,
			viewport_size.y - callout_size.y - 32
		),
	]
	var best := candidates[0]
	var best_overlap := INF
	for candidate in candidates:
		var candidate_rect := Rect2(candidate + global_position, callout_size)
		var overlap := 0.0
		for target_rect in target_rects:
			var intersection := candidate_rect.intersection(target_rect)
			overlap += intersection.size.x * intersection.size.y
		if overlap < best_overlap:
			best_overlap = overlap
			best = candidate
	callout.position = best

func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.22, 0.25, 0.12)
	style.border_color = Color(0.55, 1.0, 0.94, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	return style

func _step_title(index: int) -> String:
	var titles := [
		"三轨解析", "拖动骰子", "点击分配", "连续三数", "校准骰子",
		"修改规则", "读取预测", "撤销方案", "重新用牌", "确认结算", "教学完成",
	]
	return titles[index]

func _on_continue_pressed() -> void:
	flow.continue_step(screen.session)
	_refresh()

func _on_skip_pressed() -> void:
	_show_save_error(progress_store.mark_done())
	active = false
	visible = false

func _on_finish_pressed() -> void:
	if not flow.can_finish(screen.session):
		return
	_show_save_error(progress_store.mark_done())
	active = false
	visible = false

func _show_save_error(error: Error) -> void:
	warning_label.text = "" if error == OK else "无法保存引导状态；下次启动会再次显示。"
	if error != OK:
		persistence_warning.emit(warning_label.text)
```

- [x] **Step 4: Create the scene-first overlay**

Create `scenes/components/single_encounter_tutorial.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/tutorial/single_encounter_tutorial.gd" id="1"]

[node name="SingleEncounterTutorial" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1")

[node name="TutorialDimmer" type="ColorRect" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
color = Color(0.01, 0.008, 0.04, 0.38)

[node name="FocusRings" type="Control" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="TutorialCallout" type="PanelContainer" parent="."]
unique_name_in_owner = true
custom_minimum_size = Vector2(440, 230)
offset_left = 32.0
offset_top = 32.0
offset_right = 472.0
offset_bottom = 262.0
mouse_filter = 0

[node name="Content" type="VBoxContainer" parent="TutorialCallout"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="TutorialProgress" type="Label" parent="TutorialCallout/Content"]
unique_name_in_owner = true
layout_mode = 2
text = "1 / 11"
theme_override_colors/font_color = Color(0.55, 1, 0.94, 1)

[node name="TutorialTitle" type="Label" parent="TutorialCallout/Content"]
unique_name_in_owner = true
layout_mode = 2
text = "三轨解析"
theme_override_font_sizes/font_size = 26

[node name="TutorialInstruction" type="Label" parent="TutorialCallout/Content"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
text = ""
autowrap_mode = 2

[node name="TutorialWarning" type="Label" parent="TutorialCallout/Content"]
unique_name_in_owner = true
layout_mode = 2
text = ""
autowrap_mode = 2
theme_override_colors/font_color = Color(1, 0.55, 0.66, 1)

[node name="Actions" type="HBoxContainer" parent="TutorialCallout/Content"]
layout_mode = 2
alignment = 2
theme_override_constants/separation = 8

[node name="TutorialSkipButton" type="Button" parent="TutorialCallout/Content/Actions"]
unique_name_in_owner = true
layout_mode = 2
text = "跳过引导"

[node name="TutorialContinueButton" type="Button" parent="TutorialCallout/Content/Actions"]
unique_name_in_owner = true
layout_mode = 2
text = "继续"

[node name="TutorialFinishButton" type="Button" parent="TutorialCallout/Content/Actions"]
unique_name_in_owner = true
layout_mode = 2
text = "完成"
visible = false
```

- [x] **Step 5: Import and run the component contract**

Expected: tutorial scene loads and exposes `configure()` and `allows()`.

- [x] **Step 6: Commit overlay component**

```powershell
git add scripts/ui/tutorial/single_encounter_tutorial.gd scripts/ui/tutorial/single_encounter_tutorial.gd.uid scenes/components/single_encounter_tutorial.tscn tests/ui_component_contract_test.gd tests/ui_component_contract_test.gd.uid
git commit --only scripts/ui/tutorial/single_encounter_tutorial.gd scripts/ui/tutorial/single_encounter_tutorial.gd.uid scenes/components/single_encounter_tutorial.tscn tests/ui_component_contract_test.gd tests/ui_component_contract_test.gd.uid -m "feat: add onboarding overlay"
```

---

### Task 4: Screen Action Protocol and Replay

**Files:**
- Modify: `scripts/ui/single_encounter_screen.gd`
- Modify: `scenes/run/single_encounter_screen.tscn`

**Interfaces:**
- Consumes: the overlay guard and existing `SingleEncounterSession`.
- Produces: `view_refreshed`, `find_tutorial_target(spec)`, `reset_teaching_encounter()`, `start_tutorial_replay()`, and guarded semantic action reporting.

- [x] **Step 1: Add screen-level tutorial configuration and target lookup**

Add to `scripts/ui/single_encounter_screen.gd`:

```gdscript
signal view_refreshed
signal ui_action_accepted(action: StringName, payload: Dictionary)

@export var tutorial_auto_start: bool = true
@export var tutorial_config_path: String = "user://onboarding.cfg"

@onready var tutorial: SingleEncounterTutorial = %SingleEncounterTutorial
```

At the end of `_ready()`:

```gdscript
	tutorial.configure(self, TutorialProgressStore.new(tutorial_config_path))
	tutorial.persistence_warning.connect(_on_tutorial_persistence_warning)
	%ReplayTutorialButton.pressed.connect(start_tutorial_replay)
	if tutorial_auto_start:
		tutorial.call_deferred("maybe_start")
```

At the end of `refresh_from_session()`:

```gdscript
	view_refreshed.emit()
```

Add:

```gdscript
func reset_teaching_encounter() -> void:
	session = SingleEncounterSession.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand()
	)
	refresh_from_session()

func start_tutorial_replay() -> void:
	tutorial.start(true)

func find_tutorial_target(spec: Dictionary) -> Control:
	match spec.get("kind"):
		&"die":
			for node in find_children("*", "Button", true, false):
				if (
					node is DieToken
					and not node.is_queued_for_deletion()
					and node.die_id == spec.get("id")
				):
					return node
		&"card":
			for node in find_children("*", "Button", true, false):
				if (
					node is CardToken
					and not node.is_queued_for_deletion()
					and node.card_index == spec.get("id")
				):
					return node
		&"lane":
			var lane_by_id := {
				&"left": %LeftLane,
				&"middle": %MiddleLane,
				&"right": %RightLane,
			}
			return lane_by_id.get(spec.get("id"))
		&"control":
			return get_node_or_null(NodePath("%" + String(spec.get("id"))))
	return null

func _tutorial_allows(action: StringName, payload: Dictionary) -> bool:
	return tutorial == null or tutorial.allows(action, payload)

func _record_tutorial_action(action: StringName, payload: Dictionary) -> void:
	ui_action_accepted.emit(action, payload)

func _on_tutorial_persistence_warning(message: String) -> void:
	session.last_error = message
	error_label.text = message
```

- [x] **Step 2: Guard and report every gameplay handler**

Replace the action handlers in `single_encounter_screen.gd` with:

```gdscript
func _on_die_activated(die_id: StringName) -> void:
	var action := &"select_die"
	var payload := {"die_id": die_id}
	if session.selection.kind == InteractionState.Kind.CARD:
		action = &"card_die"
		payload["card_index"] = session.selection.card_index
	if not _tutorial_allows(action, payload):
		return
	if session.activate_die(die_id):
		_record_tutorial_action(action, payload)
	refresh_from_session()

func _on_card_activated(card_index: int) -> void:
	var card := session.hand[card_index]
	var action := (
		&"card_global"
		if card.target_type == CardDefinition.TargetType.GLOBAL
		else &"select_card"
	)
	var payload := {"card_index": card_index}
	if not _tutorial_allows(action, payload):
		return
	if session.activate_card(card_index):
		_record_tutorial_action(action, payload)
	refresh_from_session()

func _on_lane_activated(table_id: StringName) -> void:
	var action := &"click_assign"
	var payload: Dictionary
	if session.selection.kind == InteractionState.Kind.DIE:
		payload = {"die_id": session.selection.die_id, "table_id": table_id}
	elif session.selection.kind == InteractionState.Kind.CARD:
		action = &"card_table"
		payload = {"card_index": session.selection.card_index, "table_id": table_id}
	else:
		payload = {"table_id": table_id}
	if not _tutorial_allows(action, payload):
		return
	if session.activate_table(table_id):
		_record_tutorial_action(action, payload)
	refresh_from_session()

func _on_die_drop_requested(die_id: StringName, table_id: StringName) -> void:
	var payload := {"die_id": die_id, "table_id": table_id}
	if not _tutorial_allows(&"drag_assign", payload):
		return
	if session.assign_dropped_die(die_id, table_id):
		_record_tutorial_action(&"drag_assign", payload)
	refresh_from_session()

func _on_die_return_requested(die_id: StringName) -> void:
	var payload := {"die_id": die_id}
	if not _tutorial_allows(&"return_die", payload):
		return
	if session.return_die_to_tray(die_id):
		_record_tutorial_action(&"return_die", payload)
	refresh_from_session()

func _on_gap_activated(left_id: StringName, right_id: StringName) -> void:
	var payload := {
		"card_index": session.selection.card_index,
		"left_id": left_id,
		"right_id": right_id,
	}
	if not _tutorial_allows(&"card_gap", payload):
		return
	if session.activate_gap(left_id, right_id):
		_record_tutorial_action(&"card_gap", payload)
	refresh_from_session()

func _on_calibrate_pressed(delta: int) -> void:
	if session.selection.kind != InteractionState.Kind.DIE:
		session.last_error = "请先选择一颗骰子"
		refresh_from_session()
		return
	var payload := {"die_id": session.selection.die_id, "delta": delta}
	if not _tutorial_allows(&"calibrate", payload):
		return
	if session.calibrate_die(session.selection.die_id, delta):
		_record_tutorial_action(&"calibrate", payload)
	refresh_from_session()

func _on_undo_pressed() -> void:
	if not _tutorial_allows(&"undo", {}):
		return
	if session.undo():
		_record_tutorial_action(&"undo", {})
	refresh_from_session()

func _on_confirm_pressed() -> void:
	if not _tutorial_allows(&"commit", {}):
		return
	var report := session.commit()
	if report.valid and session.controller.committed:
		_record_tutorial_action(&"commit", {})
	refresh_from_session()
```

- [x] **Step 3: Add replay control and overlay instance to the scene**

Add the tutorial scene as a new ext resource in
`scenes/run/single_encounter_screen.tscn`, changing the header to:

```ini
[gd_scene load_steps=7 format=3]
```

Then add:

```ini
[ext_resource type="PackedScene" path="res://scenes/components/single_encounter_tutorial.tscn" id="6"]
```

Add after `DealerHint`:

```ini
[node name="ReplayTutorialButton" type="Button" parent="SafeArea/RootColumn/Body/DealerPanel/DealerCopy"]
unique_name_in_owner = true
layout_mode = 2
text = "重看引导"
tooltip_text = "重置当前教学局并重新开始引导"
```

Add as the final root child so it renders above the game:

```ini
[node name="SingleEncounterTutorial" parent="." instance=ExtResource("6")]
unique_name_in_owner = true
layout_mode = 1
```

- [x] **Step 4: Import and run the synchronous suite**

Expected: screen and component contracts still pass; no script errors.

- [x] **Step 5: Commit screen integration**

```powershell
git add scripts/ui/single_encounter_screen.gd scenes/run/single_encounter_screen.tscn
git commit --only scripts/ui/single_encounter_screen.gd scenes/run/single_encounter_screen.tscn -m "feat: connect onboarding to encounter actions"
```

---

### Task 5: Existing Test Isolation and Tutorial Layout

**Files:**
- Modify: `tests/single_encounter_layout_self_check.gd`
- Modify: `tests/single_encounter_input_self_check.gd`
- Create: `tests/tutorial_layout_self_check.gd`

**Interfaces:**
- Consumes: `tutorial_auto_start=false` for existing checks and the replay API for tutorial layout.
- Produces: proof that the overlay, callout, rings, and replay button fit 1920×1080.

- [x] **Step 1: Disable automatic tutorial in existing scene checks**

In both existing self-checks, set the property before adding the screen:

```gdscript
	var screen = load("res://scenes/run/single_encounter_screen.tscn").instantiate()
	screen.tutorial_auto_start = false
	root.add_child(screen)
```

For `single_encounter_input_self_check.gd`, apply the same assignment to its
member `screen` before `root.add_child(screen)`.

- [x] **Step 2: Create the tutorial layout check**

Create `tests/tutorial_layout_self_check.gd`:

```gdscript
extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var screen: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	screen.tutorial_auto_start = false
	screen.tutorial_config_path = OS.get_temp_dir().path_join(
		"project-joker-tutorial-layout-%d.cfg" % Time.get_ticks_usec()
	)
	root.add_child(screen)
	await process_frame
	await process_frame
	screen.start_tutorial_replay()
	await process_frame
	await process_frame

	var tutorial: Control = screen.get_node("%SingleEncounterTutorial")
	var callout: Control = screen.get_node("%TutorialCallout")
	var replay: Control = screen.get_node("%ReplayTutorialButton")
	_assert_true(tutorial.visible, "replay should show tutorial")
	_assert_inside(screen.get_rect(), callout.get_global_rect(), "tutorial callout")
	_assert_inside(screen.get_rect(), replay.get_global_rect(), "replay button")
	_assert_true(
		screen.get_node("%FocusRings").get_child_count() >= 3,
		"welcome should focus the three lanes and resolution panel"
	)

	var path := screen.tutorial_config_path
	screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	if failures.is_empty():
		print("PASS tutorial_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _assert_inside(parent_rect: Rect2, child_rect: Rect2, label: String) -> void:
	_assert_true(parent_rect.encloses(child_rect), "%s must remain inside root" % label)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
```

- [x] **Step 3: Run layout checks**

```powershell
$baseLayoutLog = Join-Path $env:TEMP 'project-joker-tutorial-base-layout.log'
$tutorialLayoutLog = Join-Path $env:TEMP 'project-joker-tutorial-layout.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $baseLayoutLog -s res://tests/single_encounter_layout_self_check.gd
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $tutorialLayoutLog -s res://tests/tutorial_layout_self_check.gd
```

Expected: both layout checks pass and logs contain no script errors.

- [x] **Step 4: Commit test isolation and layout check**

```powershell
git add tests/single_encounter_layout_self_check.gd tests/single_encounter_input_self_check.gd tests/tutorial_layout_self_check.gd tests/tutorial_layout_self_check.gd.uid
git commit --only tests/single_encounter_layout_self_check.gd tests/single_encounter_input_self_check.gd tests/tutorial_layout_self_check.gd tests/tutorial_layout_self_check.gd.uid -m "test: verify onboarding layout"
```

---

### Task 6: Full Real-Input Tutorial Check

**Files:**
- Create: `tests/tutorial_input_self_check.gd`

**Interfaces:**
- Consumes: actual Window mouse input, temporary persistence, and every tutorial step.
- Produces: end-to-end proof for first-run, blocking, skip, replay, drag, click, calibration, card play, prediction, undo, commit, finish, and persisted completion.

- [x] **Step 1: Create the end-to-end input check**

Create `tests/tutorial_input_self_check.gd`:

```gdscript
extends SceneTree

var failures: Array[String] = []
var screen: SingleEncounterScreen
var pointer_position := Vector2.ZERO

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var config_path := OS.get_temp_dir().path_join(
		"project-joker-tutorial-input-%d.cfg" % Time.get_ticks_usec()
	)
	DirAccess.remove_absolute(config_path)
	screen = load("res://scenes/run/single_encounter_screen.tscn").instantiate()
	screen.tutorial_config_path = config_path
	root.add_child(screen)
	await process_frame
	await process_frame
	await process_frame

	var tutorial: SingleEncounterTutorial = screen.get_node("%SingleEncounterTutorial")
	_assert_true(tutorial.active and tutorial.flow.step_index == 0, "fresh config should auto-start")

	await _click(_find_die(&"d6"))
	_assert_true(
		screen.session.selection.kind == InteractionState.Kind.NONE,
		"welcome should block unrelated gameplay"
	)
	await _click(screen.get_node("%TutorialSkipButton"))
	_assert_true(not tutorial.active, "skip should close onboarding")
	_assert_true(TutorialProgressStore.new(config_path).is_done(), "skip should persist done")

	await _click(screen.get_node("%ReplayTutorialButton"))
	_assert_true(tutorial.active and tutorial.flow.step_index == 0, "replay should restart")
	_assert_true(
		screen.session.controller.state.assignments.is_empty(),
		"replay should reset teaching encounter"
	)
	await _click(screen.get_node("%TutorialContinueButton"))

	await _drag(_find_die(&"d1"), screen.get_node("%LeftLane"))
	_assert_true(tutorial.flow.step_index == 2, "drag lesson should advance")

	await _click(_find_die(&"d6"))
	await _click_lane(screen.get_node("%LeftLane"))
	_assert_true(tutorial.flow.step_index == 3, "click assignment lesson should advance")

	for die_id in [&"d2", &"d3", &"d4"]:
		await _click(_find_die(die_id))
		await _click_lane(screen.get_node("%MiddleLane"))
	_assert_true(tutorial.flow.step_index == 4, "middle lane lesson should advance")

	await _click(_find_die(&"d5"))
	await _click(screen.get_node("%MinusButton"))
	await _click_lane(screen.get_node("%RightLane"))
	_assert_true(tutorial.flow.step_index == 5, "calibration lesson should advance")
	_assert_true(screen.session.preview().total == 44, "base tutorial state should be 44")

	await _click(_find_card(1))
	await _click_lane(screen.get_node("%LeftLane"))
	_assert_true(tutorial.flow.step_index == 6, "card lesson should advance")
	_assert_true(screen.session.preview().total == 51, "card lesson should reach 51")
	await _click(screen.get_node("%TutorialContinueButton"))

	await _click(screen.get_node("%UndoButton"))
	_assert_true(tutorial.flow.step_index == 8, "undo lesson should advance")
	_assert_true(screen.session.preview().total == 44, "undo should restore 44")

	await _click(_find_card(1))
	await _click_lane(screen.get_node("%LeftLane"))
	_assert_true(tutorial.flow.step_index == 9, "reapply lesson should advance")
	await _click(screen.get_node("%ConfirmButton"))
	_assert_true(tutorial.flow.step_index == 10, "commit should reach completion")
	_assert_true(screen.session.commit().total == 51, "tutorial commit should remain 51")

	await _click(screen.get_node("%TutorialFinishButton"))
	_assert_true(not tutorial.active, "finish should close onboarding")
	_assert_true(TutorialProgressStore.new(config_path).is_done(), "finish should persist done")

	screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(config_path)
	if failures.is_empty():
		print("PASS tutorial_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _find_die(id: StringName) -> DieToken:
	for node in screen.find_children("*", "Button", true, false):
		if node is DieToken and not node.is_queued_for_deletion() and node.die_id == id:
			return node
	return null

func _find_card(index: int) -> CardToken:
	for node in screen.find_children("*", "Button", true, false):
		if node is CardToken and not node.is_queued_for_deletion() and node.card_index == index:
			return node
	return null

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
	if control == null:
		return
	await _click_at_point(control.get_global_rect().get_center())

func _click_lane(lane: Control) -> void:
	await _click_at_point(lane.get_global_rect().position + Vector2(18, 18))

func _click_at_point(point: Vector2) -> void:
	await _move_pointer(point)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	root.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	root.push_input(release, true)
	await process_frame

func _drag(source: Control, target: Control) -> void:
	await _drag_to_point(source, target.get_global_rect().get_center())

func _drag_to_point(source: Control, finish: Vector2) -> void:
	_assert_true(source != null, "drag source should exist")
	if source == null:
		return
	var start := source.get_global_rect().get_center()
	await _move_pointer(start)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	root.push_input(press, true)
	await process_frame
	for index in range(1, 7):
		var motion := InputEventMouseMotion.new()
		motion.position = start.lerp(finish, float(index) / 6.0)
		motion.relative = motion.position - pointer_position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		pointer_position = motion.position
		await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = finish
	root.push_input(release, true)
	await process_frame
	await process_frame

func _move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = point - pointer_position
	root.push_input(motion, true)
	pointer_position = point
	await process_frame

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
```

- [x] **Step 2: Import and run the tutorial input check**

```powershell
$task6ImportLog = Join-Path $env:TEMP 'project-joker-tutorial-task6-import.log'
$task6InputLog = Join-Path $env:TEMP 'project-joker-tutorial-input.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $task6ImportLog --import
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $task6InputLog -s res://tests/tutorial_input_self_check.gd
```

Expected: `PASS tutorial_input_self_check`, exit `0`, and no script errors.

- [x] **Step 3: Run the tutorial input check five consecutive times**

```powershell
for ($i = 1; $i -le 5; $i++) {
    $log = Join-Path $env:TEMP ("project-joker-tutorial-input-stability-{0}.log" -f $i)
    & 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $log -s res://tests/tutorial_input_self_check.gd
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|Failed to load script') { exit 1 }
}
```

Expected: five passes.

- [x] **Step 4: Commit the real-input tutorial check**

```powershell
git add tests/tutorial_input_self_check.gd tests/tutorial_input_self_check.gd.uid
git commit --only tests/tutorial_input_self_check.gd tests/tutorial_input_self_check.gd.uid -m "test: verify onboarding input flow"
```

---

### Task 7: Full Acceptance and Documentation State

**Files:**
- Modify: `docs/superpowers/plans/2026-07-24-single-encounter-onboarding.md`

**Interfaces:**
- Consumes: all completed tutorial code and tests.
- Produces: a verified first-run/replay onboarding build with documentation staged only.

- [x] **Step 1: Run complete automated acceptance**

```powershell
$importLog = Join-Path $env:TEMP 'project-joker-tutorial-accept-import.log'
$coreLog = Join-Path $env:TEMP 'project-joker-tutorial-accept-core.log'
$baseLayoutLog = Join-Path $env:TEMP 'project-joker-tutorial-accept-base-layout.log'
$tutorialLayoutLog = Join-Path $env:TEMP 'project-joker-tutorial-accept-layout.log'
$baseInputLog = Join-Path $env:TEMP 'project-joker-tutorial-accept-base-input.log'
$tutorialInputLog = Join-Path $env:TEMP 'project-joker-tutorial-accept-input.log'
$mainLog = Join-Path $env:TEMP 'project-joker-tutorial-accept-main.log'

& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $importLog --import
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $coreLog -s res://tests/run_all.gd
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $baseLayoutLog -s res://tests/single_encounter_layout_self_check.gd
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $tutorialLayoutLog -s res://tests/tutorial_layout_self_check.gd
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $baseInputLog -s res://tests/single_encounter_input_self_check.gd
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $tutorialInputLog -s res://tests/tutorial_input_self_check.gd
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $mainLog --quit-after 2
```

Expected:

- every command exits `0`;
- all synchronous suites pass;
- both layout checks pass;
- both input checks pass;
- main scene launches and exits cleanly;
- no log contains `SCRIPT ERROR` or `Failed to load script`.

- [x] **Step 2: Run visible smoke verification**

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64.exe' --path .
```

Verify:

- a fresh config shows the welcome callout;
- callout and focus rings are readable without hiding the relevant target;
- unrelated gameplay actions are blocked;
- skip closes the overlay;
- `重看引导` states that it resets the teaching encounter;
- replay resets and starts at step 0;
- no English player-facing reasons or gambling vocabulary appears.

- [x] **Step 3: Mark this plan complete and stage all documentation**

Change every completed `- [x]` in this document to `- [x]`, then run:

```powershell
git add docs/superpowers/plans/2026-07-24-core-rules-foundation.md docs/superpowers/plans/2026-07-24-three-lane-single-encounter-ui.md docs/superpowers/specs/2026-07-24-single-encounter-onboarding-design.md docs/superpowers/plans/2026-07-24-single-encounter-onboarding.md
git status --short
```

Expected: exactly four documentation files remain staged and uncommitted; no code file is unstaged.

## Exit Checklist

- [x] Missing onboarding config starts the tutorial.
- [x] Completion and skip persist `done=true`.
- [x] Replay persists `done=false`, resets the encounter, and starts at step 0.
- [x] Welcome blocks unrelated gameplay without mutating selection or history.
- [x] Drag lesson requires an accepted `drag_assign`.
- [x] Click lesson requires an accepted `click_assign`.
- [x] Middle, calibration, card, prediction, undo, replay-card, and commit lessons advance in order.
- [x] Prediction totals visibly follow 44→51→44→51.
- [x] Commit remains 51 and reaches completion.
- [x] Tutorial code never calculates score or mutates `RoundState`.
- [x] Focus rings resolve semantic IDs after dynamic token refreshes.
- [x] Callout and replay button remain inside 1920×1080.
- [x] Existing non-tutorial checks pass with auto-start disabled.
- [x] Tutorial real-input check passes five consecutive runs.
- [x] Godot logs contain no script load or compile errors.
- [x] Four documentation files remain staged and uncommitted.
