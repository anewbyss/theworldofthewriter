import SwiftUI

// MARK: - Timeline & continuity

struct ContinuityView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var workFilter = ""
    @State private var characterFilter = ""

    var body: some View {
        let issues = Continuity.check(store)
        let events = Continuity.orderedEvents(store).filter {
            (workFilter.isEmpty || $0.string("work") == workFilter) &&
            (characterFilter.isEmpty || $0.strings("characters").contains(characterFilter))
        }
        List {
            Section("Continuity check · \(issues.count) note\(issues.count == 1 ? "" : "s")") {
                if issues.isEmpty { Text("No continuity problems found.").foregroundColor(.secondary) }
                ForEach(issues) { issue in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(issue.message, systemImage: icon(issue.level))
                            .foregroundColor(issue.level == .bad ? .red : .primary)
                        HStack {
                            ForEach(Array(issue.refs.enumerated()), id: \.offset) { _, r in
                                Button(store.title(r.col, store.get(r.col, r.id))) { router.push(.entity(r.col, r.id)) }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                            }
                        }
                    }
                    .listRowBackground(issue.level == .bad ? Color.red.opacity(0.08) : issue.level == .warn ? Color.wowGold.opacity(0.12) : Color.clear)
                }
            }
            Section("Filters") {
                Picker("Work", selection: $workFilter) {
                    Text("All works").tag("")
                    ForEach(store.options("works")) { Text($0.label).tag($0.id) }
                }
                Picker("Character", selection: $characterFilter) {
                    Text("All characters").tag("")
                    ForEach(store.options("characters")) { Text($0.label).tag($0.id) }
                }
            }
            Section("Timeline") {
                if events.isEmpty {
                    Text("No events yet. Add births, deaths, meetings, reveals and battles to track continuity.").foregroundColor(.secondary)
                }
                ForEach(events) { ev in
                    NavigationLink(value: Route.entity("events", ev.id)) {
                        HStack(alignment: .top, spacing: 12) {
                            Circle().fill(Color.wowGold).frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.wowViolet, lineWidth: 2))
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(ev.string("title").isEmpty ? "Untitled" : ev.string("title")).font(.headline)
                                    Spacer()
                                    Chip(text: ev.string("type").isEmpty ? "event" : ev.string("type"), gold: ev.string("type") != "death")
                                }
                                let meta = metaLine(ev)
                                if !meta.isEmpty { Text(meta).font(.caption).foregroundColor(.secondary) }
                                let people = ev.strings("characters").compactMap { store.get("characters", $0) }.map { store.title("characters", $0) }
                                if !people.isEmpty { Text(people.joined(separator: ", ")).font(.callout) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Timeline & Continuity")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let e = store.newEntity("events")
                    router.push(.entity("events", e.id))
                } label: { Label("New event", systemImage: "plus") }
            }
        }
    }

    private func metaLine(_ ev: Entity) -> String {
        var parts: [String] = []
        if let n = ev.number("sequence") {
            parts.append("#" + (n == n.rounded() ? String(Int(n)) : String(n)))
        }
        parts.append(ev.string("when"))
        if let w = store.get("works", ev.string("work")) { parts.append(store.title("works", w)) }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func icon(_ level: ContinuityIssue.Level) -> String {
        switch level {
        case .bad: return "exclamationmark.octagon"
        case .warn: return "exclamationmark.triangle"
        case .info: return "info.circle"
        }
    }
}

// MARK: - Connection web

