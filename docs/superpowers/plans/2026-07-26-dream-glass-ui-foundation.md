# Dream Glass UI Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build eight precise dream-glass SVG UI assets, integrate the six active panel/button assets into the global Godot Theme, and verify import, behavior, layout, and rendered appearance without touching unrelated worktree changes.

**Architecture:** The SVG files are stable source assets with transparent backgrounds and nine-patch-safe borders. `resources/themes/neon_dream_theme.tres` owns the only runtime integration by mapping six `StyleBoxTexture` resources to the existing `PanelContainer` and `Button` theme slots; scene structures and UI scripts remain unchanged. Two companion SVGs are delivered for future selection and divider use but are intentionally not mapped in this batch.

**Tech Stack:** Godot 4.6.1, SVG 1.1-compatible vector textures, Godot `Theme` and `StyleBoxTexture`, PowerShell static checks, existing GDScript test runner.

## Global Constraints

- Target viewport is exactly 1920×1080 and the window presentation must remain usable at 1280×720.
- New assets live only under `resources/ui/dream_glass/`.
- Runtime integration modifies only `resources/themes/neon_dream_theme.tres`.
- Do not edit or stage existing changes in `project.godot`, UI scripts, tests, or unrelated design documents.
- Preserve panel content margins at left/right 16 px and top/bottom 14 px.
- Preserve button content margins at left/right 14 px and top/bottom 9 px.
- Keep `RouteChoicePanel` and every other scene-local `theme_override_styles` surface unchanged.
- Do not embed text, fonts, raster images, external links, or language-specific content in SVG files.
- Do not use ImageGen for structural UI frames.
- Do not commit. The design and implementation-plan documents are staged separately according to the project convention; implementation files remain available for review.
- Source specification: `docs/superpowers/specs/2026-07-26-dream-glass-ui-foundation-design.md`.
- Godot reference: `StyleBoxTexture` uses `texture_margin_*` for the nine-patch borders and overlays a `focus` StyleBox on the current button state.

---

## File Structure

### Create

- `resources/ui/dream_glass/panel_glass_9patch.svg` — global panel surface.
- `resources/ui/dream_glass/button_glass_normal_9patch.svg` — default button surface.
- `resources/ui/dream_glass/button_glass_hover_9patch.svg` — pointer-hover surface.
- `resources/ui/dream_glass/button_glass_pressed_9patch.svg` — held/pressed surface.
- `resources/ui/dream_glass/button_glass_disabled_9patch.svg` — disabled surface.
- `resources/ui/dream_glass/button_focus_9patch.svg` — transparent keyboard-focus overlay.
- `resources/ui/dream_glass/selection_glow_9patch.svg` — future target/selection frame.
- `resources/ui/dream_glass/divider_glow_horizontal.svg` — future horizontal divider.

### Modify

- `resources/themes/neon_dream_theme.tres` — replace five `StyleBoxFlat` button resources and one panel resource with texture-backed equivalents.

### Temporary verification only

- `tmp/dream_glass_theme_self_check.gd` — exact Theme mapping and margin check; remove after verification.
- `tmp/dream_glass_visual_qa.gd` — render all theme states and the current main screen to PNG; remove after screenshots are reviewed.
- `tmp/dream_glass_visual_qa.png` — state board screenshot; remove after review.
- `tmp/dream_glass_main_1920x1080.png` — actual main-screen screenshot; remove after review.
- `tmp/dream_glass_main_1280x720.png` — reduced-size main-screen screenshot; remove after review.

---

### Task 1: Create the eight SVG source assets

**Files:**
- Create: `resources/ui/dream_glass/panel_glass_9patch.svg`
- Create: `resources/ui/dream_glass/button_glass_normal_9patch.svg`
- Create: `resources/ui/dream_glass/button_glass_hover_9patch.svg`
- Create: `resources/ui/dream_glass/button_glass_pressed_9patch.svg`
- Create: `resources/ui/dream_glass/button_glass_disabled_9patch.svg`
- Create: `resources/ui/dream_glass/button_focus_9patch.svg`
- Create: `resources/ui/dream_glass/selection_glow_9patch.svg`
- Create: `resources/ui/dream_glass/divider_glow_horizontal.svg`

