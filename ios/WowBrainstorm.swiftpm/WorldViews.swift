import SwiftUI

// MARK: - Reference library picker

/// Chips plus a searchable sheet for choosing entries from a built-in library.
struct RefDataPicker: View {
    @EnvironmentObject var store: Store
    let source: String
    let ids: [String]
    let onChange: ([String]) -> Void
    @State private var showSheet = false
    @State private var query = ""

    var body: some View {
        FlowLayout {
            ForEach(ids, id: \.self) { id in
                Button { onChange(ids.filter { $0 != id }) } label: {
                    HStack(spacing: 4) {
                        Text(store.refData.label(source, id))
                        Image(systemName: "xmark.circle.fill").font(.caption)
                    }
                    .font(.callout)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.wowGold.opacity(0.22)))
                }
                .buttonStyle(.plain)
            }
        }
        if ["langFeatures", "powerArchetypes", "religions"].contains(source) {
            ForEach(ids, id: \.self) { id in
                if let it = store.refData.item(source, id), !it.hint.isEmpty {
                    (Text(it.label + ": ").bold() + Text(it.hint)).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        Button { showSheet = true } label: { Label("Add from the library", systemImage: "books.vertical") }
            .sheet(isPresented: $showSheet) {
                NavigationStack {
                    List {
                        ForEach(store.refData.groups(source)) { g in
                            let items = g.items.filter { query.isEmpty || ($0.label + " " + g.group).localizedCaseInsensitiveContains(query) }
                            if !items.isEmpty {
                                Section(g.group) {
                                    ForEach(items) { it in
                                        Button {
                                            onChange(ids.contains(it.id) ? ids.filter { $0 != it.id } : ids + [it.id])
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(it.label).foregroundColor(.primary)
                                                    if !it.hint.isEmpty { Text(it.hint).font(.caption).foregroundColor(.secondary).lineLimit(2) }
                                                }
                                                Spacer()
                                                if ids.contains(it.id) { Image(systemName: "checkmark.circle.fill").foregroundColor(.wowGoldDeep) }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $query, prompt: "Search the library")
                    .navigationTitle("Choose")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showSheet = false } } }
                }
            }
    }
}

// MARK: - Genealogy helpers

extension Store {
    func childrenOf(_ id: String) -> [Entity] { list("characters").filter { $0.strings("parents").contains(id) } }
    func studentsOf(_ id: String) -> [Entity] { list("characters").filter { $0.strings("teachers").contains(id) } }

    func ancestorsOf(_ id: String) -> [Entity] {
        var out: [Entity] = []
        var seen = Set<String>()
        var stack = get("characters", id)?.strings("parents") ?? []
        while let p = stack.popLast() {
            if seen.contains(p) || p == id { continue }
            seen.insert(p)
            guard let c = get("characters", p) else { continue }
            out.append(c)
            stack.append(contentsOf: c.strings("parents"))
        }
        return out
    }

    /// Flattened tree rows (depth, character id, note) from roots via children, adopted children and students.
    func treeRows(roots: [String], members: Set<String>?, withStudents: Bool) -> [(depth: Int, id: String, note: String)] {
        var rows: [(depth: Int, id: String, note: String)] = []
        func walk(_ id: String, _ depth: Int, _ seen: Set<String>) {
            guard !seen.contains(id), depth < 30 else { return }
            rows.append((depth, id, ""))
            let next = seen.union([id])
            let kids = childrenOf(id).filter { members == nil || members!.contains($0.id) }
            for k in kids { walk(k.id, depth + 1, next) }
            for a in adoptedChildren(id) where get("characters", a.id) != nil && (members == nil || members!.contains(a.id)) && !kids.contains(where: { $0.id == a.id }) {
                rows.append((depth + 1, a.id, "◇ " + (Bonds.inverse[a.type] ?? "bonded") + ": "))
            }
            if withStudents {
                for s in studentsOf(id) where members == nil || members!.contains(s.id) { rows.append((depth + 1, s.id, "✦ student: ")) }
            }
        }
        for r in roots { walk(r, 0, []) }
        return rows
    }

    /// Readable reasons a character holds an ability.
    func howHeld(_ c: Entity, _ a: Entity) -> [String] {
        var out: [String] = []
        let lin = a.string("lineage")
        if !lin.isEmpty && c.strings("lineages").contains(lin) { out.append("through " + title("lineages", get("lineages", lin))) }
        if let anc = ancestorsOf(c.id).first(where: { $0.strings("abilities").contains(a.id) }) { out.append("inherited from " + title("characters", anc)) }
        for t in c.strings("teachers") where get("characters", t)?.strings("abilities").contains(a.id) ?? false {
            out.append("taught by " + title("characters", get("characters", t)))
        }
        for t in bondTeachers(c.id) where get("characters", t.id)?.strings("abilities").contains(a.id) ?? false {
            out.append(t.type.replacingOccurrences(of: " of", with: "").replacingOccurrences(of: " (apprentice)", with: "") + ": " + title("characters", get("characters", t.id)))
        }
        for p in adoptiveParents(c.id) where get("characters", p.id)?.strings("abilities").contains(a.id) ?? false {
            out.append("from " + p.type.replacingOccurrences(of: " of", with: "") + " " + title("characters", get("characters", p.id)))
        }
        for ev in list("events") where ev.string("type") == "acquires ability" && ev.string("ability") == a.id && ev.strings("characters").contains(c.id) {
            out.append("acquired in " + title("events", ev))
        }
        if let o = get("origins", c.string("origin")) { out.append("origin: " + title("origins", o)) }
        return out
    }
}

struct TreeRowsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let rows: [(depth: Int, id: String, note: String)]

    var body: some View {
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            Button { router.push(.entity("characters", row.id)) } label: {
                HStack(spacing: 6) {
                    Rectangle().fill(Color.wowGold).frame(width: 2, height: 18)
                    Text(row.note + store.title("characters", store.get("characters", row.id)))
                }
                .padding(.leading, CGFloat(row.depth) * 18)
            }
        }
    }
}

