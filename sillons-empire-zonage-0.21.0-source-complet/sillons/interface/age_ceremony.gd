class_name AgeCeremony
extends PanelContainer
## 0.17 — Cérémonie de passage d'âge : 1 à 2 s, le cadre passe de l'ancien style au nouveau
## (éclat puis matière de l'âge suivant), nom du nouvel âge et du monument, son propre à l'âge.
## Jamais bloquante : le jeu continue dessous ; un toucher sur le bandeau la termine aussitôt.
## « Réduire les animations » : simple fondu, thème appliqué immédiatement.

var feedback: UIFeedback
var title: Label
var detail: Label
var active: bool = false
var target_age: int = 0
var _tween: Tween
var _applied: bool = false

func setup(p_feedback: UIFeedback) -> void:
	feedback = p_feedback
	visible = false
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -280
	offset_right = 280
	offset_top = 150
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	title = Label.new()
	title.theme_type_variation = "HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	detail = Label.new()
	detail.theme_type_variation = "MutedLabel"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 14)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(detail)

func play(new_age: int, text: String) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	target_age = clampi(new_age, 1, 10)
	active = true
	_applied = false
	title.text = "Âge %s — %s" % [Hud.ROMAN[target_age], AgeTheme.age_name(target_age)]
	detail.text = (text if text != "" else "Votre civilisation entre dans un nouvel âge.") + "\nToucher pour passer"
	visible = true
	pivot_offset = Vector2(280, 40)
	if GameConfig.reduce_motion:
		_apply_new()
		modulate = Color(1, 1, 1, 0)
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, 0.2)
		_tween.tween_interval(1.0)
		_tween.tween_property(self, "modulate:a", 0.0, 0.3)
		_tween.tween_callback(_finish)
		return
	scale = Vector2(0.92, 0.92)
	modulate = Color(1, 1, 1, 0)
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate", Color(1.6, 1.6, 1.6, 1.0), 0.16)
	_tween.tween_callback(_apply_new)
	_tween.tween_property(self, "modulate", Color.WHITE, 0.32)
	_tween.tween_interval(0.85)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(_finish)

func _apply_new() -> void:
	if _applied:
		return
	_applied = true
	AgeTheme.apply(target_age)
	if feedback != null:
		feedback.play("age")
	AgeTheme.haptic(40)

func skip() -> void:
	if not active:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_apply_new()
	_finish()

func _finish() -> void:
	active = false
	visible = false
	modulate = Color.WHITE
	scale = Vector2.ONE

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		accept_event()
		skip()
