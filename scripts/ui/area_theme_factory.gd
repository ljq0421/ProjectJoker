class_name AreaThemeFactory
extends RefCounted

static func build(base_theme: Theme, presentation: Dictionary) -> Theme:
	var themed := base_theme.duplicate(true) as Theme
	var primary: Color = presentation["primary"]
	var secondary: Color = presentation["secondary"]
	var surface: Color = presentation["surface"]
	var surface_raised: Color = presentation["surface_raised"]

	themed.set_stylebox(
		"normal",
		"Button",
		_button_style(surface_raised, Color(primary, 0.86), 1)
	)
	themed.set_stylebox(
		"hover",
		"Button",
		_button_style(surface_raised.lightened(0.1), secondary, 2)
	)
	themed.set_stylebox(
		"pressed",
		"Button",
		_button_style(primary.darkened(0.62), primary.lightened(0.18), 2)
	)
	themed.set_stylebox(
		"disabled",
		"Button",
		_button_style(surface.darkened(0.08), Color(primary, 0.24), 1)
	)
	themed.set_stylebox("focus", "Button", _focus_style(secondary))
	themed.set_stylebox(
		"panel",
		"PanelContainer",
		_panel_style(surface, Color(secondary, 0.54))
	)
	themed.set_color("font_color", "Button", primary.lightened(0.22))
	themed.set_color("font_hover_color", "Button", Color.WHITE)
	themed.set_color("font_pressed_color", "Button", Color.WHITE)
	themed.set_color(
		"font_disabled_color",
		"Button",
		Color(primary.lightened(0.08), 0.42)
	)
	return themed

static func _button_style(
	background: Color,
	border: Color,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 14.0
	style.content_margin_top = 9.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 9.0
	return style

static func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_top = 14.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 14.0
	return style

static func _focus_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	return style
