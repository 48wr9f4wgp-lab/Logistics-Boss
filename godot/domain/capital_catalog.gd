extends RefCounted
class_name CapitalCatalog

const FORKLIFT_COST := 20000


func is_known(kind: StringName) -> bool:
    return kind in [&"worker", &"rack", &"speed", &"packing", &"forklift"]


func cost(
    kind: StringName,
    worker_count: int,
    rack_level: int,
    speed_level: int,
    pack_level: int,
    forklift_unlocked: bool
) -> int:
    match kind:
        &"worker":
            return int(3500 * pow(2.0, max(0, worker_count - 3)))
        &"rack":
            return int(2500 * pow(2.0, rack_level))
        &"speed":
            return int(4000 * pow(2.0, speed_level))
        &"packing":
            return int(4500 * pow(2.0, pack_level))
        &"forklift":
            return FORKLIFT_COST
        _:
            return 999999999


func is_maxed(
    kind: StringName,
    worker_count: int,
    rack_level: int,
    speed_level: int,
    pack_level: int,
    forklift_unlocked: bool
) -> bool:
    match kind:
        &"worker":
            return worker_count >= 7
        &"rack":
            return rack_level >= 4
        &"speed":
            return speed_level >= 4
        &"packing":
            return pack_level >= 4
        &"forklift":
            return forklift_unlocked
        _:
            return true
