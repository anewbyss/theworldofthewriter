import SwiftUI

/// Real borders (Natural Earth), preset areas and real places (mirrors the real-geography code in web/js/maps.js).
struct GeoBundle: Decodable {
    struct Area: Decodable, Identifiable, Hashable { let id: String; let name: String; let bbox: [Double] }
    struct Country: Decodable { let id: String; let name: String; let rings: [[[Double]]] }
    struct Place: Decodable, Identifiable, Hashable {
        let id: String
        let name: String
        let lat: Double
        let lon: Double
        let kind: String
        let pool: String
        let note: String
        let stamp: String
        let land: String?
        let lore: String?
    }
    let source: String
    let areas: [Area]
    let countries: [Country]
    let places: [Place]

    /// Decoded on first use, so the app starts as fast as before.
    static let shared: GeoBundle = {
        do { return try JSONDecoder().decode(GeoBundle.self, from: Data(geoJSON.utf8)) }
        catch { fatalError("Geography data failed to load: \(error)") }
    }()

    func place(_ id: String?) -> Place? { places.first { $0.id == id } }
}

/// How a [west, south, east, north] box is fitted onto a canvas (equirectangular, squashed by latitude).
struct GeoFit: Equatable {
    var bbox: [Double]
    var kx: Double
    var scale: Double
    var ox: Double
    var oy: Double

    init(bbox: [Double], width W: Double, height H: Double) {
        self.bbox = bbox
        kx = cos((bbox[1] + bbox[3]) / 2 * .pi / 180)
        let pw = (bbox[2] - bbox[0]) * kx, ph = bbox[3] - bbox[1]
        scale = min(W / pw, H / ph) * 0.96
        ox = (W - pw * scale) / 2
        oy = (H - ph * scale) / 2
    }

    init?(json: JSONValue?) {
        guard let o = json?.object, let b = o["bbox"]?.array?.compactMap({ $0.number }), b.count == 4,
              let kx = o["kx"]?.number, let scale = o["scale"]?.number, let ox = o["ox"]?.number, let oy = o["oy"]?.number else { return nil }
        bbox = b; self.kx = kx; self.scale = scale; self.ox = ox; self.oy = oy
    }

    var json: JSONValue {
        .object(["bbox": .array(bbox.map { .number($0) }), "kx": .number(kx), "scale": .number(scale), "ox": .number(ox), "oy": .number(oy)])
    }

    private func r(_ v: Double) -> Double { (v * 10).rounded() / 10 }
    func raw(_ lon: Double, _ lat: Double) -> [Double] { [r(ox + (lon - bbox[0]) * kx * scale), r(oy + (bbox[3] - lat) * scale)] }
    /// A real place's position; a box that runs past 180° wraps western longitudes round.
    func xy(_ lon: Double, _ lat: Double) -> [Double] { raw(bbox[2] > 180 && lon < bbox[0] - 1 ? lon + 360 : lon, lat) }
    func contains(_ lon: Double, _ lat: Double) -> Bool {
        let l = bbox[2] > 180 && lon < bbox[0] - 1 ? lon + 360 : lon
        return l >= bbox[0] && l <= bbox[2] && lat >= bbox[1] && lat <= bbox[3]
    }
}

extension MapCanvas {
    /// Set when the map was drawn from real geography.
    var geo: GeoFit? {
        get { GeoFit(json: extra["geo"]) }
        set { extra["geo"] = newValue?.json }
    }
}

extension MapFeature {
    var realCountry: String? { extra["realCountry"]?.string }
    var realPlace: String? { extra["real"]?.string }
}

/// Makes a ring's longitudes continuous across the date line, then moves it next to the map's box.
func unwrapRing(_ ring: [[Double]], bbox: [Double]) -> [[Double]] {
    guard let first = ring.first else { return ring }
    var off = 0.0, prev = first[0]
    var out: [[Double]] = []
    for p in ring {
        if p[0] + off - prev > 180 { off -= 360 } else if p[0] + off - prev < -180 { off += 360 }
        prev = p[0] + off
        out.append([p[0] + off, p[1]])
    }
    let mid = out.reduce(0) { $0 + $1[0] } / Double(out.count)
    let k = (((bbox[0] + bbox[2]) / 2 - mid) / 360).rounded()
    return k == 0 ? out : out.map { [$0[0] + k * 360, $0[1]] }
}

