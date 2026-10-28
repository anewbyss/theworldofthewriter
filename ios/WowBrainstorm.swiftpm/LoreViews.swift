import SwiftUI

/// One of the lore lists, and which fields of your entries link to it.
struct LoreSource: Identifiable, Hashable {
    let id: String
    let label: String
    let short: String
    let icon: String
    let blurb: String
    let uses: [[String]]
    var care: String = ""

    static let all: [LoreSource] = [
        LoreSource(id: "animals", label: "Real animals", short: "Animals", icon: "pawprint", blurb: "Real animals and the lore people tell about them.", uses: [["species", "realAnimals"], ["pets", "realAnimals"]]),
        LoreSource(id: "creatures", label: "Mythic & fictional beings", short: "Beings", icon: "flame", blurb: "Beings from myth and folklore by region, plus public-domain fiction and kinds of being to invent from.", uses: [["species", "mythicRoots"], ["pets", "mythicRoots"]]),
        LoreSource(id: "wars", label: "Wars", short: "Wars", icon: "shield", blurb: "Sacred and mythic wars alongside real wars from every continent.", uses: [["conflicts", "basedOn"], ["events", "mythTies"]]),
        LoreSource(id: "rivalryLore", label: "Rivalries", short: "Rivalries", icon: "bolt.horizontal", blurb: "Mythic, historical, artistic and scholarly rivalries.", uses: [["rivalries", "basedOn"]]),
        LoreSource(id: "mythHistory", label: "History & myth", short: "History & myth", icon: "building.columns", blurb: "Places and people where history and legend meet.", uses: [["events", "mythTies"], ["places", "historyTies"], ["characters", "historyTies"]]),
        LoreSource(id: "colonialism", label: "Empires & colonialism", short: "Empires", icon: "crown", blurb: "Empires and colonial powers from Akkad to today, settler colonialism, and territories still disputed or administered from afar.", uses: [["factions", "basedOn"], ["conflicts", "basedOn"], ["places", "historyTies"]],
                   care: "Tell colonial history from the side of the colonised as well as the coloniser. Many of these stories are still being lived."),
        LoreSource(id: "atrocities", label: "Genocides & atrocities", short: "Atrocities", icon: "flame.circle", blurb: "Genocides, mass atrocities and enslavement, past and present, with who recognises them.", uses: [["conflicts", "basedOn"], ["events", "mythTies"], ["places", "historyTies"]],
                   care: "Real people suffered and survivors and descendants are alive. Read survivor testimony and scholarship, centre the people harmed rather than the perpetrators, and never use atrocity as spectacle or as a plot twist. Where recognition is contested, the note says so."),
        LoreSource(id: "catastrophes", label: "Catastrophes", short: "Catastrophes", icon: "tornado", blurb: "Long-term catastrophes across Earth's and humanity's history: extinctions, ice ages, plagues, famines, eruptions and climate change.", uses: [["conflicts", "basedOn"], ["events", "mythTies"], ["places", "historyTies"]]),
        LoreSource(id: "villains", label: "Perpetrators & groups", short: "Perpetrators", icon: "exclamationmark.triangle", blurb: "Real-world tyrants, perpetrators, regimes, militias, extremist groups, companies and cartels, past and present — as the documented record describes them.", uses: [["characters", "historyTies"], ["factions", "basedOn"]],
                   care: "These are real people and groups, and their victims are real. Use them to understand how power, ideology and complicity work — never to glamorise. For living people, stick to the documented record (convictions, indictments, official findings), as these entries do, and say when a finding is disputed."),
        LoreSource(id: "modern", label: "Modern cultures", short: "Modern", icon: "globe", blurb: "Every sovereign state, plus territories, stateless nations and Indigenous nations, and contemporary scenes and subcultures.", uses: [["characters", "modernCultures"], ["cultures", "modernCultures"], ["places", "historyTies"]],
                   care: "A country isn't a culture: most hold many peoples. Use the Culture Atlas and Peoples index to go deeper."),
    ]
    static func named(_ id: String) -> LoreSource { all.first { $0.id == id } ?? all[0] }
}