struct GraphView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var showImplicit = true
    @State private var seed = 0

    struct Node: Identifiable {
        let id: String
        let col: String
        let entityID: String
        let label: String
        var x: Double
        var y: Double
        var vx: Double = 0
        var vy: Double = 0
    }
    struct Edge {
        let a: Int
        let b: Int
        let explicit: Bool
        let label: String
    }

    static let colors: [String: Color] = [
        "characters": Color(hex: "#6C3DB0"), "abilities": Color(hex: "#E1AD01"), "origins": Color(hex: "#1E6F5C"),
        "works": Color(hex: "#A23B3B"), "storylines": Color(hex: "#1F3A5F"), "events": Color(hex: "#8C5A2B"),
        "research": Color(hex: "#38B2AC"), "notes": Color.gray, "places": Color(hex: "#D35400"), "maps": Color(hex: "#2A1640"), "powerSystems": Color(hex: "#B7791F"), "lineages": Color(hex: "#805AD5"), "cultures": Color(hex: "#2C7A7B"), "religions": Color(hex: "#C05621"), "languages": Color(hex: "#2B6CB0"),
    ]

    private func layout() -> ([Node], [Edge]) {
        let W = 900.0, H = 640.0
        var nodes: [Node] = []
        var index: [String: Int] = [:]
        var edges: [Edge] = []
        var rng = SystemRandomNumberGenerator()
        func node(_ col: String, _ id: String) -> Int? {
            let key = "\(col):\(id)"
            if let i = index[key] { return i }
            guard let e = store.get(col, id) else { return nil }
            nodes.append(Node(id: key, col: col, entityID: id, label: store.title(col, e),
                              x: Double.random(in: 50...(W - 50), using: &rng), y: Double.random(in: 50...(H - 50), using: &rng)))
            index[key] = nodes.count - 1
            return nodes.count - 1
        }
        for l in store.list("links") {
            if let f = splitRef(l.string("from")), let t = splitRef(l.string("to")), let a = node(f.0, f.1), let b = node(t.0, t.1) {
                edges.append(Edge(a: a, b: b, explicit: true, label: l.string("label")))
            }
        }
        if showImplicit {
            for c in store.ref.collections where c.id != "links" {
                for e in store.list(c.id) {
                    for f in c.fields {
                        guard let target = f.collection else { continue }
                        let ids: [String] = f.type == "ref" ? [e.string(f.key)] : f.type == "refs" ? e.strings(f.key) : []
                        for t in ids where !t.isEmpty {
                            if let a = node(c.id, e.id), let b = node(target, t) {
                                edges.append(Edge(a: a, b: b, explicit: false, label: ""))
                            }
                        }
                    }
                }
            }
        }
        if showImplicit {
            for m in store.list("maps") {
                for f in store.mapCanvas(m).features {
                    if let p = f.placeId, let a = node("maps", m.id), let b = node("places", p) {
                        edges.append(Edge(a: a, b: b, explicit: false, label: ""))
                    }
                    if let d = f.mapId, let a = node("maps", m.id), let b = node("maps", d) {
                        edges.append(Edge(a: a, b: b, explicit: false, label: ""))
                    }
                }
            }
        }
        // Simple force layout: repulsion + springs + centring.
        for _ in 0..<300 {
            for i in nodes.indices {
                for j in nodes.indices where j > i {
                    var dx = nodes[i].x - nodes[j].x, dy = nodes[i].y - nodes[j].y
                    let d2 = dx * dx + dy * dy + 0.01
                    let f = 1800 / d2
                    let d = d2.squareRoot()
                    dx /= d; dy /= d
                    nodes[i].vx += dx * f; nodes[i].vy += dy * f
                    nodes[j].vx -= dx * f; nodes[j].vy -= dy * f
                }
            }
            for e in edges {
                let dx = nodes[e.b].x - nodes[e.a].x, dy = nodes[e.b].y - nodes[e.a].y
                let d = max((dx * dx + dy * dy).squareRoot(), 1)
                let f = (d - 110) * 0.05
                nodes[e.a].vx += dx / d * f; nodes[e.a].vy += dy / d * f
                nodes[e.b].vx -= dx / d * f; nodes[e.b].vy -= dy / d * f
            }
            for i in nodes.indices {
                nodes[i].vx += (W / 2 - nodes[i].x) * 0.002
                nodes[i].vy += (H / 2 - nodes[i].y) * 0.002
                nodes[i].x += max(-20, min(20, nodes[i].vx))
                nodes[i].y += max(-20, min(20, nodes[i].vy))
                nodes[i].vx *= 0.6; nodes[i].vy *= 0.6
                nodes[i].x = max(30, min(W - 30, nodes[i].x))
                nodes[i].y = max(20, min(H - 20, nodes[i].y))
            }
        }
        return (nodes, edges)
    }

    var body: some View {
        let _ = seed
        let graph = layout()
        let nodes = graph.0
        let edges = graph.1
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle("Show reference links", isOn: $showImplicit).fixedSize()
                Spacer()
                Button { seed += 1 } label: { Label("Re-arrange", systemImage: "arrow.triangle.2.circlepath") }
            }
            ScrollView(.horizontal) {
                HStack {
                    ForEach(Array(GraphView.colors.keys.sorted()), id: \.self) { k in
                        HStack(spacing: 4) {
                            Circle().fill(GraphView.colors[k] ?? .gray).frame(width: 10, height: 10)
                            Text(store.def(k)?.label ?? k).font(.caption)
                        }
                    }
                }
            }
            if nodes.isEmpty {
                Text("Nothing connected yet. Link characters to abilities, works and each other.").foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    let sx = geo.size.width / 900
                    let sy = geo.size.height / 640
                    ZStack(alignment: .topLeading) {
                        Canvas { ctx, _ in
                            for e in edges {
                                var p = Path()
                                p.move(to: CGPoint(x: nodes[e.a].x * sx, y: nodes[e.a].y * sy))
                                p.addLine(to: CGPoint(x: nodes[e.b].x * sx, y: nodes[e.b].y * sy))
                                ctx.stroke(p, with: .color(e.explicit ? Color.wowGold : Color.secondary.opacity(0.35)), lineWidth: e.explicit ? 2.5 : 1)
                                if e.explicit && !e.label.isEmpty {
                                    let mid = CGPoint(x: (nodes[e.a].x + nodes[e.b].x) / 2 * sx, y: (nodes[e.a].y + nodes[e.b].y) / 2 * sy - 8)
                                    ctx.draw(Text(e.label).font(.caption2).foregroundColor(.secondary), at: mid)
                                }
                            }
                        }
                        ForEach(nodes) { n in
                            Button { router.push(.entity(n.col, n.entityID)) } label: {
                                HStack(spacing: 4) {
                                    Circle().fill(GraphView.colors[n.col] ?? .gray)
                                        .frame(width: n.col == "characters" ? 20 : 15, height: n.col == "characters" ? 20 : 15)
                                    Text(n.label).font(.caption).foregroundColor(.primary).lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            .position(x: n.x * sx + 40, y: n.y * sy)
                        }
                    }
                }
                .frame(minHeight: 500)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemGroupedBackground)))
            }
        }
        .padding()
        .navigationTitle("Connection Web")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let e = store.newEntity("links", ["label": .string("connected to")])
                    router.push(.entity("links", e.id))
                } label: { Label("New connection", systemImage: "plus") }
            }
        }
    }
}