/// Country shapes inside the box, as regions; the largest piece of each big country carries its name.
func realGeographyFeatures(_ geo: GeoFit, width W: Double, height H: Double, names: Bool) -> [MapFeature] {
    var feats: [MapFeature] = []
    for c in GeoBundle.shared.countries {
        var best: (index: Int, area: Double)?
        for raw in c.rings {
            let ring = unwrapRing(raw, bbox: geo.bbox)
            let lons = ring.map { $0[0] }, lats = ring.map { $0[1] }
            guard let lo0 = lons.min(), let lo1 = lons.max(), let la0 = lats.min(), let la1 = lats.max(),
                  lo1 >= geo.bbox[0], lo0 <= geo.bbox[2], la1 >= geo.bbox[1], la0 <= geo.bbox[3] else { continue }
            let pts = ring.map { geo.raw($0[0], $0[1]) }
            var area = 0.0
            for i in 0..<pts.count { let q = pts[(i + 1) % pts.count]; area += pts[i][0] * q[1] - q[0] * pts[i][1] }
            area = abs(area) / 2
            if area < 2 { continue }
            var f = MapFeature(kind: "region")
            f.color = "land"
            f.opacity = 1
            f.points = pts
            f.extra["realCountry"] = .string(c.name)
            feats.append(f)
            if best == nil || area > best!.area { best = (feats.count - 1, area) }
        }
        if names, let b = best, b.area > W * H * 0.003 {
            let a = feats[b.index].anchor
            if a.x > 40 && a.x < W - 40 && a.y > 30 && a.y < H - 30 { feats[b.index].label = c.name }
        }
    }
    return feats
}

func realPlaceFeature(_ p: GeoBundle.Place, _ geo: GeoFit) -> MapFeature {
    var f = MapFeature(kind: "stamp")
    let xy = geo.xy(p.lon, p.lat)
    f.stamp = p.stamp
    f.x = xy[0]
    f.y = xy[1]
    f.size = 34
    f.label = p.name
    f.extra["real"] = .string(p.id)
    return f
}

extension Store {
    /// A ready-made map of a real area with its places, e.g. for "Map this land".
    func createRealMap(title: String, bbox: [Double], scale: String = "region") -> Entity {
        let size = ref.mapSize(scale)
        var canvas = MapCanvas(width: size.0, height: size.1)
        let geo = GeoFit(bbox: bbox, width: size.0, height: size.1)
        canvas.geo = geo
        canvas.features = realGeographyFeatures(geo, width: size.0, height: size.1, names: true)
            + GeoBundle.shared.places.filter { geo.contains($0.lon, $0.lat) }.map { realPlaceFeature($0, geo) }
        return create("maps", ["title": .string(title), "scale": .string(scale), "mapStyle": .string("atlas"), "canvas": canvas.json])
    }
}