private func chipRow(_ store: Store, _ router: Router, _ col: String, _ ids: [String], gold: Bool = false) -> some View {
    FlowLayout {
        ForEach(ids, id: \.self) { id in
            Button { router.push(.entity(col, id)) } label: { Chip(text: store.title(col, store.get(col, id)), gold: gold) }.buttonStyle(.plain)
        }
    }
}

private struct Sub: View {
    let title: String
    var body: some View { Text(title).font(.subheadline.weight(.semibold)).padding(.top, 4) }
}

// MARK: - Ability trace

struct AbilityTracePanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let abilityID: String

    var body: some View {
        if let a = store.get("abilities", abilityID) {
            let chain = systemChain(a)
            let unlocks = store.list("abilities").filter { $0.strings("prerequisites").contains(a.id) }
            let counters = store.list("abilities").filter { $0.strings("counters").contains(a.id) }
            let holders = store.list("characters").filter { $0.strings("abilities").contains(a.id) }
            Sub(title: "System")
            if chain.isEmpty {
                Text("Not part of a power system yet.").foregroundColor(.secondary)
            } else {
                Text(chain.map { store.title("powerSystems", $0) }.joined(separator: " › ") + (a.string("rank").isEmpty ? "" : " · rank " + a.string("rank")))
            }
            if !a.strings("archetypes").isEmpty {
                Sub(title: "Real-world roots")
                Text(a.strings("archetypes").map { store.refData.label("powerArchetypes", $0) }.joined(separator: ", ")).font(.callout)
            }
            if let lin = store.get("lineages", a.string("lineage")) {
                Sub(title: "Lineage")
                Button(store.title("lineages", lin) + (lin.string("inheritance").isEmpty ? "" : " · " + lin.string("inheritance"))) { router.push(.entity("lineages", lin.id)) }
            }
            let pre = prereqRows(a)
            if !pre.isEmpty {
                Sub(title: "Builds on")
                ForEach(Array(pre.enumerated()), id: \.offset) { _, r in
                    Button(store.title("abilities", store.get("abilities", r.id))) { router.push(.entity("abilities", r.id)) }
                        .padding(.leading, CGFloat(r.depth) * 16)
                }
            }
            if !unlocks.isEmpty {
                Sub(title: "Unlocks")
                chipRow(store, router, "abilities", unlocks.map { $0.id })
            }
            if !a.strings("counters").isEmpty || !counters.isEmpty {
                Sub(title: "Counters")
                if !a.strings("counters").isEmpty { Text("Countered by: " + a.strings("counters").map { store.title("abilities", store.get("abilities", $0)) }.joined(separator: ", ")).font(.callout) }
                if !counters.isEmpty { Text("Counters: " + counters.map { store.title("abilities", $0) }.joined(separator: ", ")).font(.callout) }
            }
            Sub(title: "Holders (\(holders.count))")
            ForEach(holders) { c in
                Button { router.push(.entity("characters", c.id)) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.title("characters", c))
                        let why = store.howHeld(c, a)
                        Text(why.isEmpty ? "source untraced" : why.joined(separator: "; ")).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func systemChain(_ a: Entity) -> [Entity] {
        var out: [Entity] = []
        var s = store.get("powerSystems", a.string("system"))
        while let cur = s, out.count < 25 {
            out.insert(cur, at: 0)
            s = store.get("powerSystems", cur.string("parent"))
        }
        return out
    }

    private func prereqRows(_ a: Entity) -> [(depth: Int, id: String)] {
        var rows: [(depth: Int, id: String)] = []
        func walk(_ id: String, _ depth: Int, _ seen: Set<String>) {
            guard !seen.contains(id), depth < 8, let x = store.get("abilities", id) else { return }
            rows.append((depth, id))
            for p in x.strings("prerequisites") { walk(p, depth + 1, seen.union([id])) }
        }
        for p in a.strings("prerequisites") { walk(p, 0, [a.id]) }
        return rows
    }
}

// MARK: - Power system

struct PowerSystemPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let systemID: String

    var body: some View {
        if let s = store.get("powerSystems", systemID) {
            let ranks = s.string("ranks").split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let abilities = store.list("abilities").filter { $0.string("system") == s.id }
            let subs = store.list("powerSystems").filter { $0.string("parent") == s.id }
            let abilityIDs = Set(abilities.map { $0.id })
            let practitioners = store.list("characters").filter { c in c.strings("abilities").contains { abilityIDs.contains($0) } }
            if ranks.isEmpty {
                Text("List ranks (one per line) to see the ladder.").foregroundColor(.secondary)
            }
            ForEach(Array(ranks.enumerated()), id: \.offset) { i, r in
                let here = abilities.filter { $0.string("rank").trimmingCharacters(in: .whitespaces).lowercased() == r.lowercased() }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(i + 1). \(r)").font(.headline)
                    if here.isEmpty {
                        Text("no abilities yet").font(.caption).foregroundColor(.secondary)
                    } else {
                        chipRow(store, router, "abilities", here.map { $0.id })
                    }
                }
            }
            let rankSet = Set(ranks.map { $0.lowercased() })
            let unranked = abilities.filter { !rankSet.contains($0.string("rank").trimmingCharacters(in: .whitespaces).lowercased()) }
            if !unranked.isEmpty {
                Sub(title: "Other abilities")
                chipRow(store, router, "abilities", unranked.map { $0.id })
            }
            Button {
                let e = store.newEntity("abilities", ["system": .string(s.id), "rank": .string(ranks.first ?? "")])
                router.push(.entity("abilities", e.id))
            } label: { Label("Ability in this system", systemImage: "plus") }
            if !subs.isEmpty {
                Sub(title: "Branches / schools")
                chipRow(store, router, "powerSystems", subs.map { $0.id })
            }
            if !practitioners.isEmpty {
                Sub(title: "Practitioners")
                chipRow(store, router, "characters", practitioners.map { $0.id }, gold: true)
            }
        }
    }
}

