class_name UIFeedback
extends Node
## 0.17 — Retours sensoriels de l'interface, dans le style de l'âge : son d'interface, léger enfoncement
## des boutons (échelle), vibration courte (Android), info-bulle par appui long sur un bouton.
## Tout est coupé ou réduit par les réglages (sons, vibrations, « Réduire les animations »).

const TIP_DELAY := 0.55
var player: AudioStreamPlayer
var tip: PanelContainer
var tip_label: Label
var plays: int = 0
var _held: Button = null
var _held_since: float = -1.0
var _locked: Button = null

func setup(root: Control) -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -10.0
	add_child(player)
	tip = PanelContainer.new()
	tip.visible = false
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.custom_minimum_size = Vector2(220, 0)
	tip_label = Label.new()
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.custom_minimum_size = Vector2(260, 0)
	tip_label.add_theme_font_size_override("font_size", 14)
	tip.add_child(tip_label)
	root.add_child(tip)

func _exit_tree() -> void:
	# Aucun son d'interface ne doit retenir de ressource à la fermeture de la scène.
	if player != null:
		player.stop()
		player.stream = null

func play(kind: String) -> void:
	if not GameConfig.ui_sounds or player == null:
		return
	var stream: AudioStream = AgeTheme.sound(kind)
	if stream == null:
		return
	plays += 1
	# Sans sortie audio (pilote factice : recettes sans écran), aucun son n'est audible : ne rien jouer
	# évite qu'un son lancé juste avant la fermeture retienne une ressource à la sortie.
	if AudioServer.get_driver_name() == "Dummy":
		return
	player.stream = stream
	player.play()

func decorate(button: BaseButton) -> void:
	if button.has_meta("decorated"):
		return
	button.set_meta("decorated", true)
	button.button_down.connect(_on_down.bind(button))
	button.button_up.connect(_on_up.bind(button))

func _on_down(button: BaseButton) -> void:
	if button is Button:
		_held = button
		_held_since = float(Time.get_ticks_msec()) / 1000.0
	AgeTheme.haptic(8)
	if GameConfig.reduce_motion:
		return
	button.pivot_offset = button.size * 0.5
	var tween: Tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05 * float(AgeTheme.tokens()["motion"]))

func _on_up(button: BaseButton) -> void:
	_held = null
	_held_since = -1.0
	tip.visible = false
	if not button.disabled:
		play("tap")
	if GameConfig.reduce_motion:
		button.scale = Vector2.ONE
		return
	var tween: Tween = button.create_tween()
	var spring: bool = AgeTheme.current_age >= 8
	tween.tween_property(button, "scale", Vector2.ONE, 0.16 * float(AgeTheme.tokens()["motion"])).set_trans(Tween.TRANS_BACK if spring else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _process(_delta: float) -> void:
	if _locked != null and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Le relâchement qui suit une info-bulle ne déclenche pas le bouton.
		var restore: Button = _locked
		_locked = null
		restore.set_deferred("disabled", false)
	if _held == null or _held_since < 0.0 or _held.tooltip_text == "" or _held.has_meta("no_tip"):
		return
	if float(Time.get_ticks_msec()) / 1000.0 - _held_since < TIP_DELAY:
		return
	show_tip(_held, _held.tooltip_text)
	_held_since = -1.0
	if not _held.disabled:
		_locked = _held
		_held.disabled = true
		_held.scale = Vector2.ONE

func release_lock() -> void:
	if _locked != null:
		_locked.disabled = false
		_locked = null

func show_tip(anchor: Control, text: String) -> void:
	tip_label.text = text
	tip.visible = true
	tip.reset_size()
	var root_size: Vector2 = tip.get_parent_control().size if tip.get_parent_control() != null else Vector2(1280, 600)
	var r: Rect2 = anchor.get_global_rect()
	var pos: Vector2 = Vector2(r.position.x, r.position.y - tip.size.y - 8.0)
	if pos.y < 8.0:
		pos.y = r.end.y + 8.0
	tip.position = Vector2(clampf(pos.x, 8.0, maxf(8.0, root_size.x - tip.size.x - 8.0)), clampf(pos.y, 8.0, maxf(8.0, root_size.y - tip.size.y - 8.0)))
	AgeTheme.haptic(14)

static func pulse(control: CanvasItem, strength: float = 0.35) -> void:
	## Pulsation brève (alerte, badge) qui se calme ; simple éclat si les animations sont réduites.
	if control == null or GameConfig.reduce_motion:
		return
	var tween: Tween = control.create_tween()
	var hot: Color = Color(1.0 + strength, 1.0 + strength, 1.0 + strength, 1.0)
	tween.tween_property(control, "modulate", hot, 0.12)
	tween.tween_property(control, "modulate", Color.WHITE, 0.45 * float(AgeTheme.tokens()["motion"]))
