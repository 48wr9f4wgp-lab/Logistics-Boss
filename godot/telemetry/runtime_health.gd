extends Node
class_name LogisticsRuntimeHealth

const LOW_FPS_THRESHOLD := 30.0
const SAMPLE_INTERVAL := 1.0

var _sample_timer := 0.0
var _samples := 0
var _fps_total := 0.0
var _min_fps := 9999.0
var _low_fps_samples := 0


func _process(delta: float) -> void:
    _sample_timer += maxf(0.0, delta)
    if _sample_timer < SAMPLE_INTERVAL:
        return
    _sample_timer = 0.0
    record_sample(float(Engine.get_frames_per_second()))


func record_sample(fps: float) -> void:
    var safe_fps := maxf(0.0, fps)
    _samples += 1
    _fps_total += safe_fps
    _min_fps = minf(_min_fps, safe_fps)
    if safe_fps < LOW_FPS_THRESHOLD:
        _low_fps_samples += 1


func snapshot() -> Dictionary:
    if _samples <= 0:
        return {
            "samples": 0,
            "average_fps": 0.0,
            "minimum_fps": 0.0,
            "low_fps_seconds": 0.0,
            "low_fps_ratio": 0.0,
        }
    return {
        "samples": _samples,
        "average_fps": snappedf(_fps_total / float(_samples), 0.1),
        "minimum_fps": snappedf(_min_fps, 0.1),
        "low_fps_seconds": float(_low_fps_samples) * SAMPLE_INTERVAL,
        "low_fps_ratio": snappedf(float(_low_fps_samples) / float(_samples), 0.001),
    }


func reset() -> void:
    _sample_timer = 0.0
    _samples = 0
    _fps_total = 0.0
    _min_fps = 9999.0
    _low_fps_samples = 0