// MARK: - Lineage & family

struct LineagePanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let lineageID: String

    var body: some View {
        if let l = store.get("lineages", lineageID) {
            let members = store.list("characters").filter { $0.strings("lineages").contains(l.id) }
            let set = Set(members.map { $0.id } + (l.string("founder").isEmpty ? [] : [l.string("founder")]))
            let roots = set.filter { id in !(store.get("characters", id)?.strings("parents") ?? []).contains { set.contains($0) } }.sorted()
            let teaching = ["teaching lineage", "initiation / priesthood line"].contains(l.string("kind")) || ["by teaching", "by initiation"].contains(l.string("inheritance"))
            if set.isEmpty {
                Text("Add this lineage to characters (and set their parents) to grow the tree.").foregroundColor(.secondary)
            } else {
                TreeRowsView(rows: store.treeRows(roots: roots.isEmpty ? Array(set) : roots, members: set, withStudents: teaching))
            }
            let inherited = l.strings("abilities").compactMap { store.get("abilities", $0) }
            if !inherited.isEmpty {
                Sub(title: "Inherited powers")
                ForEach(inherited) { a in
                    let holding = members.filter { $0.strings("abilities").contains(a.id) }.count
                    Button("\(store.title("abilities", a)) — held by \(holding)/\(members.count) members") { router.push(.entity("abilities", a.id)) }
                }
            }
            Button {
                let e = store.newEntity("characters", ["name": .string(""), "lineages": .strings([l.id])])
                router.push(.entity("characters", e.id))
            } label: { Label("New member", systemImage: "person.badge.plus") }
        }
    }
}