/// "Real places & borders" in the map designer's overview.
struct RealGeographyPanel: View {
    @EnvironmentObject var store: Store
    let mapID: String
    let canvas: MapCanvas
    @State private var area = ""
    @State private var names = true
    @State private var query = ""
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Real places & borders", systemImage: "globe.europe.africa").font(.headline)
            if !loaded && canvas.geo == nil {
                Text("Start from real coastlines and today's borders, then place real cities, sacred sites and ruins at their true positions.").font(.caption).foregroundColor(.secondary)
                Button { loaded = true } label: { Label("Use real geography & places", systemImage: "globe") }.buttonStyle(.bordered)
            } else {
                content
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.wowVioletSoft.opacity(0.08)))
    }

    @ViewBuilder private var content: some View {
        let geo = GeoBundle.shared
        Picker("Area", selection: $area) {
            if canvas.geo != nil { Text("This map's current area").tag("") } else { Text("Choose an area…").tag("") }
            Section("Areas") { ForEach(geo.areas) { Text($0.name).tag("area:" + $0.id) } }
            Section("Lands & stewards") { ForEach(store.ref.lands) { Text($0.name).tag($0.id) } }
        }
        Toggle("Country names", isOn: $names)
        HStack {
            Button(canvas.geo == nil ? "Add real coastlines & borders" : "Redraw real borders") { redraw() }
                .buttonStyle(.borderedProminent)
                .disabled(area.isEmpty && canvas.geo == nil)
            if canvas.geo != nil {
                Button("Remove") {
                    var c = canvas
                    c.features.removeAll { $0.realCountry != nil }
                    c.geo = nil
                    store.saveCanvas(mapID, c)
                }
            }
        }
        if let g = canvas.geo {
            let inView = geo.places.filter { g.contains($0.lon, $0.lat) }
            let q = query.lowercased()
            let shown = inView.filter { q.isEmpty || "\($0.name) \($0.note)".lowercased().contains(q) }.prefix(60)
            Text("Real places in this area (\(inView.count))").font(.subheadline.weight(.semibold))
            TextField("Find a real city, sacred site, ruin…", text: $query).textFieldStyle(.roundedBorder)
            ForEach(Array(shown)) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(.callout)
                        Text(p.kind).font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button { add([p], g) } label: { Image(systemName: "plus.circle") }.buttonStyle(.borderless)
                }
            }
            if shown.isEmpty { Text("No listed places here — add your own.").font(.caption).foregroundColor(.secondary) }
            if !inView.isEmpty {
                Button("Add all \(inView.count)") {
                    let have = Set(canvas.features.compactMap { $0.realPlace })
                    add(inView.filter { !have.contains($0.id) }, g)
                }
                .font(.callout)
            }
        } else {
            Text("Add real borders first to place real locations at their true positions.").font(.caption).foregroundColor(.secondary)
        }
        Text("Borders: Natural Earth (public domain), today's boundaries. Real places: a starting list — drag them, rename them, and add your own.")
            .font(.caption2).foregroundColor(.secondary)
    }

    private func add(_ places: [GeoBundle.Place], _ g: GeoFit) {
        var c = canvas
        c.features.append(contentsOf: places.map { realPlaceFeature($0, g) })
        store.saveCanvas(mapID, c)
    }

    private func redraw() {
        let geo = GeoBundle.shared
        let bbox: [Double]
        if area.hasPrefix("area:"), let a = geo.areas.first(where: { "area:" + $0.id == area }) { bbox = a.bbox }
        else if let l = store.ref.lands.first(where: { $0.id == area }), let b = l.bbox { bbox = b }
        else if let g = canvas.geo { bbox = g.bbox }
        else { return }
        var c = canvas
        let fit = GeoFit(bbox: bbox, width: c.width, height: c.height)
        c.geo = fit
        // Real places move to their true spot in the new area (or drop off if outside it); your own work stays as drawn.
        let drawn = c.features.filter { $0.realCountry == nil }.compactMap { f -> MapFeature? in
            guard let p = geo.place(f.realPlace) else { return f }
            guard fit.contains(p.lon, p.lat) else { return nil }
            var moved = f
            let xy = fit.xy(p.lon, p.lat)
            moved.x = xy[0]
            moved.y = xy[1]
            return moved
        }
        c.features = realGeographyFeatures(fit, width: c.width, height: c.height, names: names) + drawn
        store.saveCanvas(mapID, c)
        area = ""
    }
}

/// What a real place or country connects to: its land's stewards, the libraries and the economy.
struct RealFeatureInfo: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let feature: MapFeature

    var body: some View {
        if let name = feature.realCountry {
            let econ = EconomyData.shared
            let modernNames = Dictionary(store.ref.modern.flatMap { $0.items.map { ($0.id, $0.name) } }, uniquingKeysWith: { a, _ in a })
            let c = econ.find(name, modernNames: modernNames)
            let lands = store.ref.lands.filter { $0.name.contains(name) || ((name == "Israel" || name == "Palestine") && $0.id == "land:palestine") }
            info {
                Text("Real country (today's borders)").font(.caption.weight(.bold))
                if let c = c {
                    let pop = econ.latest(c.pop), gdp = econ.latest(c.gdp)
                    Text([pop.map { "Population \(formatAmount($0.value, "people"))" }, gdp.map { "GDP \(formatAmount($0.value * 1e6, "US$"))" }].compactMap { $0 }.joined(separator: " · ")).font(.caption)
                    if let pool = c.pool { Button((store.ref.culture(pool)?.region ?? pool) + " →") { router.push(.culture(pool)) }.font(.caption) }
                }
                ForEach(lands) { l in Button("\(l.name.components(separatedBy: " (").first ?? l.name): stewards →") { router.push(.land(l.id)) }.font(.caption) }
                Text("For who held this land in the past, see Lands & stewards and the Time Atlas.").font(.caption2).foregroundColor(.secondary)
            }
        } else if let p = GeoBundle.shared.place(feature.realPlace) {
            info {
                Text(p.name).font(.caption.weight(.bold))
                Text("\(p.kind) · \(String(format: "%.2f", p.lat))°, \(String(format: "%.2f", p.lon))°").font(.caption2).foregroundColor(.secondary)
                Text(p.note).font(.caption)
                Button((store.ref.culture(p.pool)?.region ?? p.pool) + " →") { router.push(.culture(p.pool)) }.font(.caption)
                if let land = store.ref.lands.first(where: { $0.id == p.land }) {
                    Button("\(land.name.components(separatedBy: " (").first ?? land.name): stewards →") { router.push(.land(land.id)) }.font(.caption)
                }
            }
        }
    }

    private func info<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) { content() }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.wowVioletSoft.opacity(0.1)))
    }
}
