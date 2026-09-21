extends RefCounted
class_name WorkRoutes

static func points(source: Vector3, target: Vector3) -> Array[Vector3]:
    # Presentation waypoints only. Domain task duration and reservations own work.
    return [source, Vector3(source.x, source.y, 3.25), Vector3(target.x, target.y, 3.25), target]

static func at(path: Array[Vector3], fraction: float) -> Vector3:
    var length := 0.0
    for i in path.size() - 1:
        length += path[i].distance_to(path[i + 1])
    var remaining := clampf(fraction, 0.0, 1.0) * length
    for i in path.size() - 1:
        var distance := path[i].distance_to(path[i + 1])
        if remaining <= distance and distance > 0.0001:
            return path[i].lerp(path[i + 1], remaining / distance)
        remaining -= distance
    return path[-1]

static func waiting(role: String, index: int) -> Vector3:
    var origin := Vector3(-4.8, 0.35, 3.35) if role == "store" else (Vector3(0.1, 0.35, 3.35) if role == "pick" else Vector3(5.0, 0.35, 3.35))
    return origin + Vector3(float(index % 2) * 0.5, 0.0, float(index / 2) * 0.22)
