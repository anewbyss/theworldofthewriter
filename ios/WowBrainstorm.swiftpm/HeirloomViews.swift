import SwiftUI

// MARK: - Effects on characters and places

extension Store {
    /// Curses or blessings touching a character: directly, through a lineage, or through gear they hold.
    func effects(_ col: String, onCharacter c: Entity) -> [(entry: Entity, via: String)] {
        var out: [(entry: Entity, via: String)] = []
        for x in list(col) {
            if x.strings("characters").contains(c.id) {
                out.append((x, "directly"))
            } else if let l = x.strings("lineages").first(where: { c.strings("lineages").contains($0) }) {
                out.append((x, "through lineage " + title("lineages", get("lineages", l))))
            } else if let g = list("gear").first(where: { $0.string("owner") == c.id && x.strings("gear").contains($0.id) }) {
                out.append((x, "through " + title("gear", g)))
            }
        }
        return out
    }

    /// Curses or blessings on a place, directly or on a place that contains it.
    func effects(_ col: String, onPlace p: Entity) -> [(entry: Entity, via: String)] {
        var out: [(entry: Entity, via: String)] = []
        for x in list(col) {
            if x.strings("places").contains(p.id) {
                out.append((x, "directly"))
                continue
            }
            var id = p.string("parent")
            var depth = 0
            while !id.isEmpty && depth < 25 {
                if x.strings("places").contains(id) {
                    out.append((x, "within " + title("places", get("places", id))))
                    break
                }
                id = get("places", id)?.string("parent") ?? ""
                depth += 1
            }
        }
        return out
    }

    func addRef(_ col: String, _ id: String, _ key: String, _ value: String) {
        guard let x = get(col, id) else { return }
        var ids = x.strings(key)
        if !ids.contains(value) { ids.append(value) }
        update(col, id, key, .strings(ids))
    }
}

/// Menu to pick an existing entry or create a new one.
struct EntryPickerMenu: View {
    @EnvironmentObject var store: Store
    let col: String
    let title: String
    var filter: (Entity) -> Bool = { _ in true }
    let onPick: (Entity) -> Void

    var body: some View {
        Menu {
            ForEach(store.list(col).filter(filter)) { x in
                Button(store.title(col, x)) { onPick(x) }
            }
            Divider()
            Button { onPick(store.newEntity(col)) } label: { Label("New \(store.def(col)?.singular.lowercased() ?? "entry")", systemImage: "plus") }
        } label: { Label(title, systemImage: "plus.circle") }
    }
}

private struct EffectRows: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let col: String
    let rows: [(entry: Entity, via: String)]

    var body: some View {
        if rows.isEmpty { Text("None.").foregroundColor(.secondary) }
        ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
            Button { router.push(.entity(col, r.entry.id)) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.title(col, r.entry))
                    let status = r.entry.string("status")
                    Text(r.via + (status.isEmpty || status == "active" ? "" : " · " + status)).font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
}

struct InventoryPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let characterID: String

    var body: some View {
        if let c = store.get("characters", characterID) {
            let gear = store.list("gear").filter { $0.string("owner") == c.id }
            Text("Carrying").font(.subheadline.weight(.semibold))
            if gear.isEmpty { Text("Nothing yet.").foregroundColor(.secondary) }
            ForEach(gear) { g in
                Button(store.title("gear", g) + (g.string("rarity").isEmpty ? "" : " · " + g.string("rarity"))) { router.push(.entity("gear", g.id)) }
            }
            EntryPickerMenu(col: "gear", title: "Give gear", filter: { $0.string("owner") != c.id }) { g in
                store.update("gear", g.id, "owner", .string(c.id))
            }
            Text("Curses").font(.subheadline.weight(.semibold))
            EffectRows(col: "curses", rows: store.effects("curses", onCharacter: c))
            EntryPickerMenu(col: "curses", title: "Lay a curse") { x in store.addRef("curses", x.id, "characters", c.id) }
            Text("Blessings").font(.subheadline.weight(.semibold))
            EffectRows(col: "blessings", rows: store.effects("blessings", onCharacter: c))
            EntryPickerMenu(col: "blessings", title: "Bestow a blessing") { x in store.addRef("blessings", x.id, "characters", c.id) }
        }
    }
}

