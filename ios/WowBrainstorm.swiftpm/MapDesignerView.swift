import SwiftUI
import UniformTypeIdentifiers

/// Map designer: stamps, routes, regions and labels, linked to places, events,
/// characters and detail maps, viewable at any moment of in-world time.
struct MapDesignerView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let mapID: String

    enum Tool: String, CaseIterable {
        case pan, select, stamp, path, region, label
        var title: String {
            switch self {
            case .pan: return "Scroll"
            case .select: return "Select"
            case .stamp: return "Stamp"
            case .path: return "Route"
            case .region: return "Region"
            case .label: return "Label"
            }
        }
        var icon: String {
            switch self {
            case .pan: return "hand.raised"
            case .select: return "cursorarrow"
            case .stamp: return "mappin"
            case .path: return "point.topleft.down.curvedto.point.bottomright.up"
            case .region: return "pentagon"
            case .label: return "textformat"
            }
        }
    }

    @State private var tool: Tool = .select
    @State private var stamp = "pin"
    @State private var selectedID: String?
    @State private var draft: [[Double]] = []
    @State private var zoom: Double = 0
    @State private var timeOn = false
    @State private var time: Double = 0
    @State private var journeyID = ""
    @State private var layers: Set<String> = ["regions", "paths", "stamps", "labels", "events", "decor"]
    @State private var dragOrigin: MapFeature?
    @State private var dragging = false
    @State private var labelPoint: CGPoint?
    @State private var labelText = ""
    @State private var showInspector = true
    @State private var exportDoc: ExportDocument?
    @State private var showExporter = false

    var body: some View {
        if let map = store.get("maps", mapID) {
            let canvas = store.mapCanvas(map)
            VStack(spacing: 0) {
                toolbar(map)
                timebar
                Divider()
                HStack(spacing: 0) {
                    mapArea(map, canvas)
                    if showInspector {
                        Divider()
                        ScrollView { inspector(map, canvas).padding() }
                            .frame(width: 320)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                    }
                }
            }
            .navigationTitle(store.title("maps", map))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.right") }
                    Button { exportPNG(map, canvas) } label: { Label("Export image", systemImage: "square.and.arrow.up") }
                    Button { router.push(.mapDetails(mapID)) } label: { Label("Details", systemImage: "info.circle") }
                }
            }
            .alert("Label text", isPresented: Binding(get: { labelPoint != nil }, set: { if !$0 { labelPoint = nil } })) {
                TextField("Label", text: $labelText)
                Button("Add") {
                    if let p = labelPoint, !labelText.isEmpty {
                        var f = MapFeature(kind: "label")
                        f.text = labelText
                        f.x = p.x
                        f.y = p.y
                        f.size = 24
                        mutate { $0.features.append(f) }
                        selectedID = f.id
                    }
                    labelText = ""
                    labelPoint = nil
                }
                Button("Cancel", role: .cancel) { labelPoint = nil }
            }
            .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .png, defaultFilename: "\(store.title("maps", map)).png") { _ in }
            .onAppear {
                if let from = map.number("eraFrom") { time = from } else { time = store.timeRange().upperBound }
            }
        } else {
            Text("This map no longer exists.").foregroundColor(.secondary)
        }
    }

    // MARK: Editing helpers

    private func mutate(_ change: (inout MapCanvas) -> Void) {
        guard let map = store.get("maps", mapID) else { return }
        var c = store.mapCanvas(map)
        change(&c)
        store.saveCanvas(mapID, c)
    }

    private func mutateSelected(_ change: (inout MapFeature) -> Void) {
        mutate { c in
            if let i = c.index(of: selectedID) { change(&c.features[i]) }
        }
    }

    private func finishDraft() {
        let need = tool == .region ? 3 : 2
        if draft.count >= need {
            var f = MapFeature(kind: tool == .region ? "region" : "path")
            f.points = draft
            if tool == .region { f.color = "land" }
            mutate { $0.features.append(f) }
            selectedID = f.id
        }
        draft = []
    }

    // MARK: Toolbar

    private func toolbar(_ map: Entity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Tool.allCases, id: \.self) { t in
                        Button {
                            tool = t
                            if t != .path && t != .region { draft = [] }
                        } label: {
                            Label(t.title, systemImage: t.icon)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(tool == t ? Color.wowGold : Color.wowVioletSoft.opacity(0.12)))
                                .foregroundColor(tool == t ? .wowVioletDeep : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                    Divider().frame(height: 24)
                    Button { zoom = max(0.1, currentZoom / 1.25) } label: { Image(systemName: "minus.magnifyingglass") }
                    Button("Fit") { zoom = 0 }
                    Button { zoom = min(4, currentZoom * 1.25) } label: { Image(systemName: "plus.magnifyingglass") }
                }
                .padding(.horizontal)
            }
            if tool == .stamp {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(store.ref.mapStamps.keys.sorted(), id: \.self) { key in
                            if let def = store.ref.mapStamps[key] {
                                Button { stamp = key } label: {
                                    VStack(spacing: 2) {
                                        StampIcon(def: def, style: store.ref.mapStyle(map.string("mapStyle"))).frame(width: 30, height: 30)
                                        Text(def.label).font(.caption2).lineLimit(1)
                                    }
                                    .frame(width: 72)
                                    .padding(4)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: store.ref.mapStyle(map.string("mapStyle")).colors["paper"] ?? "#FFFFFF")))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(stamp == key ? Color.wowGold : Color.secondary.opacity(0.3), lineWidth: stamp == key ? 3 : 1))
                                    .foregroundColor(.black)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            if tool == .path || tool == .region {
                HStack {
                    Text(tool == .region ? "Tap points around the area, then Finish." : "Tap points along the route, then Finish.")
                        .font(.caption).foregroundColor(.secondary)
                    Button("Finish") { finishDraft() }.buttonStyle(.borderedProminent)
                    Button("Cancel") { draft = [] }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    private var timebar: some View {
        let range = store.timeRange()
        return HStack(spacing: 12) {
            Toggle("Time travel", isOn: $timeOn).fixedSize()
            if timeOn {
                Slider(value: $time, in: range, step: 1)
                Text("Order \(Int(time))").font(.caption.monospacedDigit()).frame(width: 80)
            } else {
                Text("Showing all of time").font(.caption).foregroundColor(.secondary)
                Spacer()
            }
            Picker("Journey", selection: $journeyID) {
                Text("No journey").tag("")
                ForEach(store.options("characters")) { Text("Trace " + $0.label).tag($0.id) }
            }
            .pickerStyle(.menu)
            Menu {
                ForEach(["regions", "paths", "stamps", "labels", "events", "decor"], id: \.self) { l in
                    Button {
                        if layers.contains(l) { layers.remove(l) } else { layers.insert(l) }
                    } label: { Label(l.capitalized, systemImage: layers.contains(l) ? "checkmark.square" : "square") }
                }
            } label: { Label("Layers", systemImage: "square.3.layers.3d") }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: Map area

    @State private var fitZoom: Double = 0.5
    private var currentZoom: Double { zoom == 0 ? fitZoom : zoom }

    private func mapArea(_ map: Entity, _ canvas: MapCanvas) -> some View {
        GeometryReader { geo in
            let fit = max(0.1, min((geo.size.width - 8) / canvas.width, (geo.size.height - 8) / canvas.height))
            let z = zoom == 0 ? fit : zoom
            ScrollView([.horizontal, .vertical]) {
                Canvas { ctx, _ in
                    var o = MapRenderOptions()
                    o.zoom = z
                    o.time = timeOn ? time : nil
                    o.journeyID = journeyID
                    o.selectedID = selectedID
                    o.editing = true
                    o.draft = draft
                    o.draftIsRegion = tool == .region
                    o.layers = layers
                    MapRenderer.draw(&ctx, store: store, map: map, canvas: canvas, options: o)
                }
                .frame(width: canvas.width * z, height: canvas.height * z)
                .contentShape(Rectangle())
                .gesture(dragGesture(canvas: canvas, zoom: z), including: tool == .pan ? .subviews : .all)
            }
            .onAppear { fitZoom = fit }
            .onChange(of: geo.size) { _ in fitZoom = fit }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func dragGesture(canvas: MapCanvas, zoom z: Double) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let p = CGPoint(x: value.startLocation.x / z, y: value.startLocation.y / z)
                if !dragging {
                    dragging = true
                    begin(at: p, canvas: canvas, zoom: z)
                } else if tool == .select, let origin = dragOrigin {
                    let dx = Double(value.translation.width) / z, dy = Double(value.translation.height) / z
                    mutateSelected { $0.move(from: origin, dx: dx.rounded(), dy: dy.rounded()) }
                }
            }
            .onEnded { _ in
                dragging = false
                dragOrigin = nil
            }
    }

    private func begin(at p: CGPoint, canvas: MapCanvas, zoom z: Double) {
        let x = Double(p.x).rounded(), y = Double(p.y).rounded()
        switch tool {
        case .pan:
            break
        case .select:
            selectedID = canvas.hitTest(p, tolerance: 12 / z)
            dragOrigin = canvas.features.first { $0.id == selectedID }
        case .stamp:
            var f = MapFeature(kind: "stamp")
            f.stamp = stamp
            f.x = x
            f.y = y
            f.size = 40
            mutate { $0.features.append(f) }
            selectedID = f.id
        case .label:
            labelPoint = CGPoint(x: x, y: y)
        case .path, .region:
            if let last = draft.last, hypot(last[0] - x, last[1] - y) < 3 { return }
            draft.append([x, y])
        }
    }

    @MainActor
    private func exportPNG(_ map: Entity, _ canvas: MapCanvas) {
        var o = MapRenderOptions()
        o.time = timeOn ? time : nil
        o.journeyID = journeyID
        o.layers = layers
        let view = MapPicture(store: store, map: map, options: o).frame(width: canvas.width, height: canvas.height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        if let data = renderer.uiImage?.pngData() {
            exportDoc = ExportDocument(data: data)
            showExporter = true
        }
    }

    // MARK: Inspector

    @ViewBuilder
    private func inspector(_ map: Entity, _ canvas: MapCanvas) -> some View {
        if !draft.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(tool == .region ? "Drawing a region" : "Drawing a route").font(.headline)
                Text("\(draft.count) point(s). Tap Finish when done.").font(.caption).foregroundColor(.secondary)
            }
        } else if let i = canvas.index(of: selectedID) {
            FeatureInspector(mapID: mapID, map: map, feature: canvas.features[i], time: timeOn ? time : nil,
                             onChange: { change in mutateSelected(change) },
                             onReorder: { front in
                                 mutate { c in
                                     guard let idx = c.index(of: selectedID) else { return }
                                     let f = c.features.remove(at: idx)
                                     if front { c.features.append(f) } else { c.features.insert(f, at: 0) }
                                 }
                             },
                             onDuplicate: {
                                 var copy = canvas.features[i]
                                 copy.id = MapFeature(kind: copy.kind).id
                                 copy.move(from: canvas.features[i], dx: 30, dy: 30)
                                 mutate { $0.features.append(copy) }
                                 selectedID = copy.id
                             },
                             onDelete: {
                                 let id = selectedID
                                 mutate { $0.features.removeAll { $0.id == id } }
                                 selectedID = nil
                             },
                             onDone: { selectedID = nil })
                .id(canvas.features[i].id)
        } else {
            MapOverview(mapID: mapID, map: map, canvas: canvas)
        }
    }
}

/// Small stamp preview for the palette.
struct StampIcon: View {
    let def: MapStamp
    let style: MapStyle

    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width, size.height) / 40
            let t = CGAffineTransform(scaleX: k, y: k)
            func col(_ key: String?) -> Color? {
                guard let key = key, key != "none" else { return nil }
                if key == "fill" { return Color(hex: style.colors[def.color] ?? def.color) }
                return Color(hex: style.colors[key] ?? key)
            }
            for s in def.shapes {
                let path = MapRenderer.shapePath(s).applying(t)
                if let c = col(s.fill), s.t != "line" { ctx.fill(path, with: .color(c.opacity(s.opacity ?? 1))) }
                if let c = col(s.stroke) { ctx.stroke(path, with: .color(c.opacity(s.opacity ?? 1)), lineWidth: (s.sw ?? 1) * k) }
            }
        }
    }
}

