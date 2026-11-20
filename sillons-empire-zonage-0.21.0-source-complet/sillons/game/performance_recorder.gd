class_name AndroidPerfRecorder
extends RefCounted
## Diagnostic local : intervalles muraux des images et temps bruts des ticks.
var frames_ms: PackedFloat64Array = PackedFloat64Array()
var ticks_ms: PackedFloat64Array = PackedFloat64Array()
var seconds: Array[Dictionary] = []
var metadata: Dictionary = {}
var interruptions: int = 0
var elapsed: float = 0.0
var _second_elapsed: float = 0.0
var _second_frames: int = 0
var _recording: bool = false

func begin(context: Dictionary) -> void:
	metadata = context.duplicate(true)
	metadata.merge({"version": ProjectSettings.get_setting("application/config/version"),
		"godot": Engine.get_version_info()["string"], "os": OS.get_name(), "os_version": OS.get_version(),
		"device": OS.get_model_name(), "cpu": OS.get_processor_name(), "cores": OS.get_processor_count(),
		"renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(),
		"headless": DisplayServer.get_name() == "headless", "display_driver": DisplayServer.get_name(),
		"window": str(DisplayServer.window_get_size()), "utc": Time.get_datetime_string_from_system(true),
		"target_fps": Engine.max_fps, "tick_rate": Rules.TICK_RATE,
		"thermal_status": null, "thermal_reason": "Relevé externe Android requis : dumpsys thermalservice.",
		"memory_note": "RSS du processus si lisible ; PSS via ADB. Mémoire Godot et vidéo distinctes.",
		"frame_note": "Intervalles muraux des images ; préparation du rendu exclue, bascules incluses."}, true)
	frames_ms.clear(); ticks_ms.clear(); seconds.clear()
	interruptions = 0; elapsed = 0.0; _second_elapsed = 0.0; _second_frames = 0
	_recording = true

func record_tick(milliseconds: float) -> void:
	if _recording and is_finite(milliseconds) and milliseconds >= 0.0:
		ticks_ms.append(milliseconds)

func record_frame(delta: float, viewport: Viewport, context: Dictionary) -> void:
	if not _recording or not is_finite(delta) or delta <= 0.0:
		return
	frames_ms.append(delta * 1000.0)
	elapsed += delta; _second_elapsed += delta; _second_frames += 1
	if _second_elapsed < 1.0:
		return
	var rid: RID = viewport.get_viewport_rid()
	var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var sample: Dictionary = {"elapsed_s": elapsed, "fps": float(_second_frames) / _second_elapsed,
		"rss_mib": process_rss_mib(), "godot_static_mib": float(OS.get_static_memory_usage()) / 1048576.0,
		"video_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(rid),
		"render_gpu_ms": gpu_ms if gpu_ms > 0.0 else null}
	sample.merge(context, true); seconds.append(sample)
	_second_elapsed = 0.0; _second_frames = 0

static func process_rss_mib() -> Variant:
	if OS.get_name() not in ["Linux", "Android"]:
		return null
	var handle: FileAccess = FileAccess.open("/proc/self/status", FileAccess.READ)
	if handle == null:
		return null
	while not handle.eof_reached():
		var line: String = handle.get_line()
		if line.begins_with("VmRSS:"):
			var fields: PackedStringArray = line.replace("\t", " ").split(" ", false)
			if fields.size() >= 2 and fields[1].is_valid_int():
				return float(fields[1]) / 1024.0
	return null

static func distribution(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty():
		return {"count": 0, "p50_ms": null, "p95_ms": null, "p99_ms": null, "max_ms": null}
	var ordered: PackedFloat64Array = values.duplicate()
	ordered.sort()
	var result: Dictionary = {"count": ordered.size(), "max_ms": ordered[-1]}
	for entry in [["p50_ms", 0.50], ["p95_ms", 0.95], ["p99_ms", 0.99]]:
		result[String(entry[0])] = ordered[clampi(ceili(float(ordered.size()) * float(entry[1])) - 1, 0, ordered.size() - 1)]
	return result

func finish() -> Dictionary:
	_recording = false
	var slow: int = 0
	for value in frames_ms:
		if value > 1000.0 / 30.0: slow += 1
	var rss_peak: Variant = null
	for sample in seconds:
		if sample["rss_mib"] != null:
			rss_peak = maxf(float(rss_peak) if rss_peak != null else 0.0, float(sample["rss_mib"]))
	return {"schema": 1, "metadata": metadata, "elapsed_s": elapsed, "interruptions": interruptions,
		"fps_mean": float(frames_ms.size()) / elapsed if elapsed > 0 else 0.0,
		"frame": distribution(frames_ms), "tick": distribution(ticks_ms),
		"frames_above_33_33_ms": slow, "rss_peak_mib": rss_peak,
		"sim_ticks_per_s": float(ticks_ms.size()) / elapsed if elapsed > 0 else 0.0, "seconds": seconds}

static func save_report(report: Dictionary, path: String) -> Error:
	if not path.begins_with("user://mesures/") or ".." in path:
		return ERR_INVALID_PARAMETER
	var error: Error = DirAccess.make_dir_recursive_absolute("user://mesures")
	if error != OK: return error
	var temporary: String = path + ".tmp"
	var handle: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if handle == null: return FileAccess.get_open_error()
	handle.store_string(JSON.stringify(report, "  "))
	var write_error: Error = handle.get_error()
	handle.close()
	if write_error != OK: return write_error
	return DirAccess.rename_absolute(temporary, path)