struct PlaceInventoryPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let placeID: String

    var body: some View {
        if let p = store.get("places", placeID) {
            let gear = store.list("gear").filter { $0.string("location") == p.id }
            Text("Gear kept here").font(.subheadline.weight(.semibold))
            if gear.isEmpty { Text("Nothing.").foregroundColor(.secondary) }
            ForEach(gear) { g in Button(store.title("gear", g)) { router.push(.entity("gear", g.id)) } }
            EntryPickerMenu(col: "gear", title: "Store gear here") { g in store.update("gear", g.id, "location", .string(p.id)) }
            Text("Curses").font(.subheadline.weight(.semibold))
            EffectRows(col: "curses", rows: store.effects("curses", onPlace: p))
            EntryPickerMenu(col: "curses", title: "Curse this place") { x in store.addRef("curses", x.id, "places", p.id) }
            Text("Blessings").font(.subheadline.weight(.semibold))
            EffectRows(col: "blessings", rows: store.effects("blessings", onPlace: p))
            EntryPickerMenu(col: "blessings", title: "Bless this place") { x in store.addRef("blessings", x.id, "places", p.id) }
        }
    }
}

struct GearPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let gearID: String

    var body: some View {
        if let g = store.get("gear", gearID) {
            let trail = Continuity.orderedEvents(store).filter { $0.string("item") == g.id }
            if let o = store.get("characters", g.string("owner")) {
                Button("Held by " + store.title("characters", o)) { router.push(.entity("characters", o.id)) }
            } else {
                Text("Not held by anyone").foregroundColor(.secondary)
            }
            if let l = store.get("places", g.string("location")) {
                Button("Kept at " + store.title("places", l)) { router.push(.entity("places", l.id)) }
            }
            let curses = store.list("curses").filter { $0.strings("gear").contains(g.id) }
            let blessings = store.list("blessings").filter { $0.strings("gear").contains(g.id) }
            ForEach(curses) { x in Button("Cursed: " + store.title("curses", x)) { router.push(.entity("curses", x.id)) } }
            ForEach(blessings) { x in Button("Blessed: " + store.title("blessings", x)) { router.push(.entity("blessings", x.id)) } }
            Text("Chain of custody").font(.subheadline.weight(.semibold))
            if trail.isEmpty {
                Text("Add timeline events of type “gains item” / “loses item” with this gear to trace who held it when.").font(.caption).foregroundColor(.secondary)
            }
            ForEach(trail) { ev in
                Button { router.push(.entity("events", ev.id)) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.title("events", ev))
                        Text(([ev.string("type")] + ev.strings("characters").map { store.title("characters", store.get("characters", $0)) }).filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Button {
                let ev = store.newEntity("events", ["type": .string("gains item"), "item": .string(g.id)])
                router.push(.entity("events", ev.id))
            } label: { Label("Custody event", systemImage: "plus") }
        }
    }
}

struct EffectPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let col: String
    let entryID: String

    var body: some View {
        if let x = store.get(col, entryID) {
            let direct = x.strings("characters").filter { store.get("characters", $0) != nil }
            let viaLineage = store.list("characters").filter { c in !direct.contains(c.id) && x.strings("lineages").contains { c.strings("lineages").contains($0) } }
            let viaGear = store.list("gear").filter { x.strings("gear").contains($0.id) && !$0.string("owner").isEmpty }
            let key = col == "curses" ? "curse" : "blessing"
            let events = Continuity.orderedEvents(store).filter { $0.string(key) == x.id }
            if !direct.isEmpty {
                Text("Directly").font(.subheadline.weight(.semibold))
                ForEach(direct, id: \.self) { id in Button(store.title("characters", store.get("characters", id))) { router.push(.entity("characters", id)) } }
            }
            if !viaLineage.isEmpty {
                Text("Through their lineage").font(.subheadline.weight(.semibold))
                ForEach(viaLineage) { c in Button(store.title("characters", c)) { router.push(.entity("characters", c.id)) } }
            }
            if !viaGear.isEmpty {
                Text("Through gear they hold").font(.subheadline.weight(.semibold))
                ForEach(viaGear) { g in
                    Button("\(store.title("characters", store.get("characters", g.string("owner")))) · \(store.title("gear", g))") { router.push(.entity("characters", g.string("owner"))) }
                }
            }
            if direct.isEmpty && viaLineage.isEmpty && viaGear.isEmpty && x.strings("places").isEmpty {
                Text("Not on anyone or anything yet.").foregroundColor(.secondary)
            }
            Text("On the timeline").font(.subheadline.weight(.semibold))
            ForEach(events) { ev in Button("\(store.title("events", ev)) · \(ev.string("type"))") { router.push(.entity("events", ev.id)) } }
            Button {
                let ev = store.newEntity("events", ["type": .string(col == "curses" ? "cursed" : "blessed"), key: .string(x.id)])
                router.push(.entity("events", ev.id))
            } label: { Label("Event", systemImage: "plus") }
        }
    }
}

