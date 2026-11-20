class_name TouchTile
extends Control
## 0.17 — Tuile tactile commune (barre de sélection, groupes, héros, pouvoirs, alertes).
## Toucher = `tapped`, deuxième toucher rapide = `double_tapped`, appui maintenu 0,5 s = `long_pressed`.
## Un glissé (le doigt sort de la tuile) annule le geste : aucune action involontaire.
## Dessin : boîte du thème de l'âge (Button/normal ou pressed), icône, texte, jauge et anneau de recharge.

signal tapped
signal double_tapped
signal long_pressed

const LONG := 0.5
const DOUBLE := 0.32
var icon: Texture2D
var caption: String = ""
var badge: String = ""
var detail: String = ""
var gauge: float = -1.0            # 0..1 : jauge de santé ou de progression (-1 = aucune)
var ring: float = -1.0             # 0..1 : anneau de recharge (-1 = aucun)
var highlighted: bool = false
var dimmed: bool = false
var shape: String = ""             # repère de forme doublant la couleur (accessibilité)
var _down_at: float = -1.0
var _long_done: bool = false
var _last_tap: float = -10.0
var _press_pos: Vector2 = Vector2.ZERO

func _init() -> void:
	custom_minimum_size = Vector2(56, 56)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _gui_input(event: InputEvent) -> void:
	var pressed: bool = false
	var released: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		pos = event.position
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _down_at >= 0.0 and event.position.distance_to(_press_pos) > 28.0:
			_down_at = -1.0
			queue_redraw()
		return
	else:
		return
	accept_event()
	if pressed:
		_down_at = _now()
		_long_done = false
		_press_pos = pos
		queue_redraw()
	elif released and _down_at >= 0.0:
		_down_at = -1.0
		queue_redraw()
		if _long_done:
			return
		var t: float = _now()
		if t - _last_tap <= DOUBLE:
			_last_tap = -10.0
			double_tapped.emit()
		else:
			_last_tap = t
			tapped.emit()

func _process(_delta: float) -> void:
	if _down_at >= 0.0 and not _long_done and _now() - _down_at >= LONG:
		_long_done = true
		_last_tap = -10.0
		long_pressed.emit()
		AgeTheme.haptic(18)
		queue_redraw()

func refresh_look() -> void:
	queue_redraw()

func _draw() -> void:
	var box: StyleBox = get_theme_stylebox("pressed" if (_down_at >= 0.0 or highlighted) else "normal", "Button")
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var text_color: Color = AgeTheme.c("disabled") if dimmed else AgeTheme.c("text")
	var font: Font = get_theme_default_font()
	var inner: Rect2 = Rect2(Vector2(6, 5), size - Vector2(12, 12))
	if icon != null:
		var side: float = minf(inner.size.x, inner.size.y - (12.0 if caption != "" else 0.0))
		var rect := Rect2(inner.position + Vector2((inner.size.x - side) * 0.5, 0.0), Vector2(side, side))
		draw_texture_rect(icon, rect, false, Color(1, 1, 1, 0.45 if dimmed else 1.0))
	if caption != "":
		var font_size: int = 13 if icon != null else 15
		var y: float = size.y - 9.0 if icon != null else size.y * 0.5 + 5.0
		draw_string(font, Vector2(4, y), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8.0, font_size, text_color)
	if detail != "":
		draw_string(font, Vector2(4, 15), detail, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8.0, 13, AgeTheme.c("muted"))
	if badge != "":
		var bw: float = maxf(20.0, font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 8.0)
		var br := Rect2(Vector2(size.x - bw - 2.0, 2.0), Vector2(bw, 18.0))
		draw_rect(br, AgeTheme.c("accent"))
		draw_string(font, br.position + Vector2(0, 14), badge, HORIZONTAL_ALIGNMENT_CENTER, bw, 13, AgeTheme.c("accent_text"))
	if gauge >= 0.0:
		var gr := Rect2(Vector2(6, size.y - 6.0), Vector2(size.x - 12.0, 3.0))
		draw_rect(gr, AgeTheme.c("track"))
		var col: Color = AgeTheme.c("success") if gauge > 0.6 else (AgeTheme.c("warning") if gauge > 0.3 else AgeTheme.c("danger"))
		draw_rect(Rect2(gr.position, Vector2(gr.size.x * clampf(gauge, 0.0, 1.0), gr.size.y)), col)
	if ring >= 0.0 and ring < 1.0:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 4.0
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - ring), 32, AgeTheme.c("scrim"), 4.0)
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * ring, 32, AgeTheme.c("accent"), 3.0)
	if shape != "":
		draw_string(font, Vector2(4, 16), shape, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_color)
