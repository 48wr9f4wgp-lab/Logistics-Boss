extends Node
class_name MobileUiGestureRouter

# The composed mobile scene has one raw gesture owner. Standalone legacy HUD
# tests keep their original routers; bind() disables them only in this scene.
signal action_activated(button: Button)

const DRAG_THRESHOLD := 6.0
const MOUSE_SUPPRESSION_MS := 450

var hud: MobileGameHud
var zone: WarehouseZonePanel
var _button: Button
var _pointer := -1
var _movement := 0.0
var _dragging := false
var _scrolling := false
var _identity := ""
var _normal_style: StyleBox
var _suppress_until := 0
var _blocked_touches: Dictionary = {}


func bind(next_hud: MobileGameHud, next_zone: WarehouseZonePanel) -> void:
    hud = next_hud
    zone = next_zone
    hud.set_process_input(false)
    if zone != null:
        zone.set_process_input(false)


func _input(event: InputEvent) -> void:
    if hud == null:
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if _blocked_touches.has(touch.index):
            if not touch.pressed:
                _blocked_touches.erase(touch.index)
            get_viewport().set_input_as_handled()
            return
        if touch.pressed:
            if _pointer != -1:
                _dragging = true
                _restore_visual()
                _blocked_touches[touch.index] = true
                get_viewport().set_input_as_handled()
            else:
                _begin(touch.position, touch.index)
        elif _pointer == touch.index:
            _finish(touch.position, touch.canceled)
        return
    if event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if _blocked_touches.has(drag.index):
            get_viewport().set_input_as_handled()
        elif drag.index == _pointer:
            _move(drag.relative)
        return
    if event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index != MOUSE_BUTTON_LEFT:
            return
        if Time.get_ticks_msec() < _suppress_until:
            get_viewport().set_input_as_handled()
            return
        if mouse.pressed and _pointer == -1:
            _begin(mouse.position, -2)
        elif not mouse.pressed and _pointer == -2:
            _finish(mouse.position, false)
        return
    if event is InputEventMouseMotion and _pointer == -2:
        _move((event as InputEventMouseMotion).relative)


func _begin(position: Vector2, pointer: int) -> void:
    var target := button_at(position)
    var in_scroll := (
        hud._sheet.visible and hud._mobile_scroll != null
        and _contains_visible(hud._mobile_scroll, position)
    )
    if target == null and not in_scroll:
        return
    _button = target
    _pointer = pointer
    _movement = 0.0
    _dragging = false
    _scrolling = in_scroll
    _identity = _button_identity(target)
    _normal_style = target.get_theme_stylebox("normal") if target != null else null
    if pointer >= 0:
        _suppress_until = Time.get_ticks_msec() + MOUSE_SUPPRESSION_MS
    apply_pressed_visual()
    get_viewport().set_input_as_handled()


func _move(relative: Vector2) -> void:
    _movement += relative.length()
    if _movement >= DRAG_THRESHOLD:
        _dragging = true
        _restore_visual()
    if _dragging and _scrolling and hud._sheet.visible:
        hud._scroll_management_by(relative.y)
    get_viewport().set_input_as_handled()


func _finish(position: Vector2, cancelled: bool) -> void:
    var target := _button
    var activate := (
        not cancelled and not _dragging and is_instance_valid(target)
        and button_at(position) == target
        and _identity == _button_identity(target)
    )
    if _pointer >= 0:
        _suppress_until = Time.get_ticks_msec() + MOUSE_SUPPRESSION_MS
    _restore_visual()
    _button = null
    _pointer = -1
    _scrolling = false
    _normal_style = null
    get_viewport().set_input_as_handled()
    if activate:
        # Existing signal handlers remain the only path to authoritative actions.
        target.pressed.emit()
        action_activated.emit(target)


func apply_pressed_visual() -> void:
    if is_instance_valid(_button) and not _dragging:
        _button.add_theme_stylebox_override("normal", _button.get_theme_stylebox("pressed"))


func is_pressing(button: Button) -> bool:
    return _button == button and _pointer != -1 and not _dragging


func _restore_visual() -> void:
    if is_instance_valid(_button) and _normal_style != null:
        _button.add_theme_stylebox_override("normal", _normal_style)


func button_at(position: Vector2) -> Button:
    if hud == null:
        return null
    if hud._reset_modal != null and hud._reset_modal.visible:
        return _find_button(hud._reset_modal, position)
    if hud._sheet.visible:
        if _contains_visible(hud._sheet, position):
            return _find_button(hud._sheet, position)
        return _dock_button_at(position)
    if zone != null and zone.is_open() and _contains_visible(zone._panel, position):
        return _find_button(zone._panel, position)
    return _find_button(hud, position)


func _dock_button_at(position: Vector2) -> Button:
    for candidate in [hud._manage_button, hud._speed_button]:
        var button := candidate as Button
        if button != null and not button.disabled and _contains_visible(button, position):
            return button
    return null


func _find_button(node: Node, position: Vector2) -> Button:
    if node is Control:
        var control := node as Control
        if not control.is_visible_in_tree():
            return null
        if control.clip_contents and not control.get_global_rect().has_point(position):
            return null
    var children := node.get_children()
    for index in range(children.size() - 1, -1, -1):
        var found := _find_button(children[index], position)
        if found != null:
            return found
    if node is Button and node is not OptionButton:
        var button := node as Button
        if not button.disabled and button.mouse_filter != Control.MOUSE_FILTER_IGNORE and _contains_visible(button, position):
            return button
    return null


func _contains_visible(control: Control, position: Vector2) -> bool:
    if not control.is_visible_in_tree() or not control.get_global_rect().has_point(position):
        return false
    if not get_viewport().get_visible_rect().has_point(position):
        return false
    var ancestor := control.get_parent()
    while ancestor != null:
        if ancestor is Control:
            var parent_control := ancestor as Control
            if not parent_control.is_visible_in_tree():
                return false
            if parent_control.clip_contents and not parent_control.get_global_rect().has_point(position):
                return false
        ancestor = ancestor.get_parent()
    return true


func _button_identity(button: Button) -> String:
    if button == null:
        return ""
    var index := hud._contract_buttons.find(button)
    if index >= 0:
        if hud.sim == null or not hud.sim.active_contract.is_empty() or index >= hud.sim.contract_offers.size():
            return "unavailable"
        var offer: Dictionary = hud.sim.contract_offers[index]
        return "contract:%s" % str(offer.get("id", -1))
    return str(button.get_instance_id())


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        _restore_visual()
        _button = null
        _pointer = -1
        _blocked_touches.clear()
        _suppress_until = Time.get_ticks_msec() + MOUSE_SUPPRESSION_MS


func _exit_tree() -> void:
    _restore_visual()
    if is_instance_valid(hud):
        hud.set_process_input(true)
    if is_instance_valid(zone):
        zone.set_process_input(true)