struct FamilyPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let characterID: String

    var body: some View {
        if let c = store.get("characters", characterID) {
            let parents = c.strings("parents").filter { store.get("characters", $0) != nil }
            let kids = store.childrenOf(c.id).map { $0.id }
            let siblings = store.list("characters").filter { x in x.id != c.id && x.strings("parents").contains { parents.contains($0) } }.map { $0.id }
            let students = store.studentsOf(c.id).map { $0.id }
            if parents.isEmpty && kids.isEmpty && c.strings("lineages").isEmpty && c.strings("teachers").isEmpty && store.bonds(of: c.id).isEmpty {
                Text("Set parents, teachers and lineages above, or add bonds below, to trace family lines and inherited powers.").foregroundColor(.secondary)
            }
            let raisedBy = store.adoptiveParents(c.id).filter { store.get("characters", $0.id) != nil }
            if !raisedBy.isEmpty {
                Sub(title: "Raised by")
                ForEach(raisedBy, id: \.id) { p in
                    Button("\(store.title("characters", store.get("characters", p.id))) · \(p.type.replacingOccurrences(of: " of", with: ""))") { router.push(.entity("characters", p.id)) }
                }
            }
            if !parents.isEmpty { Sub(title: "Parents"); chipRow(store, router, "characters", parents, gold: true) }
            if !siblings.isEmpty { Sub(title: "Siblings"); chipRow(store, router, "characters", siblings) }
            if !kids.isEmpty { Sub(title: "Children"); chipRow(store, router, "characters", kids) }
            if !c.strings("teachers").isEmpty { Sub(title: "Teachers"); chipRow(store, router, "characters", c.strings("teachers")) }
            if !students.isEmpty { Sub(title: "Students"); chipRow(store, router, "characters", students) }
            if !c.strings("lineages").isEmpty { Sub(title: "Lineages"); chipRow(store, router, "lineages", c.strings("lineages"), gold: true) }
            let powers = c.strings("lineages").flatMap { lid in (store.get("lineages", lid)?.strings("abilities") ?? []).map { (lid, $0) } }.filter { store.get("abilities", $0.1) != nil }
            if !powers.isEmpty {
                Sub(title: "Lineage powers")
                ForEach(Array(powers.enumerated()), id: \.offset) { _, p in
                    Text("\(store.title("abilities", store.get("abilities", p.1))) from \(store.title("lineages", store.get("lineages", p.0)))" + (c.strings("abilities").contains(p.1) ? " ✓" : " (not awakened)")).font(.callout)
                }
            }
            let ancestors = store.ancestorsOf(c.id)
            let eldest = ancestors.filter { a in !a.strings("parents").contains { store.get("characters", $0) != nil } }.map { $0.id }
            if !eldest.isEmpty {
                Sub(title: "Family tree")
                TreeRowsView(rows: store.treeRows(roots: eldest, members: nil, withStudents: false))
            }
        }
    }
}

// MARK: - Peoples, faiths and languages

struct CulturePanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let cultureID: String

    var body: some View {
        if let p = store.get("cultures", cultureID) {
            if !p.strings("realPeoples").isEmpty {
                Sub(title: "Drawn from")
                Text(p.strings("realPeoples").map { store.refData.label("peoples", $0) }.joined(separator: ", ")).font(.callout)
            }
            let subs = store.list("cultures").filter { $0.string("parent") == p.id }.map { $0.id }
            let members = store.list("characters").filter { $0.strings("peoples").contains(p.id) }.map { $0.id }
            let places = store.list("places").filter { $0.strings("peoples").contains(p.id) }.map { $0.id }
            if !subs.isEmpty { Sub(title: "Branches"); chipRow(store, router, "cultures", subs) }
            if members.isEmpty { Text("No characters belong to this people yet.").foregroundColor(.secondary) } else { Sub(title: "Characters"); chipRow(store, router, "characters", members, gold: true) }
            if !places.isEmpty { Sub(title: "Lives in"); chipRow(store, router, "places", places) }
        }
    }
}