**Interfaces:**
- Consumes: Exact colors, canvas sizes, safe margins, and state semantics in the global constraints and the table below.
- Produces: Eight loadable SVG textures at stable `res://resources/ui/dream_glass/*.svg` paths.

**Asset geometry:**

| Asset | Canvas | Primary shape | Safe margins |
|---|---:|---|---:|
| Panel | 256×256 | `x=4 y=4 width=248 height=248 rx=12` | 24 px all sides |
| Button states | 256×80 | `x=4 y=4 width=248 height=72 rx=12` | 18 px left/right, 16 px top/bottom |
| Focus | 256×80 | Transparent center; same button outline | 18 px left/right, 16 px top/bottom |
| Selection | 256×128 | Transparent center; four protected corner brackets | 20 px all sides |
| Divider | 256×8 | Centered 2 px horizontal gradient rule | 20 px left/right |

**State palette:**

| Asset | Fill | Outer stroke | Inner highlight |
|---|---|---|---|
| Panel | `#0E0B26` at 94% with violet-to-cyan diagonal gradient | `#59E6DB` at 72%, 2 px | `#D27BE5` at 22%, 1 px along top/left |
| Normal | `#321C5E` at 94% | `#D27BE5` at 90%, 2 px | white at 10%, top edge only |
| Hover | `#452873` at 98% | `#59E6DB` at 95%, 2 px | `#8CFFF2` at 22%, top edge only |
| Pressed | `#1F5966` at 100% | `#8CFFF2` at 100%, 2 px | black at 14%, top inset |
| Disabled | `#1C152E` at 72% | `#5E4F7A` at 65%, 2 px | none |
| Focus | transparent | `#FFADE8` at 95%, 2 px | `#59E6DB` at 20%, second inset line |

- [ ] **Step 1: Run the precondition check and verify the asset set is absent**

Run:

```powershell
$dir = 'resources/ui/dream_glass'
$names = @(
  'panel_glass_9patch.svg',
  'button_glass_normal_9patch.svg',
  'button_glass_hover_9patch.svg',
  'button_glass_pressed_9patch.svg',
  'button_glass_disabled_9patch.svg',
  'button_focus_9patch.svg',
  'selection_glow_9patch.svg',
  'divider_glow_horizontal.svg'
)
$missing = $names | Where-Object { -not (Test-Path (Join-Path $dir $_)) }
if ($missing.Count -eq 0) { throw 'Expected the new asset set to be absent before implementation.' }
$missing
```

Expected: all eight filenames are printed.

- [ ] **Step 2: Create the SVG files with precise shared structure**

Use `apply_patch` for every SVG. Each file must start with this root shape, using the exact canvas from the asset table:

```xml
<svg xmlns="http://www.w3.org/2000/svg"
     width="256" height="80" viewBox="0 0 256 80"
     fill="none">
  <defs>
    <linearGradient id="fill" x1="18" y1="4" x2="238" y2="76"
                    gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#452873"/>
      <stop offset="0.55" stop-color="#321C5E"/>
      <stop offset="1" stop-color="#102D3C"/>
    </linearGradient>
  </defs>
  <rect x="4" y="4" width="248" height="72" rx="12"
        fill="url(#fill)" fill-opacity="0.98"
        stroke="#59E6DB" stroke-opacity="0.95" stroke-width="2"/>
</svg>
```

Apply the asset table’s exact fill, stroke, canvas, and shape to each file. Keep all state differences inside `<defs>` colors and edge paths; never move the primary rectangle between button states. The panel’s signature element is one violet top-left trace paired with one faint cyan bottom-right trace. Buttons use only one top-edge highlight. Selection uses corner brackets contained entirely inside the 20 px protected borders. Divider uses a left-to-right transparent/cyan/transparent gradient and contains no center emblem that could stretch.

- [ ] **Step 3: Parse every SVG as XML**

Run:

```powershell
$files = Get-ChildItem -LiteralPath 'resources/ui/dream_glass' -Filter '*.svg'
if ($files.Count -ne 8) { throw "Expected 8 SVGs, found $($files.Count)." }
foreach ($file in $files) {
  try { [xml](Get-Content -Raw -LiteralPath $file.FullName) | Out-Null }
  catch { throw "Invalid SVG XML: $($file.Name): $($_.Exception.Message)" }
}
'PASS: 8 SVG files parse as XML.'
```

