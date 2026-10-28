import SwiftUI

/// Time Atlas: real and Earth history on one scalable timeline, with a world map of
/// regions showing what was happening where in any chosen year (mirrors web/js/timeatlas.js).
struct TimeCategory: Identifiable, Hashable {
    let id: String
    let label: String
    let color: Color

    static let all: [TimeCategory] = [
        TimeCategory(id: "catastrophes", label: "Catastrophes & Earth", color: Color(hex: "#2F6FB0")),
        TimeCategory(id: "colonialism", label: "Empires & colonialism", color: Color(hex: "#C9A227")),
        TimeCategory(id: "atrocities", label: "Genocides & atrocities", color: Color(hex: "#7A1F2B")),
        TimeCategory(id: "wars", label: "Wars", color: Color(hex: "#D14B3C")),
        TimeCategory(id: "rivalryLore", label: "Rivalries", color: Color(hex: "#8E5BD0")),
        TimeCategory(id: "mythHistory", label: "History & myth", color: Color(hex: "#1E8A6E")),
        TimeCategory(id: "villains", label: "Perpetrators & groups", color: Color(hex: "#3A3A3A")),
        TimeCategory(id: "stewards", label: "Land stewards", color: Color(hex: "#7A5C2E")),
        TimeCategory(id: "mine", label: "Your conflicts & powers", color: Color(hex: "#6C3DB0")),
    ]
    static func named(_ id: String) -> TimeCategory { all.first { $0.id == id } ?? all[0] }
}

struct TimeScale: Identifiable, Hashable {
    let id: String
    let label: String
    let lo: Double
    var log = false

    static let all: [TimeScale] = [
        TimeScale(id: "earth", label: "Earth · 4.5 billion years", lo: -4.6e9, log: true),
        TimeScale(id: "life", label: "Complex life · 540 million years", lo: -5.4e8, log: true),
        TimeScale(id: "human", label: "Humankind · 300,000 years", lo: -3e5, log: true),
        TimeScale(id: "recorded", label: "Recorded history · 5,500 years", lo: -3500),
        TimeScale(id: "modern", label: "Last 500 years", lo: 1500),
        TimeScale(id: "now", label: "1900 – today", lo: 1900),
    ]

    /// Position 0…1 of a year on this scale: linear for recent history, log of "years ago" for deep time.
    func x(_ y: Double) -> Double {
        if !log { return (y - lo) / (currentYear - lo) }
        return 1 - Foundation.log10(max(currentYear - y, 1)) / Foundation.log10(currentYear - lo)
    }
    func year(_ x: Double) -> Double {
        if !log { return lo + x * (currentYear - lo) }
        return currentYear - pow(10, (1 - x) * Foundation.log10(currentYear - lo))
    }
    var ticks: [(Double, String)] {
        if log {
            return [4e9, 1e9, 5e8, 1e8, 1e7, 1e6, 1e5, 3e4, 1e4, 3000, 1000, 300, 100, 30, 10].filter { $0 < currentYear - lo }.map { a in
                (currentYear - a, a >= 1e9 ? "\(Int(a / 1e9)) bn ya" : a >= 1e6 ? "\(Int(a / 1e6)) m ya" : a >= 1e4 ? "\(Int(a / 1e3))k ya" : "\(Int(a)) ya")
            }
        }
        let span = currentYear - lo
        let step = [1.0, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000].first { span / $0 <= 10 } ?? 5000
        var out: [(Double, String)] = []
        var y = (lo / step).rounded(.up) * step
        while y <= currentYear { out.append((y, y < 0 ? "\(Int(-y)) BCE" : "\(Int(y))")); y += step }
        return out
    }
}

struct TimeItem: Identifiable {
    let cat: String
    let id: String
    let name: String
    let start: Double
    let end: Double?
    let ongoing: Bool
    let pools: [String]
    let note: String
    let meta: String
    var entry: LoreEntry? = nil
    var route: Route? = nil

    var span: String {
        if let e = end, e != start { return "\(formatYear(start)) – \(ongoing ? "today" : formatYear(e))" }
        return formatYear(start)
    }
}

