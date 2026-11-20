class_name UIMotion
extends RefCounted
static func is_open(control: Control) -> bool:
	return control.visible and not bool(control.get_meta("closing", false))
static func toggle(control: Control) -> void:
	if is_open(control): conceal(control)
	else: reveal(control)
static func reveal(control: Control) -> void:
	control.set_meta("closing", false)
	if control.has_meta("motion"):
		var old: Tween = control.get_meta("motion") as Tween
		if old != null and old.is_valid(): old.kill()
	control.show()
	if GameConfig.reduce_motion: control.modulate.a = 1; control.scale = Vector2.ONE; return
	control.modulate.a = 0.0
	# 0.17 : le panneau glisse depuis son bord (échelle partant du bord le plus proche), rythme de l'âge.
	var parent_size: Vector2 = control.get_parent_area_size()
	var center: Vector2 = control.position + control.size * 0.5
	var pivot: Vector2 = Vector2(0.0 if center.x < parent_size.x * 0.5 else control.size.x, control.size.y if center.y > parent_size.y * 0.5 else 0.0)
	control.pivot_offset = pivot
	control.scale = Vector2(0.96, 0.96)
	var pace: float = float(AgeTheme.tokens()["motion"])
	var tween: Tween = control.create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.18 * pace).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "scale", Vector2.ONE, 0.2 * pace).set_trans(Tween.TRANS_BACK if AgeTheme.current_age >= 8 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	control.set_meta("motion", tween)
static func conceal(control: Control) -> void:
	control.set_meta("closing", true)
	if control.has_meta("motion"):
		var old: Tween = control.get_meta("motion") as Tween
		if old != null and old.is_valid(): old.kill()
	if GameConfig.reduce_motion: control.hide(); return
	var tween: Tween = control.create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.13)
	tween.tween_callback(control.hide)
	control.set_meta("motion", tween)
static func clear(parent: Node) -> void:
	for child in parent.get_children(): parent.remove_child(child); child.queue_free()