// MARK: - Originality

struct OriginalityView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var text = ""
    @State private var result: OriginalityResult?
    @State private var scan: [(col: String, entity: Entity, result: OriginalityResult)] = []

    var body: some View {
        List {
            Section {
                Text("Transparent word-overlap scoring against ~80 well-known tropes and everything in your library. It shows exactly what matched so you decide.")
                    .font(.callout).foregroundColor(.secondary)
                TextField("Paste or write an ability, character concept or storyline…", text: $text, axis: .vertical)
                    .lineLimit(5...20)
                Button("Check text") {
                    result = Originality.check(text, others: store.otherEntries(excluding: nil), ref: store.ref)
                }
                .buttonStyle(.borderedProminent).tint(.wowGold).foregroundColor(.wowVioletDeep)
            }
            if let r = result {
                Section("Result") { OriginalityResultView(result: r) }
            }
            Section {
                Button("Scan my whole library") {
                    var rows: [(col: String, entity: Entity, result: OriginalityResult)] = []
                    for col in Store.checkableCollections {
                        for e in store.list(col) {
                            if let r = store.checkOriginality(col, e.id) { rows.append((col, e, r)) }
                        }
                    }
                    scan = rows.sorted { ($0.result.score ?? 101) < ($1.result.score ?? 101) }
                }
                ForEach(scan, id: \.entity.id) { row in
                    Button { router.push(.entity(row.col, row.entity.id)) } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(store.title(row.col, row.entity))
                                Text([row.result.tropeMatches.first?.trope.name, row.result.ownMatches.first?.label].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundColor(.secondary)
                                if !row.result.representation.isEmpty {
                                    Text("Representation check: " + row.result.representation.map { $0.trope.name }.joined(separator: ", "))
                                        .font(.caption).foregroundColor(.red)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(row.result.score.map { String($0) } ?? "—").font(.title3.weight(.bold))
                                Text(row.result.label).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: { Text("Library scan") }
        }
        .navigationTitle("Originality")
    }
}
