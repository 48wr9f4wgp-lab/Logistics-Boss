extends Node
class_name LogisticsGameFeel

const MIX_RATE := 22050
const MAX_SAMPLE := 32767.0

var sim: WarehouseSim
var audio_enabled := true
var haptics_enabled := true
var feedback_count := 0

var _player: AudioStreamPlayer


func _ready() -> void:
    _player = AudioStreamPlayer.new()
    _player.volume_db = -8.0
    add_child(_player)


func bind_sim(next_sim: WarehouseSim) -> void:
    if sim != null and sim.event_emitted.is_connected(_on_sim_event):
        sim.event_emitted.disconnect(_on_sim_event)
    sim = next_sim
    if sim != null and not sim.event_emitted.is_connected(_on_sim_event):
        sim.event_emitted.connect(_on_sim_event)


func _on_sim_event(event: Dictionary) -> void:
    var event_type := String(event.get("type", ""))
    match event_type:
        "shipment":
            _feedback([760.0, 940.0], 0.035, 0.11, 16)
        "policy_changed", "staffing_changed", "routing_changed":
            _feedback([420.0, 520.0], 0.035, 0.08, 18)
        "upgrade_purchased", "facility_purchased", "receiving_annex_purchased", "inbound_carrier_program_purchased":
            _feedback([430.0, 620.0], 0.055, 0.13, 30)
        "contract_completed":
            _feedback([520.0, 660.0, 790.0], 0.055, 0.15, 55)
        "contract_failed":
            _feedback([240.0, 185.0], 0.075, 0.11, 45)
        "rank_up":
            _feedback([390.0, 520.0, 660.0, 820.0], 0.065, 0.17, 90)
        "measurement_completed":
            var before: Dictionary = event.get("before", {})
            var after: Dictionary = event.get("after", {})
            var delta := float(after.get("shipments_per_min", 0.0)) - float(before.get("shipments_per_min", 0.0))
            if delta >= 0.5:
                _feedback([560.0, 700.0], 0.045, 0.10, 22)
            elif delta <= -0.5:
                _feedback([280.0, 230.0], 0.055, 0.08, 28)


func _feedback(frequencies: Array[float], segment_seconds: float, gain: float, vibration_ms: int) -> void:
    feedback_count += 1
    if audio_enabled and _player != null:
        _player.stream = _build_tone(frequencies, segment_seconds, gain)
        _player.play()
    if haptics_enabled and vibration_ms > 0 and (OS.has_feature("android") or OS.has_feature("ios")):
        Input.vibrate_handheld(vibration_ms)


func _build_tone(frequencies: Array[float], segment_seconds: float, gain: float) -> AudioStreamWAV:
    var seconds := maxf(0.01, segment_seconds)
    var samples_per_segment := maxi(1, int(float(MIX_RATE) * seconds))
    var total_samples := samples_per_segment * maxi(1, frequencies.size())
    var bytes := PackedByteArray()
    bytes.resize(total_samples * 2)

    var byte_index := 0
    for frequency in frequencies:
        var safe_frequency := maxf(40.0, float(frequency))
        for sample_index in samples_per_segment:
            var progress := float(sample_index) / float(maxi(1, samples_per_segment - 1))
            var attack := minf(1.0, progress * 10.0)
            var release := clampf((1.0 - progress) * 4.0, 0.0, 1.0)
            var envelope := attack * release
            var t := float(sample_index) / float(MIX_RATE)
            var wave := sin(TAU * safe_frequency * t)
            var overtone := sin(TAU * safe_frequency * 2.0 * t) * 0.18
            var sample_value := clampf((wave + overtone) * envelope * gain, -1.0, 1.0)
            var encoded := int(round(sample_value * MAX_SAMPLE))
            if encoded < 0:
                encoded += 65536
            bytes[byte_index] = encoded & 0xff
            bytes[byte_index + 1] = (encoded >> 8) & 0xff
            byte_index += 2

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = MIX_RATE
    stream.stereo = false
    stream.data = bytes
    return stream


func _exit_tree() -> void:
    if sim != null and sim.event_emitted.is_connected(_on_sim_event):
        sim.event_emitted.disconnect(_on_sim_event)