/// Inspector for one selected feature.
struct FeatureInspector: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let mapID: String
    let map: Entity
    let feature: MapFeature
    let time: Double?
    let onChange: ((inout MapFeature) -> Void) -> Void
    let onReorder: (Bool) -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onDone: () -> Void

    private let swatches = ["land", "water", "ink", "accent", "paper", "#2F6B3F", "#A23B3B", "#1F3A5F", "#C9A227", "#8E5BD0"]

    var body: some View {
        let f = feature
        let style = store.ref.mapStyle(map.string("mapStyle"))
        let place = store.get("places", f.placeId)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(f.kind == "stamp" ? (store.ref.mapStamps[f.stamp ?? ""]?.label ?? "Stamp") : f.kind.capitalized).font(.headline)
                Spacer()
                Button("Done", action: onDone)
            }
            if f.kind == "label" {
                field("Text") {
                    TextField("Text", text: Binding(get: { f.text ?? "" }, set: { v in onChange { $0.text = v } })).textFieldStyle(.roundedBorder)
                }
            } else {
                field("Label on map") {
                    TextField("Label", text: Binding(get: { f.label ?? "" }, set: { v in onChange { $0.label = v.isEmpty ? nil : v } })).textFieldStyle(.roundedBorder)
                }
            }
            if f.kind == "stamp" {
                field("Stamp") {
                    Picker("Stamp", selection: Binding(get: { f.stamp ?? "pin" }, set: { v in onChange { $0.stamp = v } })) {
                        ForEach(store.ref.mapStamps.keys.sorted(), id: \.self) { k in Text(store.ref.mapStamps[k]?.label ?? k).tag(k) }
                    }
                }
            }

            field("Place") {
                Picker("Place", selection: Binding(get: { f.placeId ?? "" }, set: { v in onChange { $0.placeId = v.isEmpty ? nil : v } })) {
                    Text("— not linked —").tag("")
                    ForEach(store.options("places")) { Text($0.label).tag($0.id) }
                }
                if let p = place {
                    Button("Open place →") { router.push(.entity("places", p.id)) }.font(.callout)
                } else {
                    Button {
                        let made = store.newEntity("places", [
                            "name": .string(f.label ?? f.text ?? "New place"),
                            "kind": placeKind(f).map { JSONValue.string($0) } ?? .null,
                            "parent": map["place"],
                            "existsFrom": map["eraFrom"],
                        ])
                        onChange { $0.placeId = made.id }
                    } label: { Label("New place from this", systemImage: "plus") }.font(.callout)
                }
            }

            let autoMap = place.flatMap { p in store.list("maps").first { $0.string("place") == p.id && $0.id != mapID } }
            field("Zoom into map") {
                Picker("Map", selection: Binding(get: { f.mapId ?? "" }, set: { v in onChange { $0.mapId = v.isEmpty ? nil : v } })) {
                    Text(autoMap.map { "Auto: " + store.title("maps", $0) } ?? "— none —").tag("")
                    ForEach(store.options("maps").filter { $0.id != mapID }) { Text($0.label).tag($0.id) }
                }
                HStack {
                    if let target = store.get("maps", f.mapId) ?? autoMap {
                        Button("Open “\(store.title("maps", target))” →") { router.push(.entity("maps", target.id)) }
                    }
                    Spacer()
                    Button {
                        let scales = store.def("maps")?.fields.first { $0.key == "scale" }?.options ?? []
                        let idx = (scales.firstIndex(of: map.string("scale")) ?? 2) + 1
                        let next = idx < scales.count - 1 ? scales[idx] : "city"
                        let size = store.ref.mapSize(next)
                        let made = store.newEntity("maps", [
                            "title": .string((f.label ?? place?.string("name") ?? "Detail") + " map"),
                            "scale": .string(next),
                            "mapStyle": map["mapStyle"],
                            "place": f.placeId.map { JSONValue.string($0) } ?? .null,
                            "work": map["work"],
                            "eraFrom": map["eraFrom"],
                            "eraTo": map["eraTo"],
                            "canvas": MapCanvas(width: size.0, height: size.1).json,
                        ])
                        onChange { $0.mapId = made.id }
                        router.push(.entity("maps", made.id))
                    } label: { Label("New detail map", systemImage: "plus.magnifyingglass") }
                }
                .font(.callout)
            }

            let inherited = store.window(of: withoutOwnWindow(f))
            field("Exists on this map (in-world order)") {
                HStack {
                    OptionalNumberField(placeholder: inherited.from.map { "from \(Int($0)) (place)" } ?? "from", value: f.from) { v in onChange { $0.from = v } }
                    OptionalNumberField(placeholder: inherited.to.map { "to \(Int($0)) (place)" } ?? "to", value: f.to) { v in onChange { $0.to = v } }
                }
            }

            field("Colour") {
                FlowLayout {
                    ForEach(swatches, id: \.self) { k in
                        Button { onChange { $0.color = k } } label: {
                            Circle().fill(Color(hex: style.colors[k] ?? k)).frame(width: 26, height: 26)
                                .overlay(Circle().stroke(f.color == k ? Color.wowGold : Color.secondary.opacity(0.4), lineWidth: f.color == k ? 3 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if f.kind == "stamp" || f.kind == "label" {
                field("Size") {
                    Slider(value: Binding(get: { f.size ?? (f.kind == "label" ? 22 : 40) }, set: { v in onChange { $0.size = v.rounded() } }),
                           in: f.kind == "label" ? 10...90 : 16...200)
                }
            }
            if f.kind == "path" {
                field("Route style") {
                    Picker("Route style", selection: Binding(get: { f.pathStyle ?? "" }, set: { v in onChange { $0.pathStyle = v.isEmpty ? nil : v } })) {
                        Text("Map default (\(style.pathStyle))").tag("")
                        ForEach(["solid", "dashed", "dotted", "double", "footprints"], id: \.self) { Text($0).tag($0) }
                    }
                }
                field("Width") {
                    Slider(value: Binding(get: { f.width ?? 3 }, set: { v in onChange { $0.width = v.rounded() } }), in: 1...12)
                }
            }
            if f.kind == "region" {
                field("Opacity") {
                    Slider(value: Binding(get: { f.opacity ?? 0.8 }, set: { v in onChange { $0.opacity = (v * 100).rounded() / 100 } }), in: 0.1...1)
                }
            }
            FlowLayout {
                Button("Bring forward") { onReorder(true) }.buttonStyle(.bordered)
                Button("Send back") { onReorder(false) }.buttonStyle(.bordered)
                Button("Duplicate", action: onDuplicate).buttonStyle(.bordered)
                Button("Delete", role: .destructive, action: onDelete).buttonStyle(.bordered)
            }

            if let p = place {
                Divider()
                HereSection(mapID: mapID, map: map, place: p, featureID: f.id, time: time)
            }
        }
    }

    private func withoutOwnWindow(_ f: MapFeature) -> MapFeature {
        var g = f
        g.from = nil
        g.to = nil
        return g
    }

    private func placeKind(_ f: MapFeature) -> String? {
        let byStamp: [String: String] = ["city": "city", "village": "town / village", "temple": "sacred site", "fort": "landmark", "market": "landmark", "mountain": "mountain / range", "volcano": "mountain / range", "forest": "forest / wild", "sacred-tree": "sacred site", "lake": "sea / river / lake", "island": "island / archipelago", "cave": "otherworld location", "spirit": "otherworld location", "tomb": "sacred site"]
        if let s = f.stamp, let k = byStamp[s] { return k }
        if f.kind == "region" { return "region" }
        if f.kind == "path" { return "route / road" }
        return nil
    }

    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.weight(.semibold)).foregroundColor(.secondary)
            content()
        }
    }
}

