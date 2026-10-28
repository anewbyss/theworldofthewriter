import SwiftUI

// MARK: - Bond semantics (mirrors web/js/kin.js)

enum Bonds {
    static let parentLike = ["adoptive parent of", "foster parent of", "guardian of", "step-parent of", "spiritual parent of"]
    static let teaching = ["mentor of", "teacher of", "master of (apprentice)", "initiator of"]
    static let inverse: [String: String] = [
        "adoptive parent of": "adopted child of", "foster parent of": "foster child of", "guardian of": "ward of", "step-parent of": "step-child of",
        "spiritual parent of": "spiritual child of", "godparent / sponsor of": "godchild of", "mentor of": "mentee of", "teacher of": "student of",
        "master of (apprentice)": "apprentice of", "initiator of": "initiate of", "chosen elder of": "chosen younger kin of",
    ]
}

extension Store {
    struct BondView: Identifiable {
        let bond: Entity
        let other: String
        let label: String
        let giver: Bool
        var id: String { bond.id }
    }

    func bonds(of id: String) -> [BondView] {
        list("bonds").filter { $0.string("from") == id || $0.string("to") == id }.map { b in
            let mine = b.string("from") == id
            let type = b.string("type").isEmpty ? "bond" : b.string("type")
            return BondView(bond: b, other: mine ? b.string("to") : b.string("from"), label: mine ? type : (Bonds.inverse[type] ?? type), giver: mine)
        }
    }

    func adoptiveParents(_ id: String) -> [(id: String, type: String)] {
        list("bonds").filter { $0.string("to") == id && Bonds.parentLike.contains($0.string("type")) }.map { (id: $0.string("from"), type: $0.string("type")) }
    }

    func adoptedChildren(_ id: String) -> [(id: String, type: String)] {
        list("bonds").filter { $0.string("from") == id && Bonds.parentLike.contains($0.string("type")) }.map { (id: $0.string("to"), type: $0.string("type")) }
    }

    func bondTeachers(_ id: String) -> [(id: String, type: String)] {
        list("bonds").filter { $0.string("to") == id && Bonds.teaching.contains($0.string("type")) }.map { (id: $0.string("from"), type: $0.string("type")) }
    }

    /// Who should receive an heirloom next, by its succession rule.
    func suggestedHeir(_ g: Entity) -> (id: String, why: String)? {
        var births: [String: Double] = [:]
        for ev in Continuity.orderedEvents(self) where ev.string("type") == "birth" {
            guard let s = ev.number("sequence") else { continue }
            for id in ev.strings("characters") where births[id] == nil { births[id] = s }
        }
        let alive: (String) -> Bool = { id in self.get("characters", id).map { $0.string("status") != "dead" } ?? false }
        func byBirth(_ ids: [String], descending: Bool = false) -> [String] {
            ids.filter(alive).sorted { a, b in
                let x = births[a], y = births[b]
                if descending {
                    if let x = x, let y = y { return x > y }
                    return x != nil
                }
                return (x ?? .infinity) < (y ?? .infinity)
            }
        }
        let holder = g.string("owner")
        var children: [String] = []
        if !holder.isEmpty {
            for c in list("characters") where c.strings("parents").contains(holder) && !children.contains(c.id) { children.append(c.id) }
            for c in adoptedChildren(holder) where !children.contains(c.id) { children.append(c.id) }
        }
        switch g.string("succession") {
        case "eldest child":
            return byBirth(children).first.map { (id: $0, why: "eldest living child of the holder") }
        case "youngest child":
            return byBirth(children, descending: true).first.map { (id: $0, why: "youngest living child of the holder") }
        case "next in the lineage":
            let lin = g.string("heirloomOf")
            guard !lin.isEmpty else { return nil }
            let held = Set(g.strings("pastHolders") + [holder])
            let members = list("characters").filter { $0.strings("lineages").contains(lin) && !held.contains($0.id) }.map { $0.id }
            return byBirth(members).first.map { (id: $0, why: "next living lineage member who hasn't held it") }
        default:
            return g.string("heir").isEmpty ? nil : (id: g.string("heir"), why: "designated heir")
        }
    }
}