extension Store {
    func timeItems() -> [TimeItem] {
        var out: [TimeItem] = []
        for c in TimeCategory.all where c.id != "mine" && c.id != "stewards" {
            for e in loreEntries(c.id) {
                guard let s = e.item.start else { continue }
                out.append(TimeItem(cat: c.id, id: e.item.id, name: e.item.name, start: s, end: e.item.ongoing == true ? currentYear : e.item.end,
                                    ongoing: e.item.ongoing == true, pools: e.pools, note: e.item.note, meta: e.item.meta, entry: e))
            }
        }
        for l in ref.lands {
            for (i, s) in l.stewards.enumerated() {
                out.append(TimeItem(cat: "stewards", id: "\(l.id)#\(i)", name: "\(s.name) · \(l.name.components(separatedBy: " (").first ?? l.name)", start: s.start,
                                    end: s.ongoing == true ? currentYear : s.end, ongoing: s.ongoing == true, pools: l.pools, note: s.note, meta: l.name, route: .land(l.id)))
            }
        }
        for e in list("conflicts") {
            guard let s = e.number("start") else { continue }
            let end = e.number("end") ?? (e.string("status") == "ongoing" ? currentYear : nil)
            out.append(TimeItem(cat: "mine", id: e.id, name: title("conflicts", e), start: s, end: end, ongoing: false, pools: e.strings("cultures"),
                                note: e.string("stakes").isEmpty ? e.string("cause") : e.string("stakes"), meta: e.string("kind"), route: .entity("conflicts", e.id)))
        }
        for f in list("factions") {
            guard let s = f.number("founded") else { continue }
            out.append(TimeItem(cat: "mine", id: f.id, name: title("factions", f), start: s, end: f.number("dissolved") ?? currentYear, ongoing: false,
                                pools: f.strings("cultures"), note: f.string("goals"), meta: f.string("kind"), route: .entity("factions", f.id)))
        }
        return out
    }
}

struct TimeAtlasView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var scale = TimeScale.all[4]
    @State private var year = currentYear
    @State private var cats = Set(TimeCategory.all.map { $0.id }.filter { $0 != "stewards" && $0 != "villains" })
    @State private var region = ""
    @State private var selected = ""
    @State private var query = ""

    /// Regions laid out roughly where they sit on the globe (column, row).
    private let tiles: [(String, Int, Int)] = [
        ("global", 0, 0), ("arctic", 4, 0),
        ("indigenous-americas", 1, 1), ("african-america", 2, 1), ("europe", 5, 1), ("caucasus", 6, 1), ("central-asia", 7, 1), ("himalaya", 8, 1), ("east-asia", 9, 1),
        ("caribbean-diaspora", 2, 2), ("north-africa", 5, 2), ("persia-middle-east", 6, 2), ("south-asia", 7, 2), ("southeast-asia", 8, 2),
        ("latin-america", 1, 3), ("afro-latin", 2, 3), ("west-africa", 4, 3), ("east-africa", 6, 3), ("pacific", 9, 3),
        ("diasporas", 0, 4), ("southern-africa", 5, 4), ("indian-ocean", 7, 4),
    ]

