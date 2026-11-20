class_name MobilePerfBudget
extends RefCounted
## J12 : governor visuel local, sans modifier le tick logique ni les ordres.
## LOD légèrement abaissé après surcharge soutenue ; remontée lente pour éviter le pompage.
var stage: int = 0
var galaxy_refresh_ticks: int = 15
var terrain_lod_bias: float = 0.0
var _window_s: float = 0.0
var _slow_frames: int = 0
var _frames: int = 0
var _recovery_windows: int = 0

func observe(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_window_s += minf(delta, 0.25)
	_frames += 1
	if delta > 0.0225:
		_slow_frames += 1
	if _window_s < 2.0:
		return
	var slow_ratio: float = float(_slow_frames) / float(maxi(1, _frames))
	if slow_ratio > 0.28:
		stage = mini(2, stage + 1)
		_recovery_windows = 0
	elif slow_ratio < 0.06:
		_recovery_windows += 1
		if _recovery_windows >= 3:
			stage = maxi(0, stage - 1)
			_recovery_windows = 0
	else:
		_recovery_windows = 0
	galaxy_refresh_ticks = 15 if stage == 0 else (30 if stage == 1 else 45)
	terrain_lod_bias = float(stage) * 7.0
	_window_s = 0.0
	_slow_frames = 0
	_frames = 0