Expected: `PASS: 8 SVG files parse as XML.`

- [ ] **Step 4: Enforce structural SVG constraints**

Run:

```powershell
$files = Get-ChildItem -LiteralPath 'resources/ui/dream_glass' -Filter '*.svg'
$forbidden = '<text|<image|href=|url\(https?://|font-family'
foreach ($file in $files) {
  $content = Get-Content -Raw -LiteralPath $file.FullName
  if ($content -match $forbidden) { throw "Forbidden embedded content in $($file.Name)." }
  if ($content -notmatch 'viewBox="0 0 256 (80|128|256|8)"') {
    throw "Unexpected viewBox in $($file.Name)."
  }
}
'PASS: SVG files are self-contained and use approved canvases.'
```

Expected: `PASS: SVG files are self-contained and use approved canvases.`

- [ ] **Step 5: Import the SVG files through Godot**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --quit
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

Expected: exit code `0`, with no SVG parser or missing-resource errors.

- [ ] **Step 6: Review the scoped asset diff**

Run:

```powershell
git status --short -- resources/ui/dream_glass
git diff --check -- resources/ui/dream_glass
```

Expected: exactly eight new SVG source files plus Godot-generated `.import` metadata ignored by `.gitignore`; no whitespace errors.

---

### Task 2: Replace global flat styles with texture-backed styles

**Files:**
- Modify: `resources/themes/neon_dream_theme.tres:1-111`
- Create temporarily: `tmp/dream_glass_theme_self_check.gd`

**Interfaces:**
- Consumes: The six active SVG paths created by Task 1.
- Produces: `Theme.get_stylebox()` returns `StyleBoxTexture` for `PanelContainer/panel` and all five `Button` style slots.

- [ ] **Step 1: Create the temporary Theme contract check**

Create `tmp/dream_glass_theme_self_check.gd` with:

```gdscript
extends SceneTree

const THEME_PATH := "res://resources/themes/neon_dream_theme.tres"
const EXPECTED := {
	"PanelContainer/panel": [
		"res://resources/ui/dream_glass/panel_glass_9patch.svg",
		Vector4(24.0, 24.0, 24.0, 24.0),
		Vector4(16.0, 14.0, 16.0, 14.0),
	],
	"Button/normal": [
		"res://resources/ui/dream_glass/button_glass_normal_9patch.svg",
		Vector4(18.0, 16.0, 18.0, 16.0),
		Vector4(14.0, 9.0, 14.0, 9.0),
	],
	"Button/hover": [
		"res://resources/ui/dream_glass/button_glass_hover_9patch.svg",
		Vector4(18.0, 16.0, 18.0, 16.0),
		Vector4(14.0, 9.0, 14.0, 9.0),
	],
	"Button/pressed": [
		"res://resources/ui/dream_glass/button_glass_pressed_9patch.svg",
		Vector4(18.0, 16.0, 18.0, 16.0),
		Vector4(14.0, 9.0, 14.0, 9.0),
	],
	"Button/disabled": [
		"res://resources/ui/dream_glass/button_glass_disabled_9patch.svg",
		Vector4(18.0, 16.0, 18.0, 16.0),
		Vector4(14.0, 9.0, 14.0, 9.0),
	],
	"Button/focus": [
		"res://resources/ui/dream_glass/button_focus_9patch.svg",
		Vector4(18.0, 16.0, 18.0, 16.0),
		Vector4(0.0, 0.0, 0.0, 0.0),
	],
}

func _initialize() -> void:
	var theme := load(THEME_PATH) as Theme
	if theme == null:
		push_error("Cannot load %s" % THEME_PATH)
		quit(1)
		return
	var failures: Array[String] = []
	for key: String in EXPECTED:
		var parts := key.split("/")
		var theme_type := StringName(parts[0])
		var style_name := StringName(parts[1])
		var style := theme.get_stylebox(style_name, theme_type)
		if not style is StyleBoxTexture:
			failures.append("%s is not StyleBoxTexture" % key)
			continue
		var textured := style as StyleBoxTexture
		var expected: Array = EXPECTED[key]
		if textured.texture == null or textured.texture.resource_path != expected[0]:
			failures.append("%s texture mismatch" % key)
		var texture_margins: Vector4 = expected[1]
		var content_margins: Vector4 = expected[2]
		var sides := [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]
		for index in sides.size():
			if textured.get_texture_margin(sides[index]) != texture_margins[index]:
				failures.append("%s texture margin %d mismatch" % [key, sides[index]])
			if textured.get_content_margin(sides[index]) != content_margins[index]:
				failures.append("%s content margin %d mismatch" % [key, sides[index]])
	if failures.is_empty():
		print("PASS: dream-glass Theme contract")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
```