struct ReferenceReligionCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let refID: String

    var body: some View {
        let r = store.refData.religion(refID)
        if let religion = r.religion {
            VStack(alignment: .leading, spacing: 4) {
                Text(r.branch.map { "\(religion.name) — \($0.name)" } ?? religion.name).font(.headline)
                Text(r.branch?.note ?? religion.origin).font(.callout)
                Text("Key ideas: " + religion.concepts.joined(separator: "; ")).font(.caption)
                Text(religion.care).font(.caption).foregroundColor(.wowGoldDeep)
                Button("Open in Faiths library →") { router.push(.faith(religion.id)) }.font(.caption)
            }
        }
    }
}

struct ReligionPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let religionID: String

    var body: some View {
        if let r = store.get("religions", religionID) {
            ForEach(r.strings("basedOn"), id: \.self) { ReferenceReligionCard(refID: $0) }
            let branches = store.list("religions").filter { $0.string("parent") == r.id }.map { $0.id }
            let followers = store.list("characters").filter { $0.strings("religions").contains(r.id) }.map { $0.id }
            let powers = store.list("abilities").filter { $0.string("religion") == r.id }.map { $0.id }
            if !branches.isEmpty { Sub(title: "Branches in your world"); chipRow(store, router, "religions", branches) }
            if !followers.isEmpty { Sub(title: "Followers"); chipRow(store, router, "characters", followers, gold: true) }
            if !powers.isEmpty { Sub(title: "Powers it grants"); chipRow(store, router, "abilities", powers) }
            if r.strings("basedOn").isEmpty && branches.isEmpty && followers.isEmpty {
                Text("Draw on real faiths above, or give characters this faith.").foregroundColor(.secondary)
            }
        }
    }
}

struct LanguagePanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let languageID: String

    var body: some View {
        if let l = store.get("languages", languageID) {
            let chain = ancestry(l)
            let daughters = store.list("languages").filter { $0.string("parent") == l.id }.map { $0.id }
            let speakers = store.list("characters").filter { $0.strings("languages").contains(l.id) }.map { $0.id }
            let lexicon = l.string("lexicon").split(separator: "\n").compactMap { line -> (String, String)? in
                let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                return parts.count == 2 && !parts[0].isEmpty ? (parts[0], parts[1]) : nil
            }
            if !chain.isEmpty { Sub(title: "Descends from"); Text(chain.map { store.title("languages", $0) }.joined(separator: " › ")) }
            if !daughters.isEmpty { Sub(title: "Daughter languages"); chipRow(store, router, "languages", daughters) }
            ForEach(l.strings("basedOn"), id: \.self) { id in
                let ref = store.refData.language(id)
                if let lang = ref.language, let fam = ref.family {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(lang.name) (\(fam.name))").font(.headline)
                        if !lang.features.isEmpty { Text("Features: " + lang.features.map { store.refData.label("langFeatures", $0) }.joined(separator: ", ")).font(.caption) }
                        if !lang.scripts.isEmpty { Text("Scripts: " + lang.scripts.map { store.refData.label("writing", $0) }.joined(separator: ", ")).font(.caption) }
                        if !lang.status.isEmpty { Text("Status: " + lang.status).font(.caption).foregroundColor(.secondary) }
                    }
                }
            }
            if !speakers.isEmpty { Sub(title: "Speakers"); chipRow(store, router, "characters", speakers, gold: true) }
            if !lexicon.isEmpty {
                Sub(title: "Lexicon (\(lexicon.count))")
                ForEach(Array(lexicon.prefix(40).enumerated()), id: \.offset) { _, w in
                    HStack { Text(w.0).bold(); Text(w.1).foregroundColor(.secondary) }
                }
            }
        }
    }

    private func ancestry(_ l: Entity) -> [Entity] {
        var out: [Entity] = []
        var p = store.get("languages", l.string("parent"))
        while let cur = p, out.count < 25 {
            out.insert(cur, at: 0)
            p = store.get("languages", cur.string("parent"))
        }
        return out
    }
}

// MARK: - Faiths library

