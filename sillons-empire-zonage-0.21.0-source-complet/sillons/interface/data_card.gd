class_name DataCard
extends Button
var picture: TextureRect
var caption: Label
var description: Label
var reason: Label
var key: String = ""
func setup(title: String, image: Texture2D, detail: String, callback: Callable) -> void:
	custom_minimum_size = Vector2(184, 154)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10; box.offset_top = 9; box.offset_right = -10; box.offset_bottom = -9
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	picture = TextureRect.new()
	picture.texture = image
	picture.custom_minimum_size.y = 72
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(picture)
	caption = Label.new(); caption.text = title; caption.add_theme_font_size_override("font_size", 15)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(caption)
	description = Label.new(); description.text = detail
	description.add_theme_font_size_override("font_size", 13); description.theme_type_variation = "MutedLabel"
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(description)
	reason = Label.new(); reason.add_theme_font_size_override("font_size", 13)
	reason.add_theme_color_override("font_color", AgeTheme.c("warning"))
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(reason)
	if callback.is_valid(): pressed.connect(callback)
func availability(refusal: String) -> void:
	disabled = not refusal.is_empty()
	tooltip_text = refusal
	reason.text = refusal
	picture.modulate = Color(0.6, 0.6, 0.6) if disabled else Color.WHITE