// MARK: - Bonds panels

struct BondsPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let characterID: String
    @State private var type = "found family with"
    @State private var other = ""
    @State private var tradition = ""

    private let groups: [(String, (Store.BondView) -> Bool)] = [
        ("Parents & guardians (not by blood)", { !$0.giver && (Bonds.parentLike.contains($0.bond.string("type")) || $0.bond.string("type") == "godparent / sponsor of") }),
        ("In their care", { $0.giver && (Bonds.parentLike.contains($0.bond.string("type")) || $0.bond.string("type") == "godparent / sponsor of") }),
        ("Mentors & teachers", { !$0.giver && (Bonds.teaching.contains($0.bond.string("type")) || $0.bond.string("type") == "chosen elder of") }),
        ("Students & apprentices", { $0.giver && (Bonds.teaching.contains($0.bond.string("type")) || $0.bond.string("type") == "chosen elder of") }),
        ("Chosen & sworn kin", { ["found family with", "sworn sibling of", "milk kin of", "age-set mate of", "co-parent / compadre of", "study partner of", "other"].contains($0.bond.string("type")) }),
        ("Partners", { ["partner / spouse of", "betrothed to"].contains($0.bond.string("type")) }),
    ]

    var body: some View {
        let all = store.bonds(of: characterID)
        if all.isEmpty { Text("No bonds yet. Add adoptive parents, mentors, found family, sworn siblings and more.").foregroundColor(.secondary) }
        ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
            let items = all.filter(g.1)
            if !items.isEmpty {
                Text(g.0).font(.subheadline.weight(.semibold))
                ForEach(items) { x in
                    Button { router.push(.entity("bonds", x.bond.id)) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.title("characters", store.get("characters", x.other)) + " — " + x.label)
                            let extra = x.bond.strings("tradition").map { store.refData.label("kinship", $0) } + [x.bond.string("status") == "active" ? "" : x.bond.string("status")]
                            if !extra.filter({ !$0.isEmpty }).isEmpty {
                                Text(extra.filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        DisclosureGroup("Add a bond") {
            Picker("Is…", selection: $type) {
                ForEach(store.def("bonds")?.fields.first { $0.key == "type" }?.options ?? [], id: \.self) { Text($0).tag($0) }
            }
            Picker("…of / with", selection: $other) {
                Text("—").tag("")
                ForEach(store.options("characters").filter { $0.id != characterID }) { Text($0.label).tag($0.id) }
            }
            Picker("Tradition", selection: $tradition) {
                Text("— optional —").tag("")
                ForEach(store.ref.kinshipTraditions) { Text($0.name).tag($0.id) }
            }
            .onChange(of: tradition) { t in if let k = store.ref.kinshipTraditions.first(where: { $0.id == t }) { type = k.bond } }
            Button("Add bond") {
                store.create("bonds", ["from": .string(characterID), "type": .string(type), "to": .string(other), "tradition": .strings(tradition.isEmpty ? [] : [tradition]), "status": .string("active")])
                other = ""
                tradition = ""
            }
            .disabled(other.isEmpty)
        }
    }
}

struct BondPanel: View {
    @EnvironmentObject var store: Store
    let bondID: String

    var body: some View {
        if let b = store.get("bonds", bondID) {
            let from = store.title("characters", store.get("characters", b.string("from")))
            let to = store.title("characters", store.get("characters", b.string("to")))
            if b.string("from").isEmpty || b.string("to").isEmpty {
                Text("Choose both people.").foregroundColor(.secondary)
            } else {
                Text("\(from) is \(b.string("type").isEmpty ? "bonded to" : b.string("type")) \(to).")
                if let inv = Bonds.inverse[b.string("type")] { Text("\(to) is \(inv) \(from).").font(.callout).foregroundColor(.secondary) }
            }
            ForEach(b.strings("tradition"), id: \.self) { id in
                if let k = store.ref.kinshipTraditions.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k.name).font(.headline)
                        Text(k.roots).font(.caption).foregroundColor(.secondary)
                        Text(k.description).font(.callout)
                    }
                }
            }
        }
    }
}

