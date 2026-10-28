import Foundation

/// One thing drawn on a map: a stamp, path (route), region or label.
/// Stored inside the map entry's "canvas" JSON, same shape as the web app.
struct MapFeature: Identifiable, Equatable {
    var id: String
    var kind: String
    var stamp: String?
    var x: Double = 0
    var y: Double = 0
    var size: Double?
    var points: [[Double]] = []
    var label: String?
    var text: String?
    var color: String?
    var placeId: String?
    var mapId: String?
    var from: Double?
    var to: Double?
    var width: Double?
    var pathStyle: String?
    var opacity: Double?
    /// Keys this version doesn't know about, preserved on save.
    var extra: [String: JSONValue] = [:]

    static let knownKeys: Set<String> = ["id", "kind", "stamp", "x", "y", "size", "points", "label", "text", "color", "placeId", "mapId", "from", "to", "width", "pathStyle", "opacity"]

    init(id: String = "f-" + String(UUID().uuidString.prefix(8)).lowercased(), kind: String) {
        self.id = id
        self.kind = kind
    }

    init(json: JSONValue) {
        let o = json.object ?? [:]
        id = o["id"]?.string ?? "f-" + String(UUID().uuidString.prefix(8)).lowercased()
        kind = o["kind"]?.string ?? "stamp"
        stamp = o["stamp"]?.string
        x = o["x"]?.number ?? 0
        y = o["y"]?.number ?? 0
        size = o["size"]?.number
        points = (o["points"]?.array ?? []).map { p in (p.array ?? []).compactMap { $0.number } }.filter { $0.count >= 2 }
        label = o["label"]?.string
        text = o["text"]?.string
        color = o["color"]?.string
        placeId = o["placeId"]?.string
        mapId = o["mapId"]?.string
        from = o["from"]?.number
        to = o["to"]?.number
        width = o["width"]?.number
        pathStyle = o["pathStyle"]?.string
        opacity = o["opacity"]?.number
        extra = o.filter { !MapFeature.knownKeys.contains($0.key) }
    }

    var json: JSONValue {
        var o = extra
        o["id"] = .string(id)
        o["kind"] = .string(kind)
        func putS(_ k: String, _ v: String?) { if let v = v, !v.isEmpty { o[k] = .string(v) } }
        func putN(_ k: String, _ v: Double?) { if let v = v { o[k] = .number(v) } }
        putS("stamp", stamp)
        if kind == "path" || kind == "region" {
            o["points"] = .array(points.map { .array($0.map { .number($0) }) })
        } else {
            o["x"] = .number(x)
            o["y"] = .number(y)
        }
        putN("size", size)
        putS("label", label)
        putS("text", text)
        putS("color", color)
        putS("placeId", placeId)
        putS("mapId", mapId)
        putN("from", from)
        putN("to", to)
        putN("width", width)
        putS("pathStyle", pathStyle)
        putN("opacity", opacity)
        return .object(o)
    }

    var anchor: CGPoint {
        if kind == "path" || kind == "region" {
            guard !points.isEmpty else { return .zero }
            if kind == "path" {
                let p = points[points.count / 2]
                return CGPoint(x: p[0], y: p[1])
            }
            let sx = points.reduce(0) { $0 + $1[0] }, sy = points.reduce(0) { $0 + $1[1] }
            return CGPoint(x: sx / Double(points.count), y: sy / Double(points.count))
        }
        return CGPoint(x: x, y: y)
    }

    mutating func move(from original: MapFeature, dx: Double, dy: Double) {
        if kind == "path" || kind == "region" {
            points = original.points.map { [$0[0] + dx, $0[1] + dy] }
        } else {
            x = original.x + dx
            y = original.y + dy
        }
    }
}

struct MapCanvas: Equatable {
    var width: Double
    var height: Double
    var features: [MapFeature]

    init(json: JSONValue, fallbackSize: (Double, Double)) {
        let o = json.object ?? [:]
        width = o["width"]?.number ?? fallbackSize.0
        height = o["height"]?.number ?? fallbackSize.1
        features = (o["features"]?.array ?? []).map { MapFeature(json: $0) }
    }