- [ ] **Step 2: Run the check and verify it fails against the old flat Theme**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tmp/dream_glass_theme_self_check.gd
```

Expected: nonzero exit code with `PanelContainer/panel is not StyleBoxTexture` and button style failures.

- [ ] **Step 3: Rewrite the Theme resources**

Replace the flat style subresources with six `StyleBoxTexture` resources. Use this exact shape for the panel:

```text
[ext_resource type="Texture2D" path="res://resources/ui/dream_glass/panel_glass_9patch.svg" id="1_panel"]

[sub_resource type="StyleBoxTexture" id="Panel"]
content_margin_left = 16.0
content_margin_top = 14.0
content_margin_right = 16.0
content_margin_bottom = 14.0
texture = ExtResource("1_panel")
texture_margin_left = 24.0
texture_margin_top = 24.0
texture_margin_right = 24.0
texture_margin_bottom = 24.0
```

Use this exact shape for each normal, hover, pressed, and disabled button, changing only the external texture ID:

```text
[sub_resource type="StyleBoxTexture" id="ButtonNormal"]
content_margin_left = 14.0
content_margin_top = 9.0
content_margin_right = 14.0
content_margin_bottom = 9.0
texture = ExtResource("2_button_normal")
texture_margin_left = 18.0
texture_margin_top = 16.0
texture_margin_right = 18.0
texture_margin_bottom = 16.0
```

Use a transparent-center overlay for focus:

```text
[sub_resource type="StyleBoxTexture" id="ButtonFocus"]
content_margin_left = 0.0
content_margin_top = 0.0
content_margin_right = 0.0
content_margin_bottom = 0.0
expand_margin_left = 2.0
expand_margin_top = 2.0
expand_margin_right = 2.0
expand_margin_bottom = 2.0
texture = ExtResource("6_button_focus")
texture_margin_left = 18.0
texture_margin_top = 16.0
texture_margin_right = 18.0
texture_margin_bottom = 16.0
draw_center = false
```

Keep all existing font colors and final Theme mappings unchanged:

```text
Button/styles/normal = SubResource("ButtonNormal")
Button/styles/hover = SubResource("ButtonHover")
Button/styles/pressed = SubResource("ButtonPressed")
Button/styles/disabled = SubResource("ButtonDisabled")
Button/styles/focus = SubResource("ButtonFocus")
PanelContainer/styles/panel = SubResource("Panel")
```

- [ ] **Step 4: Reimport and run the Theme contract check**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --quit
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tmp/dream_glass_theme_self_check.gd
exit $LASTEXITCODE
```

Expected: `PASS: dream-glass Theme contract` and exit code `0`.

- [ ] **Step 5: Confirm the Theme diff does not include layout or copy changes**

Run:

```powershell
git diff --check -- resources/themes/neon_dream_theme.tres
git diff -- resources/themes/neon_dream_theme.tres
```

Expected: only external texture declarations and flat-to-texture StyleBox definitions change; Theme font colors, font sizes, style slot names, and content margins remain stable.

---

### Task 3: Run regression and visual acceptance

**Files:**
- Create temporarily: `tmp/dream_glass_visual_qa.gd`
- Create temporarily: `tmp/dream_glass_visual_qa.png`
- Create temporarily: `tmp/dream_glass_main_1920x1080.png`
- Create temporarily: `tmp/dream_glass_main_1280x720.png`
- Read only: existing scenes, scripts, and tests.

**Interfaces:**
- Consumes: The integrated `neon_dream_theme.tres` from Task 2.
- Produces: Passing automated checks and reviewed screenshots proving the global styles render correctly in isolation and on the real main screen.

