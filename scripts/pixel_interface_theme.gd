extends RefCounted
## The diner dialogue's square frame and pixel typography, with scene palettes.
const FONT_PATH := "res://assets/level3/dialogue/dialogue-mono-bold.ttf"
const GARDEN := {
    "background": Color("191c13"), "inset": Color("10150f"),
    "accent": Color("d3b66d"), "text": Color("f2ead0"),
    "muted": Color("b1b99b"), "rule": Color("66724b"),
}
const RACE := {
    "background": Color("091b1e"), "inset": Color("061215"),
    "accent": Color("64dbcf"), "text": Color("dcfff8"),
    "muted": Color("9fc8c4"), "rule": Color("285f61"),
}
static var _font: FontFile

static func font() -> FontFile:
    if _font == null:
        _font = (load(FONT_PATH) as FontFile).duplicate() as FontFile
        _font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
        _font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
    return _font

static func frame(background: Color, border: Color, width := 2, shadow := 0) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(0)
    style.shadow_color = Color(0, 0, 0, .72)
    style.shadow_size = shadow
    return style

static func label(control: Control, colour: Color) -> void:
    control.add_theme_font_override("font", font())
    control.add_theme_color_override("font_color", colour)
    control.add_theme_color_override("font_outline_color", Color("071014"))
    control.add_theme_constant_override("outline_size", 1)

static func button(control: Button, palette: Dictionary) -> void:
    label(control, palette.text)
    control.add_theme_color_override("font_hover_color", Color.WHITE)
    control.add_theme_color_override("font_pressed_color", palette.inset)
    control.add_theme_color_override("font_disabled_color", palette.muted.darkened(.35))
    control.add_theme_stylebox_override("normal", frame(palette.background, palette.accent))
    control.add_theme_stylebox_override("hover", frame(palette.background.lightened(.12), palette.text))
    control.add_theme_stylebox_override("pressed", frame(palette.accent, palette.text))
    control.add_theme_stylebox_override("disabled", frame(palette.inset, palette.rule))
    control.add_theme_stylebox_override("focus", frame(Color.TRANSPARENT, palette.text))
