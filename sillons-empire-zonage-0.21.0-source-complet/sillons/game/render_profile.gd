class_name RenderProfile
extends RefCounted
## Gouverneur de rendu uniquement : aucun changement du pas de simulation, du brouillard ou des ordres.
const RESOLUTION := [0.72, 0.88, 1.0]
const SHADOW_DISTANCE := [0.0, 48.0, 64.0]

static func apply(viewport: Viewport, sun: DirectionalLight3D, quality: int, stage: int, shadows: bool) -> Dictionary:
	var q: int = clampi(quality, 0, 2)
	var pressure: int = clampi(stage, 0, 2)
	var resolution: float = maxf(0.60, float(RESOLUTION[q]) - float(pressure) * 0.08)
	viewport.scaling_3d_scale = resolution
	viewport.msaa_3d = Viewport.MSAA_DISABLED if q == 0 or pressure >= 2 else Viewport.MSAA_2X
	if sun != null:
		sun.shadow_enabled = shadows and q > 0 and pressure < 2
		sun.directional_shadow_max_distance = maxf(24.0, float(SHADOW_DISTANCE[q]) - float(pressure) * 10.0)
	return {"quality": q, "pressure": pressure, "scale": resolution, "shadows": sun != null and sun.shadow_enabled}