/// Number box that can be empty.
struct OptionalNumberField: View {
    let placeholder: String
    let onChange: (Double?) -> Void
    @State private var text: String

    init(placeholder: String, value: Double?, onChange: @escaping (Double?) -> Void) {
        self.placeholder = placeholder
        self.onChange = onChange
        _text = State(initialValue: value.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? "")
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numbersAndPunctuation)
            .textFieldStyle(.roundedBorder)
            .onChange(of: text) { v in
                let t = v.trimmingCharacters(in: .whitespaces)
                onChange(t.isEmpty ? nil : Double(t))
            }
    }
}

/// Events and people at a place shown on the map.
struct HereSection: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let mapID: String
    let map: Entity
    let place: Entity
    let featureID: String
    let time: Double?

    var body: some View {
        let canvas = store.mapCanvas(map)
        let events = store.eventsByFeature(canvas, time: time)[featureID] ?? []
        let people = peopleIDs(events)
        VStack(alignment: .leading, spacing: 8) {
            Text(time == nil ? "What happens here" : "What happens here (up to now)").font(.subheadline.weight(.semibold))
            if events.isEmpty { Text("No timeline events here yet.").font(.caption).foregroundColor(.secondary) }
            ForEach(events) { ev in
                Button {
                    router.push(.entity("events", ev.id))
                } label: {
                    Text((ev.number("sequence").map { "#\(Int($0)) " } ?? "") + (ev.string("title").isEmpty ? "Untitled" : ev.string("title")))
                }
                .font(.callout)
            }
            Button {
                let e = store.newEntity("events", ["place": .string(place.id), "sequence": time.map { JSONValue.number($0) } ?? .null])
                router.push(.entity("events", e.id))
            } label: { Label("Event here", systemImage: "plus") }.font(.callout)
            if !people.isEmpty {
                Text("People").font(.subheadline.weight(.semibold))
                FlowLayout {
                    ForEach(people, id: \.self) { id in
                        Button { router.push(.entity("characters", id)) } label: { Chip(text: store.title("characters", store.get("characters", id)), gold: true) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

extension HereSection {
    func peopleIDs(_ events: [Entity]) -> [String] {
        var people = Set(place.strings("characters"))
        for c in store.list("characters") where c.string("homeland") == place.id { people.insert(c.id) }
        for e in events { for id in e.strings("characters") { people.insert(id) } }
        return people.sorted()
    }
}

/// Inspector content when nothing is selected.
struct MapOverview: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let mapID: String
    let map: Entity
    let canvas: MapCanvas

    var body: some View {
        let style = store.ref.mapStyle(map.string("mapStyle"))
        let placeIDs = Array(Set(canvas.features.compactMap { $0.placeId })).sorted()
        let parents = store.list("maps").filter { m in
            m.id != mapID && store.mapCanvas(m).features.contains { $0.mapId == mapID || (!map.string("place").isEmpty && $0.placeId == map.string("place")) }
        }
        VStack(alignment: .leading, spacing: 12) {
            Text("Map designer").font(.headline)
            Text("Pick a tool, then tap the map. Select anything to link it to a place, set when it exists, or zoom into a detail map. Use Scroll to move around a large map.")
                .font(.caption).foregroundColor(.secondary)
            Text(style.name).font(.subheadline.weight(.semibold)) + Text(" — " + style.inspiration).font(.subheadline)
            if let care = style.care { Text(care).font(.caption).foregroundColor(.wowGoldDeep) }
            HStack {
                Text("Canvas \(Int(canvas.width)) × \(Int(canvas.height))").font(.caption)
                Button("Resize to scale") {
                    let size = store.ref.mapSize(map.string("scale"))
                    var c = canvas
                    c.width = size.0
                    c.height = size.1
                    store.saveCanvas(mapID, c)
                }
                .font(.caption)
            }
            Button { router.push(.mapDetails(mapID)) } label: { Label("Title, style, scale & era…", systemImage: "slider.horizontal.3") }
            if !placeIDs.isEmpty {
                Text("Places on this map").font(.subheadline.weight(.semibold))
                FlowLayout {
                    ForEach(placeIDs, id: \.self) { id in
                        Button { router.push(.entity("places", id)) } label: { Chip(text: store.title("places", store.get("places", id)), gold: true) }.buttonStyle(.plain)
                    }
                }
            }
            if !parents.isEmpty {
                Text("Zoom out to").font(.subheadline.weight(.semibold))
                ForEach(parents) { m in
                    Button("↑ " + store.title("maps", m)) { router.push(.entity("maps", m.id)) }.font(.callout)
                }
            }
        }
    }
}
