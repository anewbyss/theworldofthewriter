import SwiftUI

// MARK: - Narrative styles

struct StylesView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let regions = store.ref.narrativeStyles.reduce(into: [String]()) { acc, s in
            if !acc.contains(s.region) { acc.append(s.region) }
        }
        List {
            Section {
                Text("Structures from oral, theatrical and literary traditions worldwide. Euro-American forms are included only for comparison.")
                    .foregroundColor(.secondary)
            }
            ForEach(regions, id: \.self) { region in
                Section(region) {
                    ForEach(store.ref.narrativeStyles.filter { $0.region == region }) { s in
                        NavigationLink(value: Route.style(s.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(s.name).font(.headline)
                                Text(s.origin).font(.caption).foregroundColor(.secondary)
                                Text(s.summary).font(.callout).lineLimit(3)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Narrative Styles")
    }
}

struct StyleDetailView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let styleID: String

    var body: some View {
        if let s = store.ref.style(styleID) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(s.region.uppercased()).font(.caption.weight(.bold)).foregroundColor(.wowGoldDeep)
                        Text(s.origin).font(.callout).foregroundColor(.secondary)
                        Text(s.summary)
                        Text("Good for: ").bold() + Text(s.whenToUse)
                    }
                    Button {
                        let e = store.newEntity("storylines", ["title": .string("New \(s.name) storyline"), "style": .string(s.id), "stages": .object([:])])
                        router.push(.entity("storylines", e.id))
                    } label: { Label("Start a storyline with this style", systemImage: "plus.circle.fill") }
                    .buttonStyle(.borderedProminent).tint(.wowGold).foregroundColor(.wowVioletDeep)
                }
                if let care = s.care {
                    Section("Cultural care") { Text(care) }
                }
                Section("Beats") {
                    ForEach(Array(s.stages.enumerated()), id: \.offset) { i, st in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(i + 1). \(st.name)").font(.headline)
                            Text(st.prompt).font(.callout).foregroundColor(.secondary)
                        }
                        .padding(.leading, 10)
                        .overlay(alignment: .leading) { Rectangle().fill(Color.wowGold).frame(width: 3) }
                    }
                }
                Section("Learn from the source") {
                    ForEach(s.sources, id: \.self) { Text($0) }
                }
                if s.id == "rasa" {
                    Section("The nine rasas") {
                        ForEach(store.ref.rasas) { r in
                            HStack {
                                Circle().fill(Color(hex: r.color)).frame(width: 12, height: 12)
                                Text(r.name).bold()
                                Text(r.meaning).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                let used = store.list("storylines").filter { $0.string("style") == s.id }
                Section("Your storylines in this style") {
                    if used.isEmpty { Text("None yet.").foregroundColor(.secondary) }
                    ForEach(used) { u in EntityRow(col: "storylines", entity: u) }
                }
            }
            .navigationTitle(s.name)
        } else {
            Text("Unknown style.")
        }
    }
}

// MARK: - Culture atlas

struct AtlasView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        List {
            Section {
                Text("Starting points for research — not a substitute for reading, listening to, and crediting people from these cultures. Tap + on anything to drop it into your Research Pool.")
                    .foregroundColor(.secondary)
            }
            ForEach(store.ref.culturePools) { p in
                NavigationLink(value: Route.culture(p.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.region).font(.headline)
                        Text(p.peoples).font(.caption).foregroundColor(.secondary).lineLimit(2)
                        Text(p.powerConcepts.prefix(3).joined(separator: " · ")).font(.callout).lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Culture Atlas")
    }
}

struct CultureDetailView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let cultureID: String
    @State private var added: Set<String> = []

    var body: some View {
        if let p = store.ref.culture(cultureID) {
            List {
                Section {
                    Text(p.peoples).foregroundColor(.secondary)
                    Label(p.care, systemImage: "hand.raised").foregroundColor(.wowGoldDeep)
                }
                section("Storytelling forms", p.storytelling, p)
                section("Cosmology & ideas", p.cosmology, p)
                section("Power concepts", p.powerConcepts, p)
                section("Figures (myth & history)", p.figures, p)
                section("Crafts & arts", p.crafts, p)
                section("Read & listen", p.research, p, kind: "book")
                let mine = ["characters", "abilities", "origins", "research"].flatMap { col in
                    store.list(col).filter { $0.strings("cultures").contains(p.id) }.map { (col: col, entity: $0) }
                }
                Section("Your entries rooted here") {
                    if mine.isEmpty {
                        Text("Tag characters, abilities, origins and sources with this culture to see them here.").foregroundColor(.secondary)
                    }
                    ForEach(mine, id: \.entity.id) { item in EntityRow(col: item.col, entity: item.entity, showType: true) }
                }
            }
            .navigationTitle(p.region)
        } else {
            Text("Unknown region.")
        }
    }

    private func section(_ title: String, _ items: [String], _ p: CulturePool, kind: String = "other") -> some View {
        Section(title) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top) {
                    Text(item)
                    Spacer()
                    Button {
                        store.create("research", [
                            "title": .string(item),
                            "kind": .string(kind),
                            "cultures": .strings([p.id]),
                            "notes": .string("From the atlas — \(p.region): \(title)."),
                            "care": .string(p.care),
                            "tags": .strings([title.lowercased()]),
                        ])
                        added.insert(item)
                    } label: {
                        Image(systemName: added.contains(item) ? "checkmark.circle.fill" : "plus.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Add to Research Pool")
                }
            }
        }
    }
}