// MARK: - Paradoxes

struct ParadoxPanel: View {
    @EnvironmentObject var store: Store
    let paradoxID: String

    var body: some View {
        let covered = Continuity.check(store).filter { $0.paradoxID == paradoxID }
        if covered.isEmpty {
            Text("No continuity notes yet. Mark them from Timeline & Continuity, or set “What it covers” to include every note involving its linked entries.")
                .foregroundColor(.secondary)
        }
        ForEach(covered) { Text($0.message).font(.callout) }
        Text("Paradoxes never break anything — they just move matching notes out of the warnings list.").font(.caption).foregroundColor(.secondary)
    }
}

struct IssueKeysEditor: View {
    @EnvironmentObject var store: Store
    let keys: [String]
    let onChange: ([String]) -> Void

    var body: some View {
        let all = Dictionary(Continuity.check(store).map { ($0.key, $0.message) }, uniquingKeysWith: { a, _ in a })
        if keys.isEmpty { Text("Mark notes from Timeline & Continuity.").foregroundColor(.secondary) }
        ForEach(keys, id: \.self) { k in
            HStack {
                Text(all[k] ?? "(no longer happening) \(k)").font(.callout)
                Spacer()
                Button { onChange(keys.filter { $0 != k }) } label: { Image(systemName: "minus.circle.fill").foregroundColor(.red) }
                    .buttonStyle(.borderless)
            }
        }
    }
}

/// Menu that marks a continuity note as an intentional paradox.
struct MarkParadoxMenu: View {
    @EnvironmentObject var store: Store
    let issue: ContinuityIssue

    var body: some View {
        Menu {
            ForEach(store.list("paradoxes")) { p in Button(store.title("paradoxes", p)) { mark(p.id) } }
            Divider()
            Button { mark(store.newEntity("paradoxes", ["name": .string("New paradox")]).id) } label: { Label("New paradox", systemImage: "plus") }
        } label: { Label("Intentional paradox", systemImage: "infinity") }
        .font(.caption)
    }

    private func mark(_ id: String) {
        guard let p = store.get("paradoxes", id) else { return }
        func add(_ key: String, _ values: [String]) {
            var ids = p.strings(key)
            for v in values where !ids.contains(v) { ids.append(v) }
            store.update("paradoxes", id, key, .strings(ids))
        }
        add("issueKeys", [issue.key])
        for col in ["characters", "events", "places", "abilities"] { add(col, issue.refs.filter { $0.col == col }.map { $0.id }) }
        if p.string("status").isEmpty { store.update("paradoxes", id, "status", .string("intentional")) }
        if p.string("scope").isEmpty { store.update("paradoxes", id, "scope", .string("only the notes I mark")) }
    }
}

// MARK: - Genome editor

struct GenomeEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    var col = "characters"
    let characterID: String

    var body: some View {
        if let c = store.get(col, characterID) {
            let traits = store.traitsFor([c])
            let genome = c["genome"].object ?? [:]
            if traits.isEmpty {
                Text("No heredity traits yet — add some under Heredity Traits.").foregroundColor(.secondary)
            }
            ForEach(traits) { t in
                if t.string("mode") == "polygenic (number)" {
                    HStack {
                        Text(store.title("traits", t))
                        Spacer()
                        OptionalNumberField(placeholder: "\(fmt(t.number("min") ?? 0))–\(fmt(t.number("max") ?? 100)) \(t.string("unit"))", value: genome[t.id]?.number) { v in
                            set(t.id, v.map { JSONValue.number($0) } ?? .null)
                        }
                        .frame(maxWidth: 160)
                    }
                } else {
                    Picker(store.title("traits", t), selection: Binding(get: { genome[t.id]?.string ?? "" }, set: { set(t.id, $0.isEmpty ? .null : .string($0)) })) {
                        Text("—").tag("")
                        ForEach(Heredity.options(t, chromosomes: c.string("heredityChromosomes")), id: \.value) { o in Text(o.label).tag(o.value) }
                    }
                }
            }
            Button { router.push(.offspring(c.id)) } label: { Label("Offspring calculator with this character", systemImage: "figure.and.child.holdinghands") }
        }
    }

    private func set(_ traitID: String, _ value: JSONValue) {
        var g = store.value(col, characterID, "genome").object ?? [:]
        g[traitID] = value
        store.update(col, characterID, "genome", .object(g))
    }
}