// MARK: - Heirlooms

struct HeirloomPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let gearID: String

    var body: some View {
        if let g = store.get("gear", gearID) {
            if g.string("heirloomOf").isEmpty && g.string("heir").isEmpty && g.strings("pastHolders").isEmpty {
                Text("Not an heirloom. Set “Heirloom of” to track it through a family.").foregroundColor(.secondary)
            } else {
                if let l = store.get("lineages", g.string("heirloomOf")) {
                    Button("Belongs to \(store.title("lineages", l))" + (g.string("succession").isEmpty ? "" : " · passes on: \(g.string("succession"))")) { router.push(.entity("lineages", l.id)) }
                }
                let line = holderLine(g)
                if line.isEmpty { Text("No holders recorded yet.").foregroundColor(.secondary) }
                ForEach(Array(line.enumerated()), id: \.offset) { i, id in
                    Button("\(i + 1). \(store.title("characters", store.get("characters", id)))" + (id == g.string("owner") ? " — holds it now" : "")) { router.push(.entity("characters", id)) }
                }
                if let next = store.suggestedHeir(g) {
                    Button("Next: \(store.title("characters", store.get("characters", next.id))) (\(next.why))") { router.push(.entity("characters", next.id)) }
                } else {
                    Text("Next: no heir yet").foregroundColor(.secondary)
                }
            }
        }
    }

    private func holderLine(_ g: Entity) -> [String] {
        var out: [String] = []
        let trail = Continuity.orderedEvents(store).filter { $0.string("item") == g.id && $0.string("type") == "gains item" }.compactMap { $0.strings("characters").first }
        for id in g.strings("pastHolders") + trail + (g.string("owner").isEmpty ? [] : [g.string("owner")]) where !out.contains(id) { out.append(id) }
        return out
    }
}

struct LineageHeirloomsPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let lineageID: String

    var body: some View {
        let items = store.list("gear").filter { $0.string("heirloomOf") == lineageID }
        if items.isEmpty { Text("No heirlooms yet — set “Heirloom of” on a piece of gear.").foregroundColor(.secondary) }
        ForEach(items) { g in
            Button { router.push(.entity("gear", g.id)) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.title("gear", g))
                    let holder = store.get("characters", g.string("owner")).map { "held by " + store.title("characters", $0) } ?? "unheld"
                    let next = store.suggestedHeir(g).map { " · next: " + store.title("characters", store.get("characters", $0.id)) } ?? ""
                    Text(holder + next).font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
}

struct CharacterHeirloomsPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let characterID: String

    var body: some View {
        let held = store.list("gear").filter { $0.string("owner") == characterID && !$0.string("heirloomOf").isEmpty }
        let due = store.list("gear").filter { $0.string("owner") != characterID && store.suggestedHeir($0)?.id == characterID }
        if held.isEmpty && due.isEmpty { Text("No heirlooms held or due.").foregroundColor(.secondary) }
        ForEach(held) { g in Button("Holds: " + store.title("gear", g)) { router.push(.entity("gear", g.id)) } }
        ForEach(due) { g in Button("Next in line for: " + store.title("gear", g)) { router.push(.entity("gear", g.id)) } }
    }
}

// MARK: - Labels & tags

let labelColors: [String: Color] = ["violet": Color(hex: "#8E5BD0"), "gold": Color(hex: "#E1AD01"), "teal": Color(hex: "#2C7A7B"), "rose": Color(hex: "#C05680"), "green": Color(hex: "#38A169"), "blue": Color(hex: "#2B6CB0"), "grey": Color(hex: "#718096")]

struct TagChip: View {
    @EnvironmentObject var store: Store
    let tag: String

    var body: some View {
        let color = store.labelFor(tag).flatMap { labelColors[$0.string("color")] }
        Text("#" + tag)
            .font(.caption)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill((color ?? Color.wowVioletSoft).opacity(0.18)))
            .overlay(Capsule().stroke(color ?? Color.wowVioletSoft.opacity(0.4)))
    }
}