    var body: some View {
        let items = store.timeItems()
        let vis = items.filter { cats.contains($0.cat) && (query.isEmpty || $0.name.lowercased().contains(query.lowercased())) }
        let active = vis.filter(isActive)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(eyebrow: "Research", title: "Time Atlas", subtitle: "Earth's history and humanity's on one scalable timeline: empires and colonial powers past and present, genocides and atrocities, long catastrophes, wars, rivalries and legends. Move through time and the world map shows what was happening where.")
                Text("Care: these are real people's histories, many still unfolding. Where recognition of a genocide is contested, the entry says who recognises it. Dates are approximate, and some regions are far better documented than others — gaps are a prompt to research, not a sign that nothing happened.")
                    .font(.callout).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.wowGold.opacity(0.18)))
                controls
                if let it = items.first(where: { $0.id == selected }) { detail(it) }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { worldMap(active).frame(minWidth: 520); activeList(active).frame(width: 320) }
                    VStack(spacing: 16) { worldMap(active); activeList(active) }
                }
                Card {
                    Text("Timeline").font(.headline)
                    Text("Tap a bar for details, or tap empty space to move the year there.").font(.caption).foregroundColor(.secondary)
                    ScrollView(.horizontal) { timeline(vis) }
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Time Atlas")
        .searchable(text: $query, prompt: "Find an event")
    }

    // MARK: Controls

    private var controls: some View {
        Card {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(TimeScale.all) { s in
                        Button {
                            scale = s
                            year = min(currentYear, max(s.lo, year))
                        } label: { Chip(text: s.label, on: s == scale) }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text("YEAR").font(.caption2.weight(.bold)).foregroundColor(.secondary)
            Text(formatYear(year) + (year >= currentYear ? " · today" : "")).font(.system(.largeTitle, design: .serif).weight(.bold)).foregroundColor(.wowViolet)
            Slider(value: Binding(get: { scale.x(year) }, set: { year = scale.year($0).rounded() }), in: 0...1)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(TimeCategory.all) { c in
                        Button {
                            if cats.contains(c.id) { cats.remove(c.id) } else { cats.insert(c.id) }
                        } label: {
                            Text(c.label).font(.callout).padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Capsule().fill(cats.contains(c.id) ? c.color : Color.clear))
                                .overlay(Capsule().stroke(c.color))
                                .foregroundColor(cats.contains(c.id) ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            let mine = store.timeItems().filter { $0.cat == "mine" }.count
            Text(mine > 0 ? "\(mine) of your conflicts and factions sit on this scale using their own start and end years, read as real years." : "Give your conflicts a start and end, or your factions a founding year, to see them here.")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: Activity at the chosen year

    private func isActive(_ it: TimeItem) -> Bool {
        let point = it.end == nil || it.end == it.start
        let tol = point ? (scale.log ? max(1, (currentYear - year) * 0.03) : (currentYear - scale.lo) * 0.006) : 0
        return year >= it.start - tol && year <= (it.end ?? it.start) + tol
    }

    private func regionName(_ id: String) -> String {
        id == "global" ? "Global / whole Earth" : store.ref.culture(id)?.region ?? id
    }

    private func regions(of it: TimeItem) -> [String] { it.pools.isEmpty ? ["global"] : it.pools }

    private func worldMap(_ active: [TimeItem]) -> some View {
        Card {
            Text("World map at this moment").font(.headline)
            Text("Tap a region to list what was happening there. Colour shows the most common kind of event; dots count each kind.").font(.caption).foregroundColor(.secondary)
            GeometryReader { geo in
                let cell = geo.size.width / 10
                ZStack(alignment: .topLeading) {
                    ForEach(tiles, id: \.0) { tile in
                        let list = active.filter { regions(of: $0).contains(tile.0) }
                        let counts = TimeCategory.all.map { c in (c, list.filter { $0.cat == c.id }.count) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
                        Button { region = region == tile.0 ? "" : tile.0 } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(regionName(tile.0).components(separatedBy: " (").first ?? "")
                                    .font(.system(size: max(cell * 0.11, 7), weight: .semibold)).lineLimit(3).minimumScaleFactor(0.6)
                                    .foregroundColor(!counts.isEmpty && list.count > 2 ? .white : .primary)
                                Spacer(minLength: 0)
                                HStack(spacing: 2) {
                                    ForEach(counts.prefix(4), id: \.0.id) { cn in
                                        Text(cn.1 > 9 ? "9+" : "\(cn.1)").font(.system(size: max(cell * 0.09, 6), weight: .bold)).foregroundColor(.white)
                                            .frame(width: cell * 0.18, height: cell * 0.18).background(Circle().fill(cn.0.color))
                                    }
                                }
                            }
                            .padding(cell * 0.08)
                            .frame(width: cell - 6, height: cell - 6, alignment: .topLeading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(counts.first.map { $0.0.color.opacity(min(0.25 + Double(list.count) * 0.12, 0.9)) } ?? Color.wowVioletSoft.opacity(0.12)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(region == tile.0 ? Color.wowGold : Color.wowVioletSoft.opacity(0.3), lineWidth: region == tile.0 ? 3 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(regionName(tile.0)): \(list.count) active")
                        .offset(x: CGFloat(tile.1) * cell + 3, y: CGFloat(tile.2) * cell + 3)
                    }
                }
            }
            .aspectRatio(2, contentMode: .fit)
        }
    }

    private func activeList(_ active: [TimeItem]) -> some View {
        let list = region.isEmpty ? active : active.filter { regions(of: $0).contains(region) }
        return Card {
            HStack {
                Text(region.isEmpty ? "The world in \(formatYear(year))" : "\(regionName(region)) in \(formatYear(year))").font(.headline)
                if !region.isEmpty { Spacer(); Button("All regions") { region = "" }.font(.caption) }
            }
            if list.isEmpty {
                Text("Nothing recorded here at this moment in the reference library — a gap to research, or room for your own story.").font(.callout).foregroundColor(.secondary)
            }
            ForEach(TimeCategory.all) { c in
                let xs = list.filter { $0.cat == c.id }
                if !xs.isEmpty {
                    Text(c.label.uppercased()).font(.caption2.weight(.bold)).foregroundColor(c.color).padding(.top, 4)
                    ForEach(xs.prefix(25)) { x in
                        Button { selected = x.id } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(x.name).font(.callout)
                                Text(x.span).font(.caption2).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    if xs.count > 25 { Text("+\(xs.count - 25) more").font(.caption2).foregroundColor(.secondary) }
                }
            }
        }
    }

    // MARK: Timeline

    private struct Bar: Identifiable {
        let item: TimeItem
        let x: CGFloat
        let y: CGFloat
        let w: CGFloat
        let inside: Bool
        var label = true
        var h: CGFloat = 14
        var id: String { item.id }
    }

    private func layout(_ vis: [TimeItem], width W: CGFloat) -> (bars: [Bar], heads: [(TimeCategory, CGFloat, Int)], lands: [(String, CGFloat)], height: CGFloat) {
        var bars: [Bar] = []
        var landRows: [(String, CGFloat)] = []
        var heads: [(TimeCategory, CGFloat, Int)] = []
        var y: CGFloat = 26
        let row: CGFloat = 18
        for c in TimeCategory.all where cats.contains(c.id) {
            let xs = vis.filter { $0.cat == c.id && ($0.end ?? $0.start) >= scale.lo }.sorted { $0.start < $1.start }
            heads.append((c, y, xs.count))
            y += 20
            if c.id == "stewards" {
                // One row per land; stewards that overlap in time share the row in two halves.
                var lands: [String] = []
                for it in xs where !lands.contains(it.meta) { lands.append(it.meta) }
                for land in lands {
                    var ends: [CGFloat] = [-.infinity, -.infinity]
                    for it in xs where it.meta == land {
                        let x1 = max(0, CGFloat(scale.x(it.start)) * W)
                        let x2 = min(W, CGFloat(scale.x(it.end ?? it.start)) * W)
                        let half = ends[0] <= x1 + 1 ? 0 : ends[1] <= x1 + 1 ? 1 : (ends[0] <= ends[1] ? 0 : 1)
                        ends[half] = x2
                        bars.append(Bar(item: it, x: x1, y: y + CGFloat(half) * 9, w: max(4, x2 - x1), inside: false, label: false, h: 8))
                    }
                    landRows.append((land.components(separatedBy: " (").first ?? land, y))
                    y += 22
                }
                y += 8
                continue
            }
            var rows: [CGFloat] = []
            for it in xs {
                let x1 = max(0, CGFloat(scale.x(it.start)) * W)
                let x2 = min(W, CGFloat(scale.x(it.end ?? it.start)) * W)
                let bw = max(4, x2 - x1)
                let labelW = CGFloat(it.name.count) * 6.4 + 8
                let inside = bw > labelW
                let end = inside ? x1 + bw : x1 + bw + labelW
                // Prefer a row with room for the name; when rows run out, fit the bar alone.
                var showLabel = true
                var r = rows.firstIndex { $0 + 4 < x1 } ?? -1
                if r < 0 && rows.count < 60 { rows.append(0); r = rows.count - 1 }
                if r < 0 { showLabel = inside; r = rows.firstIndex { $0 + 2 < x1 } ?? -1 }
                if r < 0 { continue }
                rows[r] = showLabel ? end : x1 + bw
                bars.append(Bar(item: it, x: x1, y: y + CGFloat(r) * row, w: bw, inside: inside, label: showLabel))
            }
            y += CGFloat(max(1, rows.count)) * row + 8
        }
        return (bars, heads, landRows, y + 10)
    }

    private func timeline(_ vis: [TimeItem]) -> some View {
        let W: CGFloat = 1000
        let l = layout(vis, width: W)
        return ZStack(alignment: .topLeading) {
            Color.clear.contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { p in year = scale.year(min(1, max(0, Double(p.x / W)))).rounded() }
            ForEach(scale.ticks, id: \.0) { t in
                let x = CGFloat(scale.x(t.0)) * W
                Rectangle().fill(Color.secondary.opacity(0.2)).frame(width: 1, height: l.height - 16).offset(x: x, y: 16)
                Text(t.1).font(.caption2).foregroundColor(.secondary).offset(x: x + 3, y: 0)
            }
            ForEach(l.heads, id: \.0.id) { head in
                Text("\(head.0.label) (\(head.2))").font(.caption.weight(.bold)).foregroundColor(head.0.color).offset(x: 4, y: head.1)
            }
            ForEach(l.bars) { b in
                let color = TimeCategory.named(b.item.cat).color
                Button { selected = b.item.id } label: {
                    HStack(spacing: 4) {
                        Text(b.inside && b.label ? b.item.name : "").font(.system(size: 11)).foregroundColor(.white).lineLimit(1)
                            .padding(.leading, b.label ? 4 : 0)
                            .frame(width: b.w, height: b.h, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 3).fill(color.opacity(b.item.id == selected ? 1 : 0.75)))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(b.item.id == selected ? Color.wowGold : .clear, lineWidth: 2))
                        if !b.inside && b.label { Text(b.item.name).font(.system(size: 11)).foregroundColor(.primary).lineLimit(1).fixedSize() }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(b.item.name), \(b.item.span)")
                .offset(x: b.x, y: b.y)
            }
            ForEach(l.lands, id: \.1) { land in
                Text(land.0).font(.system(size: 10)).padding(.horizontal, 2).background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.85))
                    .offset(x: 4, y: land.1 + 6).allowsHitTesting(false)
            }
            Rectangle().fill(Color.wowGold).frame(width: 3, height: l.height).offset(x: CGFloat(scale.x(year)) * W - 1.5)
                .allowsHitTesting(false)
        }
        .frame(width: W, height: l.height, alignment: .topLeading)
    }

    // MARK: Detail

    private func detail(_ it: TimeItem) -> some View {
        let c = TimeCategory.named(it.cat)
        let care = LoreSource.all.first { $0.id == it.cat }?.care ?? ""
        return Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.label.uppercased()).font(.caption2.weight(.bold)).foregroundColor(c.color)
                    Text(it.name).font(.system(.title2, design: .serif).weight(.bold))
                }
                Spacer()
                Button("Close") { selected = "" }
            }
            Text(it.span + (it.meta.isEmpty ? "" : " · " + it.meta)).font(.callout.weight(.semibold))
            if !it.note.isEmpty { Text(it.note) }
            if !care.isEmpty { Text("Care: " + care).font(.caption).foregroundColor(.red.opacity(0.8)) }
            if !it.pools.isEmpty {
                FlowLayout {
                    ForEach(it.pools, id: \.self) { p in
                        Button { router.push(.culture(p)) } label: { Chip(text: regionName(p)) }.buttonStyle(.plain)
                    }
                }
            }
            FlowLayout(spacing: 8) {
                Button("Jump to its start") { year = it.start }.buttonStyle(.bordered)
                if let r = it.route { Button(it.cat == "stewards" ? "See the land's stewards" : "Open") { router.push(r) }.buttonStyle(.borderedProminent) }
                if let e = it.entry {
                    ForEach(store.loreStarts(it.cat, e), id: \.label) { s in
                        Button {
                            let made = store.newEntity(s.col, s.fields)
                            router.push(.entity(s.col, made.id))
                        } label: { Label(s.label, systemImage: "plus") }
                        .buttonStyle(.bordered)
                    }
                    Button { store.loreToResearch(it.cat, e) } label: { Label("Research", systemImage: "bookmark") }.buttonStyle(.bordered)
                }
            }
        }
        .overlay(alignment: .leading) { Rectangle().fill(c.color).frame(width: 5) }
    }
}
