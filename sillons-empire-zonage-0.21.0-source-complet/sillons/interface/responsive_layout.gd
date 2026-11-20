class_name ResponsiveLayout
extends RefCounted
## 0.18 — Paysage et portrait. Le sens de l'écran choisit la base de mise à l'échelle (1280 × 600 en paysage,
## 600 × 1280 en portrait) : textes et boutons gardent la même taille physique dans les deux sens.
## Chaque élément d'interface garde sa mise en page « paysage » (mémorisée) et reçoit une mise en page « portrait »
## décrite par une table ; la bascule se fait à chaque rotation, sans fermer les panneaux.

const LANDSCAPE_BASE := Vector2i(1280, 600)
const PORTRAIT_BASE := Vector2i(600, 1280)
const PORTRAIT_RATIO: float = 1.1
## En portrait, l'échelle d'interface choisie est plafonnée à 115 % : à 130 %, l'écran ne ferait que 460 points de large
## et les barres ne tiendraient plus sans se recouvrir.
const PORTRAIT_SCALE_MAX: float = 1.15

static func is_portrait_size(size: Vector2) -> bool:
	return size.y > size.x * PORTRAIT_RATIO

static func is_portrait(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return false
	var root: Window = node.get_tree().root
	return is_portrait_size(Vector2(root.size))

static func watch(root: Window) -> void:
	## Branche une seule fois la bascule d'échelle sur la fenêtre principale (elle survit aux changements de scène).
	if root == null or root.has_meta("responsive_watch"):
		update_scale(root)
		return
	root.set_meta("responsive_watch", true)
	root.size_changed.connect(update_scale.bind(root))
	update_scale(root)

static func update_scale(root: Window) -> void:
	if root == null:
		return
	var portrait: bool = is_portrait_size(Vector2(root.size))
	var wanted: Vector2i = PORTRAIT_BASE if portrait else LANDSCAPE_BASE
	if root.content_scale_size != wanted:
		root.content_scale_size = wanted
	var factor: float = minf(GameConfig.ui_scale, PORTRAIT_SCALE_MAX) if portrait else GameConfig.ui_scale
	if not is_equal_approx(root.content_scale_factor, factor):
		root.content_scale_factor = factor

static func remember(control: Control) -> void:
	if control == null or control.has_meta("landscape_layout"):
		return
	var base: Vector4 = control.get_meta("base_offsets", Vector4(control.offset_left, control.offset_top, control.offset_right, control.offset_bottom)) as Vector4
	control.set_meta("landscape_layout", {"anchors": Vector4(control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom),
		"offsets": base, "grow": Vector2i(control.grow_horizontal, control.grow_vertical)})

static func apply(control: Control, spec: Dictionary) -> void:
	## spec vide : retour à la mise en page paysage mémorisée. Sinon {"anchors": Vector4, "offsets": Vector4, "grow": Vector2i}.
	if control == null:
		return
	remember(control)
	var layout: Dictionary = control.get_meta("landscape_layout") as Dictionary
	var anchors: Vector4 = spec.get("anchors", layout["anchors"]) as Vector4 if not spec.is_empty() else layout["anchors"] as Vector4
	var offsets: Vector4 = spec.get("offsets", layout["offsets"]) as Vector4 if not spec.is_empty() else layout["offsets"] as Vector4
	var grow: Vector2i = spec.get("grow", layout["grow"]) as Vector2i if not spec.is_empty() else layout["grow"] as Vector2i
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.grow_horizontal = grow.x
	control.grow_vertical = grow.y
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w
	if control.has_meta("base_offsets"):
		control.set_meta("base_offsets", offsets)
	control.remove_meta("layout_base")

static func spec(anchors: Vector4, offsets: Vector4, grow: Vector2i = Vector2i(Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)) -> Dictionary:
	return {"anchors": anchors, "offsets": offsets, "grow": grow}

static func fit_full_panel(control: Control, portrait: bool) -> void:
	## Panneaux plein écran (Civilisation, Ville, Conseil…) : marges larges en paysage, étroites en portrait.
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	if portrait:
		control.offset_left = 8
		control.offset_right = -8
		control.offset_top = 8
		control.offset_bottom = -8
	else:
		control.offset_left = 70
		control.offset_right = -70
		control.offset_top = 80
		control.offset_bottom = -30

static func outside(control: Control, viewport_size: Vector2) -> bool:
	## Recette : vrai si un élément visible déborde de l'écran.
	var r: Rect2 = control.get_global_rect()
	return r.position.x < -1.0 or r.position.y < -1.0 or r.end.x > viewport_size.x + 1.0 or r.end.y > viewport_size.y + 1.0
