extends RefCounted
class_name Rank2FacilityCatalog

const RENOVATION_RATE := 0.75

const DEFINITIONS := {
    &"double_dock": {
        "zone": "A",
        "group": "intake",
        "label": "ダブルドック",
        "effect": "入荷上限+6 / 入荷頻度 約22%増",
        "cost": 12000,
    },
    &"buffer_yard": {
        "zone": "A",
        "group": "intake",
        "label": "受入バッファ",
        "effect": "入荷上限+14 / ピーク耐性",
        "cost": 10000,
    },
    &"fast_pick_rack": {
        "zone": "B",
        "group": "storage",
        "label": "高速ピックラック",
        "effect": "保管+12 / ピック25%高速",
        "strength": "ピック25%高速",
        "weakness": "保管容量は高密度ラックより4箱少ない",
        "cost": 13000,
    },
    &"high_density_rack": {
        "zone": "B",
        "group": "storage",
        "label": "高密度ラック",
        "effect": "保管+16 / ピック14%低速",
        "strength": "保管容量 +16",
        "weakness": "ピック処理が14%低速",
        "cost": 12000,
    },
    &"parallel_pack": {
        "zone": "C",
        "group": "packing",
        "label": "並列梱包ライン",
        "effect": "2箱同時 / 1箱あたり10%低速",
        "strength": "2箱を同時処理",
        "weakness": "1箱あたりの処理は10%低速",
        "cost": 14000,
    },
    &"fast_pack_cell": {
        "zone": "C",
        "group": "packing",
        "label": "高速梱包セル",
        "effect": "1箱処理 / 梱包42%高速",
        "strength": "1箱を42%高速処理",
        "weakness": "同時処理は1箱のみ",
        "cost": 13000,
    },
}


func is_known(kind: StringName) -> bool:
    return DEFINITIONS.has(kind)


func info(kind: StringName) -> Dictionary:
    if not DEFINITIONS.has(kind):
        return {}
    return (DEFINITIONS[kind] as Dictionary).duplicate(true)


func cost(kind: StringName) -> int:
    return int(info(kind).get("cost", 0))


func renovation_cost(kind: StringName) -> int:
    if not is_known(kind):
        return 0
    return int(round(float(cost(kind)) * RENOVATION_RATE))


func strength(kind: StringName) -> String:
    return String(info(kind).get("strength", effect(kind)))


func weakness(kind: StringName) -> String:
    return String(info(kind).get("weakness", ""))


func group(kind: StringName) -> String:
    return String(info(kind).get("group", ""))


func zone(kind: StringName) -> String:
    return String(info(kind).get("zone", ""))


func label(kind: StringName) -> String:
    return String(info(kind).get("label", String(kind)))


func effect(kind: StringName) -> String:
    return String(info(kind).get("effect", ""))


func all_kinds() -> Array[StringName]:
    return [
        &"double_dock",
        &"buffer_yard",
        &"fast_pick_rack",
        &"high_density_rack",
        &"parallel_pack",
        &"fast_pack_cell",
    ]