// MARK: - Spark dice

struct SparkView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var rolls: [String: String] = [:]

    private let abilityRows = [("abilitySource", "Source"), ("abilityExpression", "Expressed"), ("abilityEffect", "Effect"), ("abilityCost", "Cost")]
    private let characterRows = [("characterWant", "Wants"), ("characterWound", "Wound"), ("characterContradiction", "Contradiction")]
    private let storyRows = [("storySpark", "Premise")]

    var body: some View {
        List {
            Section {
                Text("Old-fashioned random tables to jolt your imagination. Tap any line to re-roll it. Nothing is written for you — they're prompts.")
                    .foregroundColor(.secondary)
            }
            block("Ability", abilityRows) {
                let e = store.newEntity("abilities", [
                    "name": .string("New ability"),
                    "description": .string("Comes from \(r("abilitySource")); \(r("abilityExpression")); \(r("abilityEffect"))."),
                    "cost": .string(r("abilityCost")),
                    "tags": .strings(["spark"]),
                ])
                router.push(.entity("abilities", e.id))
            }
            block("Character", characterRows) {
                let e = store.newEntity("characters", [
                    "name": .string("New character"),
                    "motivation": .string(r("characterWant")),
                    "wound": .string(r("characterWound")),
                    "contradiction": .string(r("characterContradiction")),
                    "tags": .strings(["spark"]),
                ])
                router.push(.entity("characters", e.id))
            }
            block("Story", storyRows) {
                let e = store.newEntity("storylines", ["title": .string("New storyline"), "summary": .string(r("storySpark")), "tags": .strings(["spark"])])
                router.push(.entity("storylines", e.id))
            }
        }
        .navigationTitle("Spark Dice")
        .onAppear {
            if rolls.isEmpty { for (k, _) in abilityRows + characterRows + storyRows { roll(k) } }
        }
    }

    private func r(_ key: String) -> String { rolls[key] ?? "" }
    private func roll(_ key: String) { rolls[key] = store.ref.sparkTables[key]?.randomElement() ?? "" }

    private func block(_ title: String, _ rows: [(String, String)], save: @escaping () -> Void) -> some View {
        Section {
            ForEach(rows, id: \.0) { key, label in
                Button { roll(key) } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(label.uppercased()).font(.caption.weight(.semibold)).foregroundColor(.secondary).frame(width: 110, alignment: .leading)
                        Text(r(key)).font(.system(.body, design: .serif)).foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
            }
            HStack {
                Button { rows.forEach { roll($0.0) } } label: { Label("Roll all", systemImage: "dice") }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Save as draft", action: save).buttonStyle(.borderedProminent)
            }
        } header: {
            Text(title).font(.system(.title3, design: .serif).weight(.bold)).foregroundColor(.wowViolet).textCase(nil)
        }
    }
}