    init(width: Double, height: Double) {
        self.width = width
        self.height = height
        features = []
    }

    var json: JSONValue {
        .object(["width": .number(width), "height": .number(height), "features": .array(features.map { $0.json })])
    }

    func index(of id: String?) -> Int? {
        guard let id = id else { return nil }
        return features.firstIndex { $0.id == id }
    }

    /// Topmost feature under a point (map units), with a tolerance for thin paths.
    func hitTest(_ p: CGPoint, tolerance: Double) -> String? {
        let order: [String: Int] = ["region": 0, "path": 1, "stamp": 2, "label": 3]
        let sorted = features.enumerated().sorted { a, b in
            let oa = order[a.element.kind] ?? 2, ob = order[b.element.kind] ?? 2
            return oa != ob ? oa < ob : a.offset < b.offset
        }.map { $0.element }
        for f in sorted.reversed() {
            switch f.kind {
            case "region":
                if pointInPolygon(p, f.points) { return f.id }
            case "path":
                for i in 1..<max(f.points.count, 1) {
                    let a = f.points[i - 1], b = f.points[i]
                    if distanceToSegment(p, CGPoint(x: a[0], y: a[1]), CGPoint(x: b[0], y: b[1])) < tolerance + (f.width ?? 3) { return f.id }
                }
            case "label":
                let size = f.size ?? 22
                let halfWidth = max(30, Double((f.text ?? "").count) * size * 0.3)
                if abs(p.x - f.x) < halfWidth && p.y < f.y + size * 0.3 && p.y > f.y - size { return f.id }
            default:
                let half = (f.size ?? 40) / 2
                if abs(p.x - f.x) < half + tolerance / 2 && abs(p.y - f.y) < half + tolerance / 2 { return f.id }
            }
        }
        return nil
    }
}

func pointInPolygon(_ p: CGPoint, _ pts: [[Double]]) -> Bool {
    guard pts.count >= 3 else { return false }
    var inside = false
    var j = pts.count - 1
    for i in 0..<pts.count {
        let xi = pts[i][0], yi = pts[i][1], xj = pts[j][0], yj = pts[j][1]
        if (yi > p.y) != (yj > p.y) && p.x < (xj - xi) * (p.y - yi) / (yj - yi) + xi { inside.toggle() }
        j = i
    }
    return inside
}

func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
    let dx = b.x - a.x, dy = b.y - a.y
    let len2 = dx * dx + dy * dy
    if len2 == 0 { return hypot(p.x - a.x, p.y - a.y) }
    let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
    return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
}

/// Alternating left/right footprints along a route (same as web/js/maps.js).
func footprints(_ points: [[Double]], spacing: Double) -> [(x: Double, y: Double, angle: Double)] {
    var out: [(x: Double, y: Double, angle: Double)] = []
    var carry = 0.0
    var i = 0
    guard points.count > 1 else { return out }
    for s in 1..<points.count {
        let x1 = points[s - 1][0], y1 = points[s - 1][1], x2 = points[s][0], y2 = points[s][1]
        let len = hypot(x2 - x1, y2 - y1)
        if len == 0 { continue }
        let ux = (x2 - x1) / len, uy = (y2 - y1) / len
        var d = spacing - carry
        while d <= len {
            let side: Double = i % 2 == 1 ? 4 : -4
            out.append((x1 + ux * d - uy * side, y1 + uy * d + ux * side, atan2(uy, ux)))
            i += 1
            d += spacing
        }
        carry = len - (d - spacing)
    }
    return out
}

/// Park–Miller generator so star patterns match the web app.
struct ParkMiller {
    var state: Int
    mutating func next() -> Double {
        state = (state * 16807) % 2147483647
        return Double(state) / 2147483647
    }
}

// MARK: - Connections to places, events and characters

extension Store {
    func mapCanvas(_ map: Entity) -> MapCanvas {
        MapCanvas(json: map["canvas"], fallbackSize: ref.mapSize(map.string("scale")))
    }

