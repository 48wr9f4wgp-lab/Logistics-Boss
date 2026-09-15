extends "res://view/warehouse_view.gd"
class_name MobileWarehouseView

const MOBILE_MOUSE_ORBIT_SENSITIVITY := Vector2(0.0042, 0.0032)
const MOBILE_TOUCH_ORBIT_SENSITIVITY := Vector2(0.0041, 0.0033)
const MOBILE_PINCH_ZOOM_SENSITIVITY := 0.014
const MOBILE_CAMERA_POSITION_SMOOTHING := 16.0
const MOBILE_CAMERA_FOV_SMOOTHING := 10.0
const MOBILE_INPUT_DEADZONE := 1.2
const MOBILE_MAX_DRAG_STEP := 26.0
const MOBILE_MAX_PINCH_STEP := 36.0
const MOBILE_DRAG_FILTER_WEIGHT := 0.78
const MOBILE_PINCH_FILTER_WEIGHT := 0.75
const MOBILE_MIN_DISTANCE := 14.0
const MOBILE_MAX_DISTANCE := 32.0
const MOBILE_DEFAULT_DISTANCE := 21.5
const MOBILE_NEAR_FOV := 52.0
const MOBILE_FAR_FOV := 46.0

var _filtered_touch_drag := Vector2.ZERO
var _filtered_pinch_delta := 0.0


func _ready() -> void:
    super._ready()
    _camera_distance = clampf(maxf(_camera_distance, MOBILE_DEFAULT_DISTANCE), MOBILE_MIN_DISTANCE, MOBILE_MAX_DISTANCE)
    if _camera != null:
        # Portrait gameplay needs a stable horizontal field of view. KEEP_WIDTH prevents
        # tall phone aspect ratios from collapsing the warehouse into a narrow tunnel.
        _camera.keep_aspect = Camera3D.KEEP_WIDTH
        _camera.fov = _desired_mobile_fov()
        _camera_pose_initialized = false


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            _camera_distance = maxf(MOBILE_MIN_DISTANCE, _camera_distance - 0.8)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            _camera_distance = minf(MOBILE_MAX_DISTANCE, _camera_distance + 0.8)

    if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
        var mouse_drag: Vector2 = event.relative.limit_length(MOBILE_MAX_DRAG_STEP)
        if mouse_drag.length() >= MOBILE_INPUT_DEADZONE:
            _orbit_yaw -= mouse_drag.x * MOBILE_MOUSE_ORBIT_SENSITIVITY.x
            _orbit_pitch = clampf(
                _orbit_pitch - mouse_drag.y * MOBILE_MOUSE_ORBIT_SENSITIVITY.y,
                -0.98,
                -0.48
            )

    if event is InputEventScreenTouch:
        if event.pressed:
            _touches[event.index] = event.position
            if _touches.size() >= 2:
                _last_pinch_distance = 0.0
                _filtered_pinch_delta = 0.0
        else:
            _touches.erase(event.index)
            _last_pinch_distance = 0.0
            _filtered_pinch_delta = 0.0
            if _touches.is_empty():
                _filtered_touch_drag = Vector2.ZERO

    if event is InputEventScreenDrag:
        _touches[event.index] = event.position
        if _touches.size() == 1:
            var touch_drag: Vector2 = event.relative.limit_length(MOBILE_MAX_DRAG_STEP)
            if touch_drag.length() >= MOBILE_INPUT_DEADZONE:
                _filtered_touch_drag = _filtered_touch_drag.lerp(touch_drag, MOBILE_DRAG_FILTER_WEIGHT)
                _orbit_yaw -= _filtered_touch_drag.x * MOBILE_TOUCH_ORBIT_SENSITIVITY.x
                _orbit_pitch = clampf(
                    _orbit_pitch - _filtered_touch_drag.y * MOBILE_TOUCH_ORBIT_SENSITIVITY.y,
                    -0.98,
                    -0.48
                )
        elif _touches.size() >= 2:
            var ids := _touches.keys()
            var a: Vector2 = _touches[ids[0]]
            var b: Vector2 = _touches[ids[1]]
            var distance := a.distance_to(b)
            if _last_pinch_distance > 0.0:
                var pinch_delta := clampf(
                    distance - _last_pinch_distance,
                    -MOBILE_MAX_PINCH_STEP,
                    MOBILE_MAX_PINCH_STEP
                )
                _filtered_pinch_delta = lerpf(_filtered_pinch_delta, pinch_delta, MOBILE_PINCH_FILTER_WEIGHT)
                _camera_distance = clampf(
                    _camera_distance - _filtered_pinch_delta * MOBILE_PINCH_ZOOM_SENSITIVITY,
                    MOBILE_MIN_DISTANCE,
                    MOBILE_MAX_DISTANCE
                )
            _last_pinch_distance = distance


func _desired_mobile_fov() -> float:
    var zoom_t := clampf(
        (_camera_distance - MOBILE_MIN_DISTANCE) / (MOBILE_MAX_DISTANCE - MOBILE_MIN_DISTANCE),
        0.0,
        1.0
    )
    return lerpf(MOBILE_NEAR_FOV, MOBILE_FAR_FOV, zoom_t)


func _update_camera(delta: float) -> void:
    if _camera == null:
        return

    var zoom_t := clampf(
        (_camera_distance - MOBILE_MIN_DISTANCE) / (MOBILE_MAX_DISTANCE - MOBILE_MIN_DISTANCE),
        0.0,
        1.0
    )
    var near_target := Vector3(0.0, 1.20, 0.10)
    var far_target := Vector3(0.0, 0.72, 0.05)
    var target := near_target.lerp(far_target, zoom_t)
    var desired_fov := _desired_mobile_fov()

    var horizontal := cos(_orbit_pitch) * _camera_distance
    var height := -sin(_orbit_pitch) * _camera_distance
    var desired_position := target + Vector3(
        sin(_orbit_yaw) * horizontal,
        height,
        cos(_orbit_yaw) * horizontal
    )

    if not _camera_pose_initialized:
        _camera.global_position = desired_position
        _camera.fov = desired_fov
        _camera_pose_initialized = true
    else:
        var smoothing_weight := 1.0 - exp(-MOBILE_CAMERA_POSITION_SMOOTHING * maxf(delta, 0.0))
        _camera.global_position = _camera.global_position.lerp(
            desired_position,
            clampf(smoothing_weight, 0.0, 1.0)
        )
        var fov_weight := 1.0 - exp(-MOBILE_CAMERA_FOV_SMOOTHING * maxf(delta, 0.0))
        _camera.fov = lerpf(_camera.fov, desired_fov, clampf(fov_weight, 0.0, 1.0))

    _camera.look_at(target, Vector3.UP)
