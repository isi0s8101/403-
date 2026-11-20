class_name MobileUI
extends RefCounted
## Charte commune : contraste lisible, cibles tactiles, focus clavier, aucun flou plein écran.
## 0.17 : les couleurs viennent des jetons de l'âge (AgeTheme) ; ces constantes restent pour compatibilité.
const INK := AgeTheme.NEUTRAL_INK
const MUTED := AgeTheme.NEUTRAL_MUTED
const ACCENT := AgeTheme.NEUTRAL_ACCENT
const ZONE_COLORS := AgeTheme.ZONES

static func panel(color: Color = Color.TRANSPARENT, radius: int = -1) -> StyleBoxFlat:
	## Panneau simple aux couleurs de l'âge courant (couleur explicite possible).
	var k: Dictionary = AgeTheme.tokens()
	var s := StyleBoxFlat.new()
	s.bg_color = k["bg"] if color.a <= 0.0 else color
	s.border_color = k["border"]
	s.set_border_width_all(1)
	s.set_corner_radius_all(int(k["radius"]) if radius < 0 else radius)
	s.set_content_margin_all(12)
	return s

static func theme() -> Theme:
	## Thème unique partagé par toute l'interface ; son contenu suit l'âge (AgeTheme.apply).
	return AgeTheme.shared()

static func ink() -> Color:
	return AgeTheme.c("text")

static func muted() -> Color:
	return AgeTheme.c("muted")

static func accent() -> Color:
	return AgeTheme.c("accent")

static func button(caption: String, callback: Callable, height: float = 48.0) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size.y = height
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(callback)
	return b

static func primary(button_node: Button) -> void:
	button_node.theme_type_variation = "PrimaryButton"

static func safe_insets(viewport: Viewport) -> Vector4:
	## Convertit les pixels physiques (encoche/barre Android) en coordonnées de l'interface.
	if not OS.has_feature("android"):
		return Vector4(12, 12, 12, 12)
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0 or screen.y <= 0:
		return Vector4(12, 12, 12, 12)
	var scale_ui: Vector2 = viewport.get_visible_rect().size / Vector2(screen)
	return Vector4(maxf(12, float(safe.position.x) * scale_ui.x), maxf(12, float(safe.position.y) * scale_ui.y),
		maxf(12, float(screen.x - safe.end.x) * scale_ui.x), maxf(12, float(screen.y - safe.end.y) * scale_ui.y))