    func saveCanvas(_ mapID: String, _ canvas: MapCanvas) {
        update("maps", mapID, "canvas", canvas.json)
    }

    /// A feature's time window: its own from/to, otherwise its linked place's.
    func window(of f: MapFeature) -> (from: Double?, to: Double?) {
        let place = get("places", f.placeId)
        return (f.from ?? place?.number("existsFrom"), f.to ?? place?.number("existsTo"))
    }

    func isVisible(_ f: MapFeature, at time: Double?) -> Bool {
        guard let t = time else { return true }
        let w = window(of: f)
        return (w.from == nil || w.from! <= t) && (w.to == nil || t <= w.to!)
    }

    /// Walks up the place hierarchy until it reaches a place drawn on the map.
    func placeOnMap(_ placeID: String?, _ onMap: Set<String>) -> String? {
        var id = placeID
        var depth = 0
        while let current = id, !current.isEmpty, depth < 25 {
            if onMap.contains(current) { return current }
            id = get("places", current)?.string("parent")
            depth += 1
        }
        return nil
    }

    private func featuresByPlace(_ canvas: MapCanvas) -> [String: MapFeature] {
        var out: [String: MapFeature] = [:]
        for f in canvas.features { if let p = f.placeId, out[p] == nil { out[p] = f } }
        return out
    }

    private func sequence(_ e: Entity) -> Double? { e.number("sequence") }

    func eventsByFeature(_ canvas: MapCanvas, time: Double?) -> [String: [Entity]] {
        let byPlace = featuresByPlace(canvas)
        let onMap = Set(byPlace.keys)
        var out: [String: [Entity]] = [:]
        for ev in Continuity.orderedEvents(self) {
            let place = ev.string("place")
            if place.isEmpty { continue }
            if let t = time {
                guard let s = sequence(ev), s <= t else { continue }
            }
            guard let pid = placeOnMap(place, onMap), let f = byPlace[pid] else { continue }
            out[f.id, default: []].append(ev)
        }
        return out
    }

    /// Ordered stops for a character: homeland, then each event place on this map.
    func journey(_ characterID: String, _ canvas: MapCanvas, time: Double?) -> [MapFeature] {
        let byPlace = featuresByPlace(canvas)
        let onMap = Set(byPlace.keys)
        var stops: [MapFeature] = []
        if let c = get("characters", characterID), let home = placeOnMap(c.string("homeland"), onMap), let f = byPlace[home] {
            stops.append(f)
        }
        for ev in Continuity.orderedEvents(self) where ev.strings("characters").contains(characterID) {
            if let t = time {
                guard let s = sequence(ev), s <= t else { continue }
            }
            guard let pid = placeOnMap(ev.string("place"), onMap), let f = byPlace[pid] else { continue }
            if stops.last?.id == f.id { continue }
            stops.append(f)
        }
        return stops
    }

    func mapsWithPlace(_ placeID: String) -> [Entity] {
        list("maps").filter { mapCanvas($0).features.contains { $0.placeId == placeID } }
    }

    /// The in-world order range used by the map time slider.
    func timeRange() -> ClosedRange<Double> {
        var nums: [Double] = []
        for e in list("events") { if let n = e.number("sequence") { nums.append(n) } }
        for p in list("places") { for k in ["existsFrom", "existsTo"] { if let n = p.number(k) { nums.append(n) } } }
        for m in list("maps") { for k in ["eraFrom", "eraTo"] { if let n = m.number(k) { nums.append(n) } } }
        guard let lo = nums.min(), let hi = nums.max() else { return 0...10 }
        return lo == hi ? (lo - 1)...(hi + 1) : lo...hi
    }

    func ancestors(ofPlace id: String) -> [Entity] {
        var out: [Entity] = []
        var current = get("places", id)?.string("parent")
        var depth = 0
        while let c = current, let p = get("places", c), depth < 25 {
            out.insert(p, at: 0)
            current = p.string("parent")
            depth += 1
        }
        return out
    }
}