- [ ] **Step 1: Run the existing full test suite**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file "$env:TEMP\project-joker-headless.log" -s res://tests/run_all.gd
exit $LASTEXITCODE
```

Expected: `ALL TESTS PASSED` and exit code `0`.

- [ ] **Step 2: Run the focused layout and real-input checks**

Run each existing self-check separately:

```powershell
$checks = @(
  'res://tests/single_encounter_layout_self_check.gd',
  'res://tests/single_encounter_input_self_check.gd'
)
foreach ($check in $checks) {
  & 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s $check
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: both scripts exit `0` without layout-bound or input-path failures.

- [ ] **Step 3: Create a temporary visual QA renderer**

Create `tmp/dream_glass_visual_qa.gd` that:

1. loads `res://resources/themes/neon_dream_theme.tres`;
2. creates a 1920×1080 `Control` with the project background color `Color("#09061c")`;
3. adds one `PanelContainer` containing long Chinese rule copy;
4. adds normal, hover, pressed, disabled, and focused button samples in a single row;
5. creates one 1920×1080 and one 1280×720 `SubViewport`, with
   `render_target_update_mode = SubViewport.UPDATE_ALWAYS`;
6. instantiates a fresh `res://scenes/run/single_encounter_screen.tscn` under each viewport;
7. waits three `process_frame` signals after each layout;
8. saves the state board and both viewport textures to the three exact PNG paths;
9. asserts the saved main-screen images are exactly 1920×1080 and 1280×720;
10. exits with code `1` if any `save_png()` result is not `OK`.

Use this exact capture helper:

```gdscript
func capture(viewport: Viewport, path: String, expected_size: Vector2i) -> bool:
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Empty capture for %s" % path)
		return false
	if image.get_size() != expected_size:
		push_error("Capture size mismatch for %s: %s" % [path, image.get_size()])
		return false
	var result := image.save_png(path)
	if result != OK:
		push_error("save_png failed for %s: %s" % [path, error_string(result)])
		return false
	return true
```

The focused sample must call `grab_focus()`. The disabled sample must set `disabled = true`.
The hover and pressed samples may be labeled `悬停` and `按下` on the state board, but their
actual style overrides must use `theme.get_stylebox("hover", "Button")` and
`theme.get_stylebox("pressed", "Button")` so the captured pixels show the real Theme resources.

- [ ] **Step 4: Run the visual renderer with the non-headless Godot executable**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64.exe' --path . --resolution 1920x1080 -s res://tmp/dream_glass_visual_qa.gd
exit $LASTEXITCODE
```

Expected: exit code `0` and both PNG files exist.

- [ ] **Step 5: Inspect both rendered PNGs**

Open with the workspace image viewer:

```text
tmp/dream_glass_visual_qa.png
tmp/dream_glass_main_1920x1080.png
tmp/dream_glass_main_1280x720.png
```

Acceptance checklist:

- panel corners remain circular and equal on all four sides;
- horizontal and vertical borders retain the same perceived 2 px weight;
- no center stretch creates a bright seam;
- long Chinese copy remains legible over the panel center;
- normal, hover, pressed, disabled, and focus states are distinguishable without relying only on brightness;
- focus overlay does not cover the active state border;
- narrow and wide buttons retain identical corner geometry;
- the main encounter layout has no changed bounds, clipping, or text wrapping at either target size;
- adjacent panels do not create excessive double glow.

If any check fails, adjust only the affected SVG geometry or opacity, reimport, and repeat Tasks 2 Step 4 and 3 Steps 1–5.

- [ ] **Step 6: Remove temporary QA scripts and images**

Resolve and verify each target remains inside the repository’s `tmp` directory, then remove only:

```text
tmp/dream_glass_theme_self_check.gd
tmp/dream_glass_visual_qa.gd
tmp/dream_glass_visual_qa.png
tmp/dream_glass_main_1920x1080.png
tmp/dream_glass_main_1280x720.png
```

Do not remove the `tmp` directory or any other existing temporary file.

- [ ] **Step 7: Review the final scoped worktree**

Run:

```powershell
git diff --check -- resources/ui/dream_glass resources/themes/neon_dream_theme.tres
git status --short
git diff --stat -- resources/ui/dream_glass resources/themes/neon_dream_theme.tres
```

Expected implementation scope:

```text
resources/ui/dream_glass/*.svg
resources/themes/neon_dream_theme.tres
```

The previously staged specifications and plans remain staged. Existing unrelated modifications keep their original status and contents.