// MARK: - Trait templates

struct TraitTemplatesSection: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    var body: some View {
        DisclosureGroup("Start from a template") {
            Text("Simple, fictional rules to build on. Real human traits such as skin or eye colour come from many genes — no single trait defines a people, and race is not a genetic category.")
                .font(.caption).foregroundColor(.secondary)
            ForEach(Array(store.ref.traitTemplates.enumerated()), id: \.offset) { _, t in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t["name"]?.string ?? "Trait").font(.headline)
                        Text(t["mode"]?.string ?? "").font(.caption).foregroundColor(.secondary)
                        Text(t["description"]?.string ?? "").font(.caption)
                    }
                    Spacer()
                    Button("Add") {
                        let e = store.newEntity("traits", t)
                        router.push(.entity("traits", e.id))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

// MARK: - Offspring calculator

struct OffspringCalculatorView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State var parentA: String
    @State private var parentB = ""
    @State private var lineParent: [String: Int] = [:]
    @State private var count = 3
    @State private var rolls: [RolledChild] = []
    @State private var excludedLineages: Set<String> = []
    @State private var kind = "characters"

    struct RolledChild: Identifiable {
        let id = UUID()
        let chromosomes: String
        let results: [(trait: Entity, value: JSONValue, manifests: Bool, label: String)]
    }

    init(parentA: String = "") {
        _parentA = State(initialValue: parentA)
        _kind = State(initialValue: "characters")
        pendingKindCheck = !parentA.isEmpty
    }
    private var pendingKindCheck = false

    var body: some View {
        List {
            Section {
                Text("Simplified, fictional rules — not real human genetics. Real traits like skin and eye colour come from many genes, and race is not a genetic category.")
                    .font(.caption).foregroundColor(.secondary)
                Picker("Breeding", selection: $kind) {
                    Text("Characters").tag("characters")
                    Text("Companions").tag("pets")
                }
                .pickerStyle(.segmented)
                Picker("Parent 1", selection: $parentA) {
                    Text("—").tag("")
                    ForEach(store.options(kind)) { Text($0.label).tag($0.id) }
                }
                Picker("Parent 2", selection: $parentB) {
                    Text("—").tag("")
                    ForEach(store.options(kind)) { Text($0.label).tag($0.id) }
                }
            }
            if let a = store.get(kind, parentA), let b = store.get(kind, parentB) {
                content(a, b)
            } else {
                Text("Choose two parents.").foregroundColor(.secondary)
            }
        }
        .navigationTitle("Offspring Calculator")
        .onAppear {
            if pendingKindCheck && store.get("pets", parentA) != nil { kind = "pets" }
        }
        .onChange(of: kind) { _ in
            if store.get(kind, parentA) == nil { parentA = "" }
            if store.get(kind, parentB) == nil { parentB = "" }
            rolls = []
        }
        .onChange(of: parentA) { _ in rolls = [] }
        .onChange(of: parentB) { _ in rolls = [] }
    }

    private func pct(_ p: Double) -> String { "\(fmt((p * 1000).rounded() / 10))%" }

    @ViewBuilder
    private func content(_ a: Entity, _ b: Entity) -> some View {
        let traits = store.traitsFor([a, b])
        let gA = a["genome"].object ?? [:], gB = b["genome"].object ?? [:]
        let chromA = a.string("heredityChromosomes"), chromB = b.string("heredityChromosomes")
        if let note = relation(a.id, b.id) {
            Section { Label(note, systemImage: "infinity").font(.callout) }
        }
        if !store.compatible(a, b) {
            Section { Label("By your species rules these two can't normally have children together — a miracle, magic or paradox? The odds below still run.", systemImage: "exclamationmark.triangle").font(.callout) }
        }
        if traits.isEmpty {
            Section { Text("No heredity traits yet. Create or add template traits, then set each parent's genome on their character page.").foregroundColor(.secondary) }
        }
        ForEach(traits) { t in
            let r = Heredity.predict(t, gA[t.id], gB[t.id], chromA, chromB, lineParent: lineParent[t.id] ?? 1)
            Section(store.title("traits", t) + " · " + t.string("mode")) {
                Text("\(store.title(kind, a)): \(gA[t.id]?.string ?? "unset") · \(store.title(kind, b)): \(gB[t.id]?.string ?? "unset")")
                    .font(.caption).foregroundColor(.secondary)
                if t.string("mode") == "one parent line" {
                    Picker("Line passes through", selection: Binding(get: { lineParent[t.id] ?? 1 }, set: { lineParent[t.id] = $0 })) {
                        Text(store.title(kind, a)).tag(1)
                        Text(store.title(kind, b)).tag(2)
                    }
                }
                switch r.kind {
                case .number:
                    Text("Expected about \(fmt((r.mean * 10).rounded() / 10)) \(r.unit) — 80% of children between \(fmt((r.low * 10).rounded() / 10)) and \(fmt((r.high * 10).rounded() / 10)) \(r.unit)")
                case .unavailable:
                    Text(r.note).foregroundColor(.secondary)
                default:
                    ForEach(Array(r.outcomes.enumerated()), id: \.offset) { _, o in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack { Text(o.label); Spacer(); Text(pct(o.p)).bold() }
                            ProgressView(value: max(0, min(1, o.p))).tint(.wowGold)
                        }
                    }
                    if r.kind == .mendel {
                        Text("Genotypes: TT \(pct(r.genotypes["TT"] ?? 0)) · To \(pct(r.genotypes["To"] ?? 0)) · oo \(pct(r.genotypes["oo"] ?? 0))").font(.caption).foregroundColor(.secondary)
                    }
                    if r.kind == .x {
                        Text("XX children — TT \(pct(r.daughters["TT"] ?? 0)), To \(pct(r.daughters["To"] ?? 0)) (carriers); XY children — \(pct(r.sons["T"] ?? 0)) carry it").font(.caption).foregroundColor(.secondary)
                    }
                }
                if let ab = store.get("abilities", t.string("ability")), r.manifest > 0 {
                    Text("Manifesting grants \(store.title("abilities", ab))").font(.caption)
                }
            }
        }
        let lineages = kind == "pets" ? [] : Array(Set(a.strings("lineages") + b.strings("lineages"))).compactMap { store.get("lineages", $0) }
        if kind == "characters" {
        Section("Lineages the child may join") {
            if lineages.isEmpty { Text("Neither parent belongs to a lineage.").foregroundColor(.secondary) }
            ForEach(lineages) { l in
                Toggle(isOn: Binding(get: { !excludedLineages.contains(l.id) }, set: { on in if on { excludedLineages.remove(l.id) } else { excludedLineages.insert(l.id) } })) {
                    Text(store.title("lineages", l) + (l.string("inheritance").isEmpty ? "" : " · " + l.string("inheritance")))
                }
            }
        }
        let lineageIDs = Set(lineages.map { $0.id })
        let generational = (store.list("curses") + store.list("blessings")).filter { x in x.strings("lineages").contains { lineageIDs.contains($0) } }
        if !generational.isEmpty {
            Section("Generational curses & blessings") {
                ForEach(generational) { x in Text(store.title(store.list("curses").contains { $0.id == x.id } ? "curses" : "blessings", x)) }
            }
        }
        Section("Cultural inheritance (by upbringing, not genes)") {
            let items = culturalItems(a, b)
            Text(items.isEmpty ? "None set." : items.joined(separator: " · ")).font(.callout)
        }
        }
        Section("Roll children") {
            Stepper("Children: \(count)", value: $count, in: 1...12)
            Button { roll(a, b, traits) } label: { Label("Roll", systemImage: "dice") }
                .buttonStyle(.borderedProminent).tint(.wowGold).foregroundColor(.wowVioletDeep)
            ForEach(Array(rolls.enumerated()), id: \.element.id) { i, k in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Child \(i + 1)" + (k.chromosomes.isEmpty ? "" : " · \(k.chromosomes)")).font(.headline)
                        Spacer()
                        Button("Create") { create(a, b, k, lineages) }.buttonStyle(.bordered)
                    }
                    ForEach(Array(k.results.enumerated()), id: \.offset) { _, r in
                        HStack {
                            Text(store.title("traits", r.trait)).font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text(r.label).font(.caption).fontWeight(r.manifests ? .bold : .regular)
                        }
                    }
                }
            }
        }
    }

    private func culturalItems(_ a: Entity, _ b: Entity) -> [String] {
        var out: [String] = []
        for (key, col) in [("peoples", "cultures"), ("religions", "religions"), ("languages", "languages")] {
            for id in Array(Set(a.strings(key) + b.strings(key))).sorted() { out.append(store.title(col, store.get(col, id))) }
        }
        return out
    }

    private func roll(_ a: Entity, _ b: Entity, _ traits: [Entity]) {
        let gA = a["genome"].object ?? [:], gB = b["genome"].object ?? [:]
        let chromA = a.string("heredityChromosomes"), chromB = b.string("heredityChromosomes")
        let xx = (chromA == "XX" && chromB == "XY") || (chromA == "XY" && chromB == "XX")
        rolls = (0..<count).map { _ in
            let childChrom = xx ? (Bool.random() ? "XX" : "XY") : ""
            let results = traits.map { t -> (trait: Entity, value: JSONValue, manifests: Bool, label: String) in
                let s = Heredity.sample(t, gA[t.id], gB[t.id], chromA, chromB, childChrom: childChrom, lineParent: lineParent[t.id] ?? 1)
                return (t, s.value, s.manifests, s.label)
            }
            return RolledChild(chromosomes: childChrom, results: results)
        }
    }

    private func create(_ a: Entity, _ b: Entity, _ k: RolledChild, _ lineages: [Entity]) {
        var genome: [String: JSONValue] = [:]
        for r in k.results { genome[r.trait.id] = r.value }
        let abilities = Array(Set(k.results.filter { $0.manifests && !$0.trait.string("ability").isEmpty }.map { $0.trait.string("ability") }))
        if kind == "pets" {
            let breed = a.string("breed") == b.string("breed") ? a.string("breed") : [a.string("breed"), b.string("breed")].filter { !$0.isEmpty }.joined(separator: " × ")
            let species = a.string("species").isEmpty ? b.string("species") : a.string("species")
            let pet = store.newEntity("pets", [
                "name": .string(""), "parents": .strings([a.id, b.id]), "genome": .object(genome),
                "heredityChromosomes": k.chromosomes.isEmpty ? .null : .string(k.chromosomes), "abilities": .strings(abilities),
                "species": species.isEmpty ? .null : .string(species), "breed": .string(breed), "kind": a["kind"], "status": .string("alive"), "tags": .strings(["offspring"]),
            ])
            router.push(.entity("pets", pet.id))
            return
        }
        let pa = PortraitParams(a["portrait"], spec: store.ref.portrait), pb = PortraitParams(b["portrait"], spec: store.ref.portrait)
        var portrait = PortraitParams.random(spec: store.ref.portrait)
        portrait.skin = max(0, min(store.ref.portrait.skinTones.count - 1, Int((Double(pa.skin + pb.skin) / 2).rounded()) + [-1, 0, 0, 1].randomElement()!))
        portrait.hairColor = Bool.random() ? pa.hairColor : pb.hairColor
        portrait.hair = Bool.random() ? pa.hair : pb.hair
        let e = store.newEntity("characters", [
            "name": .string(""),
            "parents": .strings([a.id, b.id]),
            "species": .strings(Array(Set(store.speciesOf(a) + store.speciesOf(b)))),
            "genome": .object(genome),
            "heredityChromosomes": k.chromosomes.isEmpty ? .null : .string(k.chromosomes),
            "abilities": .strings(abilities),
            "lineages": .strings(lineages.map { $0.id }.filter { !excludedLineages.contains($0) }),
            "peoples": .strings(Array(Set(a.strings("peoples") + b.strings("peoples")))),
            "portrait": portrait.json,
            "tags": .strings(["offspring"]),
        ])
        router.push(.entity("characters", e.id))
    }

    private func relation(_ a: String, _ b: String) -> String? {
        if a == b { return "These are the same person — a bootstrap paradox is allowed, but the maths treats them as two copies." }
        func ancestors(_ id: String) -> Set<String> {
            var out = Set<String>()
            var stack = store.get(kind, id)?.strings("parents") ?? []
            while let x = stack.popLast() {
                if out.contains(x) { continue }
                out.insert(x)
                stack.append(contentsOf: store.get(kind, x)?.strings("parents") ?? [])
            }
            return out
        }
        let ancA = ancestors(a), ancB = ancestors(b)
        if ancA.contains(b) || ancB.contains(a) { return "One parent is an ancestor of the other (perhaps through time travel). The calculator still runs." }
        if !ancA.isDisjoint(with: ancB) { return "These parents share an ancestor." }
        return nil
    }
}