struct FaithsLibraryView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var query = ""

    var body: some View {
        let used = Set(store.list("religions").flatMap { $0.strings("basedOn") }.compactMap { $0.split(separator: ":").first.map(String.init) })
        let families = store.ref.religions.reduce(into: [String]()) { acc, r in if !acc.contains(r.family) { acc.append(r.family) } }
        List {
            Section {
                Text("\(store.ref.religions.count) real religions and philosophies with their prominent branches. These are living traditions held by real people — use them to understand, to portray respectfully, or to inspire something new.")
                    .foregroundColor(.secondary)
            }
            ForEach(families, id: \.self) { fam in
                let rs = store.ref.religions.filter { r in
                    r.family == fam && (query.isEmpty || (r.name + " " + r.branches.map { $0.name }.joined(separator: " ")).localizedCaseInsensitiveContains(query))
                }
                if !rs.isEmpty {
                    Section(fam) {
                        ForEach(rs) { r in
                            NavigationLink(value: Route.faith(r.id)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(r.name).font(.headline)
                                        if used.contains(r.id) { Image(systemName: "checkmark.seal.fill").foregroundColor(.wowGoldDeep) }
                                    }
                                    Text(r.origin + (r.living ? "" : " · historical")).font(.caption).foregroundColor(.secondary)
                                    if !r.branches.isEmpty { Text(r.branches.map { $0.name }.joined(separator: " · ")).font(.caption).lineLimit(2) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Filter faiths and branches")
        .navigationTitle("Faiths Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let e = store.newEntity("religions")
                    router.push(.entity("religions", e.id))
                } label: { Label("Create your own faith", systemImage: "plus") }
            }
        }
    }
}

struct FaithDetailView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let faithID: String

    var body: some View {
        if let r = store.ref.religions.first(where: { $0.id == faithID }) {
            List {
                Section {
                    Text(r.family.uppercased()).font(.caption.weight(.bold)).foregroundColor(.wowGoldDeep)
                    Text(r.origin + (r.living ? "" : " · historical")).foregroundColor(.secondary)
                    Label(r.care, systemImage: "hand.raised").foregroundColor(.wowGoldDeep)
                    Button { make(r.id, "Faith inspired by \(r.name)") } label: { Label("Faith based on this", systemImage: "plus.circle.fill") }
                        .buttonStyle(.borderedProminent).tint(.wowGold).foregroundColor(.wowVioletDeep)
                }
                Section("Key ideas") { ForEach(r.concepts, id: \.self) { Text($0) } }
                if !r.branches.isEmpty {
                    Section("Prominent branches") {
                        ForEach(r.branches) { b in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(b.name).font(.headline)
                                    Text(b.note).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Use") { make(b.id, b.name) }.buttonStyle(.bordered)
                            }
                        }
                    }
                }
                Section("Where it lives") {
                    ForEach(r.regions, id: \.self) { pid in
                        NavigationLink(value: Route.culture(pid)) { Text(store.ref.culture(pid)?.region ?? pid) }
                    }
                }
                if !r.sources.isEmpty { Section("Read & listen") { ForEach(r.sources, id: \.self) { Text($0) } } }
                let mine = store.list("religions").filter { $0.strings("basedOn").contains { $0.split(separator: ":").first.map(String.init) == r.id } }
                Section("Your faiths drawing on it") {
                    if mine.isEmpty { Text("None yet.").foregroundColor(.secondary) }
                    ForEach(mine) { EntityRow(col: "religions", entity: $0) }
                }
            }
            .navigationTitle(r.name)
        } else {
            Text("Unknown faith.")
        }
    }

    private func make(_ basedOn: String, _ name: String) {
        let e = store.newEntity("religions", ["name": .string(name), "kind": .string("inspired by real faiths"), "basedOn": .strings([basedOn])])
        router.push(.entity("religions", e.id))
    }
}

// MARK: - Languages library

struct LanguagesLibraryView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var query = ""

    var body: some View {
        List {
            Section {
                Text("\(store.ref.languageFamilies.reduce(0) { $0 + $1.languages.count }) real languages in \(store.ref.languageFamilies.count) families, plus writing systems and features to build your own.")
                    .foregroundColor(.secondary)
            }
            if query.isEmpty {
                Section("Features to design with") {
                    ForEach(store.ref.langFeatures) { f in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.name).font(.headline)
                            Text(f.description).font(.callout)
                            Text("e.g. " + f.examples).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                Section("Writing systems") {
                    ForEach(store.ref.writingSystems) { w in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.name)
                            Text("\(w.type) · \(w.used)").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            ForEach(store.ref.languageFamilies) { f in
                let ls = f.languages.filter { query.isEmpty || ($0.name + " " + f.name).localizedCaseInsensitiveContains(query) }
                if !ls.isEmpty {
                    Section(f.name) {
                        ForEach(ls) { l in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l.name).font(.headline)
                                    let details = [l.status, l.features.map { store.refData.label("langFeatures", $0) }.joined(separator: ", "), l.scripts.map { store.refData.label("writing", $0) }.joined(separator: ", ")]
                                    Text(details.filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Inspire") {
                                    let e = store.newEntity("languages", ["kind": .string("conlang inspired by real languages"), "basedOn": .strings([l.id]), "features": .strings(l.features), "scripts": .strings(l.scripts)])
                                    router.push(.entity("languages", e.id))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Filter languages")
        .navigationTitle("Languages Library")
    }
}

// MARK: - Power concepts (shown on the Power Systems list)

struct PowerRootsSection: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    var body: some View {
        DisclosureGroup("Real-world power concepts to start from") {
            ForEach(store.ref.powerArchetypes) { a in
                VStack(alignment: .leading, spacing: 4) {
                    Text(a.name).font(.headline)
                    Text(a.roots).font(.caption).foregroundColor(.secondary)
                    Text(a.summary).font(.callout)
                    (Text("Structure: ").bold() + Text(a.structure)).font(.caption)
                    (Text("Ask: ").bold() + Text(a.prompts)).font(.caption)
                    if !a.care.isEmpty { Text("Care: " + a.care).font(.caption).foregroundColor(.wowGoldDeep) }
                    Button("Start a system from this") {
                        let e = store.newEntity("powerSystems", ["archetypes": .strings([a.id]), "source": .string(a.summary)])
                        router.push(.entity("powerSystems", e.id))
                    }
                    .font(.callout)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Atlas extras

struct AtlasExtras: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let pool: CulturePool

    var body: some View {
        if let peoples = pool.peopleList {
            Section("Peoples (\(peoples.count)) — tap to create") {
                FlowLayout {
                    ForEach(peoples) { x in
                        let used = store.list("cultures").contains { $0.strings("realPeoples").contains(x.id) }
                        Button {
                            let e = store.newEntity("cultures", ["name": .string(x.name), "kind": .string("real people (portrayed respectfully)"), "realPeoples": .strings([x.id]), "cultures": .strings([pool.id])])
                            router.push(.entity("cultures", e.id))
                        } label: { Chip(text: x.name, gold: used) }
                        .buttonStyle(.plain)
                    }
                }
                Text("A starting index — far from complete. Add any people you research to your own Peoples & Cultures.").font(.caption).foregroundColor(.secondary)
            }
        }
        let faiths = store.ref.religions.filter { $0.regions.contains(pool.id) }
        if !faiths.isEmpty {
            Section("Faiths present") {
                ForEach(faiths) { r in NavigationLink(value: Route.faith(r.id)) { Text(r.name) } }
            }
        }
        let langs = store.ref.languageFamilies.flatMap { f in f.languages.filter { $0.regions.contains(pool.id) } }
        if !langs.isEmpty {
            Section("Languages") { Text(langs.map { $0.name }.joined(separator: " · ")).font(.callout) }
        }
        let zones = store.ref.contactZones.filter { $0.connects.contains(pool.id) }
        if !zones.isEmpty {
            Section("Contact zones") {
                ForEach(zones) { z in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(z.name).font(.headline) + Text(" · " + z.era).font(.caption)
                        Text(z.flows).font(.callout)
                        Text("Connects: " + z.connects.filter { $0 != pool.id }.map { store.ref.culture($0)?.region ?? $0 }.joined(separator: ", ")).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - World coverage & gaps

struct CoverageView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    private func usage() -> [String: (direct: Int, via: Int)] {
        var use: [String: (direct: Int, via: Int)] = [:]
        for p in store.ref.culturePools { use[p.id] = (0, 0) }
        for c in store.ref.collections {
            let fields = c.fields.filter { $0.type == "cultures" }
            for e in store.list(c.id) { for f in fields { for pid in e.strings(f.key) { use[pid]?.direct += 1 } } }
        }
        // Peoples count toward the pool that lists them (ids keep their old prefix when a people moves pools).
        var poolOf: [String: String] = [:]
        for p in store.ref.culturePools { for x in p.peopleList ?? [] { poolOf[x.id] = p.id } }
        for e in store.list("cultures") { for id in e.strings("realPeoples") { if let pid = poolOf[id] ?? id.split(separator: ":").first.map(String.init) { use[pid]?.via += 1 } } }
        for e in store.list("religions") { for id in e.strings("basedOn") { for pid in store.refData.religion(id).religion?.regions ?? [] { use[pid]?.via += 1 } } }
        for e in store.list("languages") { for id in e.strings("basedOn") { for pid in store.refData.language(id).language?.regions ?? [] { use[pid]?.via += 1 } } }
        // Lore lists (mythic beings, wars…) count toward the region their group belongs to.
        var lorePools: [String: [String]] = [:]
        for s in LoreSource.all { for e in store.loreEntries(s.id) where !e.pools.isEmpty { lorePools[e.item.id] = e.pools } }
        var counted = Set<String>()
        for s in LoreSource.all {
            for u in s.uses {
                for e in store.list(u[0]) {
                    for id in e.strings(u[1]) where counted.insert("\(u[0])/\(u[1])/\(e.id)/\(id)").inserted {
                        for pid in lorePools[id] ?? [] { use[pid]?.via += 1 }
                    }
                }
            }
        }
        return use
    }

    var body: some View {
        let use = usage()
        let used: (String) -> Bool = { (use[$0]?.direct ?? 0) + (use[$0]?.via ?? 0) > 0 }
        let gaps = store.ref.contactZones.filter { z in z.connects.contains(where: used) && z.connects.contains { !used($0) } }
        let bridges = store.ref.contactZones.filter { z in z.connects.filter(used).count >= 2 && !z.connects.contains { !used($0) } }
        let region: (String) -> String = { store.ref.culture($0)?.region ?? $0 }
        let famUsed = Set(store.list("religions").flatMap { $0.strings("basedOn") }.compactMap { store.refData.religion($0).religion?.family })
        let langFamUsed = Set(store.list("languages").flatMap { $0.strings("basedOn") }.compactMap { $0.split(separator: ":").first.map(String.init) })
        let archUsed = Set((store.list("abilities") + store.list("powerSystems")).flatMap { $0.strings("archetypes") })
        let families = Array(Set(store.ref.religions.map { $0.family })).sorted()
        List {
            Section {
                Text("Which parts of the real world your fiction draws on, and where history suggests natural connections you haven't made yet. Gaps aren't quotas — write what you can research well and portray with care.")
                    .foregroundColor(.secondary)
                meter("Regions drawn on", store.ref.culturePools.filter { used($0.id) }.count, store.ref.culturePools.count)
                meter("Faith families", famUsed.count, families.count)
                meter("Language families", langFamUsed.count, store.ref.languageFamilies.count)
                meter("Power concepts", archUsed.count, store.ref.powerArchetypes.count)
            }
            Section("Natural gaps") {
                if gaps.isEmpty { Text("Tag characters, abilities, peoples and places with regions to find gaps.").foregroundColor(.secondary) }
                ForEach(gaps) { z in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(z.name).font(.headline) + Text(" · " + z.era).font(.caption)
                        Text("You draw on \(z.connects.filter(used).map(region).joined(separator: ", ")) — but not \(z.connects.filter { !used($0) }.map(region).joined(separator: ", ")).").font(.callout)
                        (Text("What flowed: ").italic() + Text(z.flows)).font(.caption)
                        (Text("Story hook: ").italic() + Text(z.hook)).font(.caption)
                    }
                    .listRowBackground(Color.wowGold.opacity(0.12))
                }
            }
            if !bridges.isEmpty {
                Section("Bridges you can use") {
                    ForEach(bridges) { z in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(z.name).font(.headline)
                            Text(z.connects.filter(used).map(region).joined(separator: " ⇄ ")).font(.callout)
                            (Text("Story hook: ").italic() + Text(z.hook)).font(.caption)
                        }
                    }
                }
            }
            Section("Regions") {
                ForEach(store.ref.culturePools) { p in
                    NavigationLink(value: Route.culture(p.id)) {
                        HStack {
                            Text(p.region)
                            Spacer()
                            Text("\(use[p.id]?.direct ?? 0) tagged · \(use[p.id]?.via ?? 0) via").font(.caption).foregroundColor(.secondary)
                            if !used(p.id) { Chip(text: "gap") }
                        }
                    }
                }
            }
            Section("Not yet drawn on") {
                Text("Faith families: " + families.filter { !famUsed.contains($0) }.joined(separator: ", ")).font(.callout)
                Text("Language families: " + store.ref.languageFamilies.filter { !langFamUsed.contains($0.id) }.map { $0.name }.joined(separator: ", ")).font(.callout)
                Text("Power concepts: " + store.ref.powerArchetypes.filter { !archUsed.contains($0.id) }.map { $0.name }.joined(separator: ", ")).font(.callout)
            }
        }
        .navigationTitle("World Coverage & Gaps")
    }

    private func meter(_ label: String, _ a: Int, _ b: Int) -> some View {
        VStack(alignment: .leading) {
            HStack { Text(label); Spacer(); Text("\(a) / \(b)").bold() }
            ProgressView(value: Double(a), total: Double(max(b, 1))).tint(.wowGold)
        }
    }
}