struct LabelsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var renaming: String?
    @State private var renameText = ""
    @State private var menu = ""
    @State private var newOption = ""

    var body: some View {
        let tags = store.tagIndex()
        let selectFields = store.ref.collections.flatMap { c in c.fields.filter { $0.type == "select" }.map { (key: "\(c.id).\($0.key)", label: "\(c.label) → \($0.label)") } }
        List {
            Section {
                Text("Rename, merge, colour and describe every tag, and add your own options to any menu. Every dropdown also has a ＋ button for adding options.")
                    .foregroundColor(.secondary)
            }
            Section("Tags · \(tags.count)") {
                if tags.isEmpty { Text("No tags yet. Add tags to any entry.").foregroundColor(.secondary) }
                ForEach(tags, id: \.tag) { t in
                    let label = store.labelFor(t.tag)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Button { router.push(.tag(t.tag)) } label: { TagChip(tag: t.tag) }.buttonStyle(.plain)
                            Text("\(t.uses.count) uses").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Menu {
                                Button("Rename or merge…") { renameText = t.tag; renaming = t.tag }
                                Menu("Colour") {
                                    ForEach(labelColors.keys.sorted(), id: \.self) { c in Button(c) { upsert(t.tag, "color", .string(c)) } }
                                    Button("None") { upsert(t.tag, "color", .null) }
                                }
                                Button("Delete from all entries", role: .destructive) {
                                    for u in t.uses { store.update(u.col, u.entity.id, "tags", .strings(u.entity.strings("tags").filter { $0 != t.tag })) }
                                    if let l = label { store.remove("labels", l.id) }
                                }
                            } label: { Image(systemName: "ellipsis.circle") }
                        }
                        TextField("What this tag means", text: Binding(get: { label?.string("description") ?? "" }, set: { upsert(t.tag, "description", .string($0)) }))
                            .font(.callout)
                    }
                }
            }
            Section("Your own menu options") {
                Picker("Menu", selection: $menu) {
                    Text("— choose —").tag("")
                    ForEach(selectFields, id: \.key) { Text($0.label).tag($0.key) }
                }
                HStack {
                    TextField("New option", text: $newOption)
                    Button("Add") {
                        let name = newOption.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty, !menu.isEmpty else { return }
                        store.create("labels", ["name": .string(name), "kind": .string("menu option"), "field": .string(menu)])
                        newOption = ""
                    }
                    .disabled(menu.isEmpty || newOption.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ForEach(store.list("labels").filter { $0.string("kind") == "menu option" }) { l in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(l.string("name")).bold()
                            Text(selectFields.first { $0.key == l.string("field") }?.label ?? l.string("field")).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) { store.remove("labels", l.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                    }
                }
            }
        }
        .navigationTitle("Labels & Tags")
        .alert("Rename or merge #\(renaming ?? "")", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("New name (or an existing tag to merge into)", text: $renameText)
            Button("Rename") {
                let to = renameText.trimmingCharacters(in: .whitespaces)
                if let from = renaming, !to.isEmpty, to != from { store.renameTag(from, to: to) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private func upsert(_ tag: String, _ key: String, _ value: JSONValue) {
        if let l = store.labelFor(tag) {
            store.update("labels", l.id, key, value)
        } else {
            store.create("labels", ["name": .string(tag), "kind": .string("tag"), key: value])
        }
    }
}

struct TagView: View {
    @EnvironmentObject var store: Store
    let tag: String

    var body: some View {
        let uses = store.tagIndex().first { $0.tag == tag }?.uses ?? []
        List {
            if let d = store.labelFor(tag)?.string("description"), !d.isEmpty {
                Section { Text(d) }
            }
            if uses.isEmpty { Text("Nothing carries this tag.").foregroundColor(.secondary) }
            ForEach(store.ref.collections) { c in
                let items = uses.filter { $0.col == c.id }
                if !items.isEmpty {
                    Section(c.label) {
                        ForEach(items, id: \.entity.id) { u in EntityRow(col: u.col, entity: u.entity) }
                    }
                }
            }
        }
        .navigationTitle("#" + tag)
    }
}