struct LoreEntry: Identifiable, Hashable {
    let group: LoreGroup
    let item: LoreItem
    var id: String { item.id }
    var pools: [String] { if let p = item.pools, !p.isEmpty { return p }; return group.pool.isEmpty ? [] : [group.pool] }
}

let currentYear = Double(Calendar.current.component(.year, from: Date()))

/// "66 million years ago", "1274 BCE", "1914" — readable at any scale (mirrors web/js/lore.js).
func formatYear(_ y: Double?) -> String {
    guard let y = y else { return "" }
    let ago = currentYear - y
    func trim(_ v: Double, _ digits: Int) -> String {
        let s = String(format: "%.\(digits)f", v)
        return s.contains(".") ? String(s.reversed().drop { $0 == "0" }.drop { $0 == "." }.reversed()) : s
    }
    if ago >= 1e9 { return "\(trim(ago / 1e9, 2)) billion years ago" }
    if ago >= 1e6 { return "\(trim(ago / 1e6, 1)) million years ago" }
    if ago >= 20000 { return "\(Int((ago / 1000).rounded())),000 years ago" }
    return y < 0 ? "\(Int(-y.rounded())) BCE" : "\(Int(y.rounded()))"
}

func yearSpan(_ it: LoreItem) -> String {
    guard let s = it.start else { return "" }
    if it.ongoing == true { return "\(formatYear(s)) – today" }
    if let e = it.end, e != s { return "\(formatYear(s)) – \(formatYear(e))" }
    return formatYear(s)
}

extension Store {
    func loreEntries(_ source: String) -> [LoreEntry] {
        ref.lore(source).flatMap { g in g.items.map { LoreEntry(group: g, item: $0) } }
    }

    /// Your entries that draw on a lore item.
    func loreUsedBy(_ source: String, _ id: String) -> [(col: String, entity: Entity)] {
        LoreSource.named(source).uses.flatMap { use in
            list(use[0]).filter { $0.strings(use[1]).contains(id) }.map { (col: use[0], entity: $0) }
        }
    }

