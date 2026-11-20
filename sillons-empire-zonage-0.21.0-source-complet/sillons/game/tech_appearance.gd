class_name TechAppearance
extends RefCounted
## Variation de niveau par quelques éléments géométriques ; zéro texture, animation ou collision.

static func decorate(root: Node3D, tier: int, anchor: Vector3, width: float) -> void:
	if int(root.get_meta("evolution_style", 0)) == tier:
		return
	var prev: Node3D = root.get_node_or_null("EvolutionStyle") as Node3D
	if prev != null:
		root.remove_child(prev)
		prev.queue_free()
	root.set_meta("evolution_style", tier)
	if tier <= 1:
		return
	var detail := Node3D.new()
	detail.name = "EvolutionStyle"
	root.add_child(detail)
	var metal: Material = Assets.mat("evolution_steel_2", Color(0.21, 0.51, 0.56), 0.37, 0.62)
	if tier >= 3:
		metal = Assets.mat("evolution_gold_3", Color(0.76, 0.59, 0.24), 0.37, 0.71)
	Assets.box(detail, Vector3(width, 0.09, 0.17), metal, anchor)
	if tier >= 3:
		Assets.box(detail, Vector3(width * 0.55, 0.13, 0.18), metal, anchor + Vector3(0, 0.18, 0))