    /// Ways to turn a lore item into one of your own entries (mirrors web/js/lore.js).
    func loreStarts(_ source: String, _ e: LoreEntry) -> [(col: String, label: String, fields: [String: JSONValue])] {
        let it = e.item
        let pool = e.pools
        let start: JSONValue = it.start.map { .number($0) } ?? .string("")
        let end: JSONValue = it.ongoing == true ? .string("") : (it.end ?? it.start).map { .number($0) } ?? .string("")
        let echo = [it.name, it.meta.isEmpty ? "" : "(\(it.meta))", it.note].filter { !$0.isEmpty }.joined(separator: " ")
        let care = "Read the tradition this comes from, credit it, and make your version your own."
        switch source {
        case "animals":
            return [("species", "Species", ["name": .string(it.name), "kind": .string("animal"), "sapience": .string("animal"), "realAnimals": .strings([it.id]), "roots": .string(echo)]),
                    ("pets", "Companion", ["name": .string(it.name), "realAnimals": .strings([it.id]), "status": .string("alive"), "kind": .string("pet"), "origin": .string(echo)])]
        case "creatures":
            return [("species", "Species", ["name": .string(it.name), "mythicRoots": .strings([it.id]), "cultures": .strings(pool), "roots": .string("\(e.group.name): \(echo)"), "care": .string(pool.isEmpty ? "" : care)]),
                    ("pets", "Companion", ["name": .string(it.name), "mythicRoots": .strings([it.id]), "status": .string("alive"), "kind": .string("familiar"), "origin": .string("\(e.group.name): \(echo)")])]
        case "wars":
            let mythic = e.group.pool.isEmpty && e.group.id.hasPrefix("mythic")
            return [("conflicts", "War", ["name": .string(it.name), "kind": .string("war"), "status": .string(mythic ? "remembered / mythic" : "ended"), "basedOn": .strings([it.id]), "era": .string(it.meta), "start": start, "end": end, "cultures": .strings(pool), "parallels": .string("Echoes \(echo)")])]
        case "colonialism":
            let dissolved: JSONValue = it.ongoing == true ? .string("") : it.end.map { .number($0) } ?? .string("")
            return [("factions", "Empire / power", ["name": .string(it.name), "kind": .string("empire / kingdom"), "status": .string(it.ongoing == true ? "dominant" : "dissolved"), "basedOn": .strings([it.id]), "cultures": .strings(pool), "founded": start, "dissolved": dissolved, "history": .string(echo)]),
                    ("conflicts", "Colonial conflict", ["name": .string("Resistance to \(it.name)"), "kind": .string("occupation"), "status": .string(it.ongoing == true ? "ongoing" : "ended"), "basedOn": .strings([it.id]), "start": start, "end": end, "cultures": .strings(pool), "parallels": .string("Echoes \(echo)")])]
        case "atrocities":
            return [("events", "To my timeline", ["title": .string(it.name), "mythTies": .strings([it.id]), "when": .string(yearSpan(it)), "description": .string(echo)]),
                    ("conflicts", "Conflict (with care)", ["name": .string(it.name), "kind": .string("atrocity (handle with care)"), "status": .string(it.ongoing == true ? "ongoing" : "remembered / mythic"), "basedOn": .strings([it.id]), "start": start, "end": end, "cultures": .strings(pool), "memory": .string(echo)])]
        case "catastrophes":
            return [("events", "To my timeline", ["title": .string(it.name), "mythTies": .strings([it.id]), "when": .string(yearSpan(it)), "description": .string(echo)]),
                    ("places", "Place it marked", ["name": .string(it.name), "historyTies": .strings([it.id]), "cultures": .strings(pool), "history": .string(echo)])]
        case "villains":
            if e.group.id.contains("regimes") || e.group.id.contains("companies") {
                return [("factions", "Faction it echoes", ["name": .string(""), "kind": .string("army / warrior order"), "status": .string(it.ongoing == true ? "dominant" : "dissolved"), "basedOn": .strings([it.id]), "cultures": .strings(pool), "history": .string("Draws on \(echo)")])]
            }
            return [("characters", "Antagonist it echoes", ["role": .string("antagonist"), "historyTies": .strings([it.id]), "cultures": .strings(pool), "inspiration": .string("Draws on \(echo)")]),
                    ("factions", "Their regime", ["name": .string(""), "kind": .string("empire / kingdom"), "basedOn": .strings([it.id]), "cultures": .strings(pool), "history": .string("Draws on \(echo)")])]
        case "modern":
            return [("cultures", "People", ["name": .string(it.name), "kind": .string("real people (portrayed respectfully)"), "modernCultures": .strings([it.id]), "cultures": .strings(pool)]),
                    ("characters", "Character from here", ["modernCultures": .strings([it.id]), "cultures": .strings(pool)])]
        case "rivalryLore":
            return [("rivalries", "Rivalry", ["name": .string(it.name), "basedOn": .strings([it.id]), "origin": .string("Echoes \(echo)")])]
        case "mythHistory":
            return [("events", "To my timeline", ["title": .string(it.name), "mythTies": .strings([it.id]), "when": .string(it.meta), "description": .string(echo)])]
        default:
            return []
        }
    }

    func loreToResearch(_ source: String, _ e: LoreEntry) {
        create("research", ["title": .string(e.item.name), "kind": .string("other"), "cultures": .strings(e.pools), "source": .string([yearSpan(e.item), e.item.meta].filter { !$0.isEmpty }.joined(separator: " · ")), "notes": .string(e.item.note), "care": .string(LoreSource.named(source).care), "tags": .strings([LoreSource.named(source).label.lowercased()])])
    }

    /// The same pick for everyone on a given day, so the inspiration feels like "today's".
    func daily<T>(_ items: [T], salt: Int) -> T? {
        guard !items.isEmpty else { return nil }
        let day = Int(Date().timeIntervalSince1970 / 86400)
        return items[(day * 7919 + salt * 104729) % items.count]
    }

    var libraryStats: [(Int, String)] {
        [(loreEntries("animals").count, "real animals"), (loreEntries("creatures").count, "mythic beings"),
         (ref.culturePools.reduce(0) { $0 + ($1.peopleList?.count ?? 0) }, "peoples"), (ref.religions.count, "faiths"),
         (ref.narrativeStyles.count, "story shapes"), (loreEntries("wars").count + loreEntries("rivalryLore").count, "wars & rivalries")]
    }
}

// MARK: - Lore library

struct LoreLibraryView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State var source: String
    @State private var query = ""
    @State private var group = ""

    var body: some View {
        let s = LoreSource.named(source)
        let groups = store.ref.lore(source).filter { group.isEmpty || $0.id == group }
        let q = query.lowercased()
        List {
            Section {
                Picker("List", selection: $source) {
                    ForEach(LoreSource.all) { Label($0.label, systemImage: $0.icon).tag($0.id) }
                }
                .pickerStyle(.menu)
                Text("\(store.loreEntries(source).count) entries. \(s.blurb)").font(.callout).foregroundColor(.secondary)
                Text("A starting index, never a complete one. Many of these beings and events belong to living peoples. Start from them to learn, then build something your own and credit what inspired it.")
                    .font(.caption).foregroundColor(.wowGoldDeep)
                if !s.care.isEmpty { Text("Care: " + s.care).font(.caption).foregroundColor(.red.opacity(0.8)) }
                Picker("Group", selection: $group) {
                    Text("All groups").tag("")
                    ForEach(store.ref.lore(source)) { Text("\($0.name) (\($0.items.count))").tag($0.id) }
                }
            }
            ForEach(groups) { g in
                let items = g.items.filter { q.isEmpty || "\($0.name) \($0.meta) \($0.note)".lowercased().contains(q) }
                if !items.isEmpty {
                    Section(g.name) {
                        ForEach(items) { it in row(LoreEntry(group: g, item: it)) }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Filter \(s.label.lowercased())")
        .navigationTitle(s.label)
        .onChange(of: source) { _ in group = "" }
    }

    private func row(_ e: LoreEntry) -> some View {
        let used = store.loreUsedBy(source, e.item.id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(e.item.name).font(.headline)
                if !used.isEmpty { Image(systemName: "checkmark.seal.fill").foregroundColor(.wowGold) }
            }
            if e.item.start != nil { Text(yearSpan(e.item)).font(.caption.weight(.semibold)).foregroundColor(.wowGoldDeep) }
            if !e.item.meta.isEmpty { Text(e.item.meta).font(.caption).foregroundColor(.secondary) }
            if !e.item.note.isEmpty { Text(e.item.note).font(.callout) }
            ForEach(used, id: \.entity.id) { u in
                Button { router.push(.entity(u.col, u.entity.id)) } label: {
                    Label(store.title(u.col, u.entity), systemImage: "arrow.turn.down.right").font(.caption)
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 8) {
                ForEach(store.loreStarts(source, e), id: \.label) { start in
                    Button {
                        let made = store.newEntity(start.col, start.fields)
                        router.push(.entity(start.col, made.id))
                    } label: { Label(start.label, systemImage: "plus") }
                    .buttonStyle(.bordered)
                }
                Button { store.loreToResearch(source, e) } label: { Image(systemName: "bookmark") }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Send to Research Pool")
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Ways to begin & daily inspiration

enum Door: CaseIterable, Identifiable {
    case character, map, myth, history, style, atlas, animal, spark
    var id: Self { self }

    var info: (icon: String, title: String, subtitle: String) {
        switch self {
        case .character: return ("person.crop.square", "Meet a character", "Portrait, powers, people, family.")
        case .map: return ("map", "Draw a world", "Maps from village to cosmos.")
        case .myth: return ("flame", "Start from a myth", "Beings from every region's folklore.")
        case .history: return ("building.columns", "Start from history", "Wars, rivalries, legends made real.")
        case .style: return ("scroll", "Choose a story shape", "Kishōtenketsu, griot epic, blues form…")
        case .atlas: return ("globe.europe.africa", "Wander the atlas", "21 regions of peoples and ideas.")
        case .animal: return ("pawprint", "Find a creature", "Real animals and their lore.")
        case .spark: return ("dice", "Roll a spark", "Dice tables for when the page is blank.")
        }
    }
}

extension Store {
    /// Where a door leads: a sidebar page, and optionally a new entry to open there.
    func destination(of door: Door) -> (SidebarItem, Route?) {
        switch door {
        case .character:
            let e = newEntity("characters")
            return (.collection("characters"), .entity("characters", e.id))
        case .map:
            let e = newEntity("maps")
            return (.collection("maps"), .entity("maps", e.id))
        case .myth: return (.lore("creatures"), nil)
        case .history: return (.lore("wars"), nil)
        case .style: return (.styles, nil)
        case .atlas: return (.atlas, nil)
        case .animal: return (.lore("animals"), nil)
        case .spark: return (.spark, nil)
        }
    }
}

struct DoorsGrid: View {
    var onDark = false
    let go: (Door) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
            ForEach(Door.allCases) { d in
                Button { go(d) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: d.info.icon).font(.title2).foregroundColor(onDark ? .wowGold : .wowViolet)
                        Text(d.info.title).font(.headline).foregroundColor(onDark ? .white : .primary)
                        Text(d.info.subtitle).font(.caption).foregroundColor(onDark ? .white.opacity(0.75) : .secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(onDark ? Color.wowGold.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(onDark ? Color.wowGold.opacity(0.4) : Color.wowVioletSoft.opacity(0.25)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct InspirationRow: View {
    @EnvironmentObject var store: Store
    var onDark = false
    let go: (SidebarItem, Route?) -> Void

    var body: some View {
        let day = Int(Date().timeIntervalSince1970 / 86400)
        let clashSource = day % 2 == 1 ? "wars" : "rivalryLore"
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
            if let c = store.daily(store.loreEntries("creatures").filter { !$0.group.pool.isEmpty }, salt: 1) {
                card("Being of the day · \(c.group.name)", c.item.name, c.item.note) { go(.lore("creatures"), nil) }
            }
            if let p = store.daily(store.loreEntries("mythHistory"), salt: 2) {
                card("Where myth meets history", p.item.name, [p.item.meta, p.item.note].filter { !$0.isEmpty }.joined(separator: " — ")) { go(.lore("mythHistory"), nil) }
            }
            if let s = store.daily(store.ref.narrativeStyles, salt: 3) {
                card("Story shape · \(s.region)", s.name, s.summary) { go(.styles, .style(s.id)) }
            }
            if let w = store.daily(store.loreEntries(clashSource), salt: clashSource == "wars" ? 4 : 5) {
                card(clashSource == "wars" ? "A war remembered" : "A famous rivalry", w.item.name, [w.item.meta, w.item.note].filter { !$0.isEmpty }.joined(separator: " — ")) { go(.lore(clashSource), nil) }
            }
        }
    }

    private func card(_ eyebrow: String, _ title: String, _ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased()).font(.caption2.weight(.bold)).foregroundColor(onDark ? .wowGold : .wowGoldDeep).lineLimit(2)
                Text(title).font(.system(.headline, design: .serif)).foregroundColor(onDark ? .white : .primary)
                Text(text).font(.caption).foregroundColor(onDark ? .white.opacity(0.75) : .secondary).lineLimit(4)
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(onDark ? Color.white.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(onDark ? Color.white.opacity(0.15) : Color.wowVioletSoft.opacity(0.25)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Opening screen

struct OpeningView: View {
    @EnvironmentObject var store: Store
    @AppStorage("showOpening") private var showOpening = true
    @State private var spark = ""
    /// Close the screen, optionally going to a page (and an entry on it).
    let finish: (SidebarItem?, Route?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 16) {
                    Text("W").font(.system(size: 40, weight: .bold, design: .serif)).foregroundColor(.wowGold)
                        .frame(width: 68, height: 68)
                        .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.wowVioletBright, .wowVioletSoft], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.wowGold, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WOW Brainstorm").font(.system(size: 44, weight: .bold, design: .serif)).foregroundColor(.wowGold).minimumScaleFactor(0.6).lineLimit(1)
                        Text("The world of the writer · every culture, every myth, every thread").font(.callout).foregroundColor(.white.opacity(0.75))
                    }
                }
                Text("Build worlds from the whole of human story, then keep every book, show and song in continuity. Nothing here writes for you. Your words, your world.")
                    .font(.system(.title3, design: .serif)).foregroundColor(.white)

                if store.hasData { continueCard }

                section("Today's inspiration") { InspirationRow(onDark: true) { finish($0, $1) } }

                section("Spark") {
                    Text(spark).font(.system(.title3, design: .serif)).foregroundColor(.white)
                    HStack {
                        Button { rollSpark() } label: { Label("Roll again", systemImage: "dice") }
                        Button {
                            let n = store.create("notes", ["title": .string("Spark"), "text": .string(spark), "tags": .strings(["spark"])])
                            finish(.collection("notes"), .entity("notes", n.id))
                        } label: { Label("Write from this", systemImage: "pencil") }
                    }
                    .buttonStyle(.bordered).tint(.wowGold)
                }

                section(store.hasData ? "Or begin something new" : "Ways to begin") {
                    DoorsGrid(onDark: true) { d in
                        let (item, route) = store.destination(of: d)
                        finish(item, route)
                    }
                }

                FlowLayout(spacing: 18) {
                    ForEach(store.libraryStats, id: \.1) { stat in
                        Text("\(stat.0) ").font(.headline).foregroundColor(.wowGold) + Text(stat.1).foregroundColor(.white.opacity(0.8))
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Button { finish(nil, nil) } label: {
                        Text("Enter WOW Brainstorm").font(.headline).padding(.horizontal, 22).padding(.vertical, 12)
                            .background(Capsule().fill(Color.wowGold)).foregroundColor(.wowVioletDeep)
                    }
                    .buttonStyle(.plain)
                    Toggle("Show this screen when I open the app", isOn: $showOpening).foregroundColor(.white).tint(.wowGold).frame(maxWidth: 420)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 40)
            .frame(maxWidth: 1040)
            .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(colors: [.wowVioletDeep, .wowViolet, .wowVioletBright], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(RadialGradient(colors: [Color.wowGold.opacity(0.18), .clear], center: .topLeading, startRadius: 0, endRadius: 500))
                .ignoresSafeArea()
        )
        .onAppear { if spark.isEmpty { rollSpark() } }
    }

    private func rollSpark() { spark = store.ref.sparkTables["storySpark"]?.randomElement() ?? "" }

    private var continueCard: some View {
        let counts = store.counts().filter { $0.value > 0 && $0.key != "links" && $0.key != "labels" }.sorted { $0.value > $1.value }.prefix(4)
        let summary = counts.map { c -> String in
            let d = store.def(c.key)
            return "\(c.value) \((c.value == 1 ? d?.singular : d?.label)?.lowercased() ?? c.key)"
        }.joined(separator: " · ")
        let recent = store.recent(1).first
        return VStack(alignment: .leading, spacing: 8) {
            Text("YOUR WORLD SO FAR").font(.caption.weight(.bold)).foregroundColor(.wowGold)
            Text(summary).foregroundColor(.white)
            if let r = recent {
                Text("Last touched: \(store.title(r.col, r.entity))").font(.caption).foregroundColor(.white.opacity(0.75))
                Button { finish(.collection(r.col), .entity(r.col, r.entity.id)) } label: { Text("Pick up where you left off").bold() }
                    .buttonStyle(.borderedProminent).tint(.wowGold).foregroundColor(.wowVioletDeep)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.wowGold.opacity(0.45)))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.caption.weight(.bold)).foregroundColor(.wowGold).tracking(1.2)
            content()
        }
    }
}
