import SwiftUI

// MARK: - Multi-type sides editor ("anyrefs")

struct AnyRefsEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let values: [String]
    let onChange: ([String]) -> Void
    @State private var col = "factions"

    private let allowed = ["characters", "factions", "cultures", "lineages", "religions", "places", "powerSystems"]

    var body: some View {
        ForEach(values, id: \.self) { ref in
            HStack {
                if let parts = splitRef(ref) {
                    Button(store.title(ref: ref)) { router.push(.entity(parts.0, parts.1)) }.buttonStyle(.borderless)
                    Text(store.def(parts.0)?.singular ?? parts.0).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button { onChange(values.filter { $0 != ref }) } label: { Image(systemName: "minus.circle.fill").foregroundColor(.red) }
                    .buttonStyle(.borderless)
            }
        }
        Picker("Type", selection: $col) {
            ForEach(store.ref.collections.filter { allowed.contains($0.id) }) { Text($0.singular).tag($0.id) }
        }
        Menu {
            ForEach(store.options(col).filter { !values.contains("\(col):\($0.id)") }) { o in
                Button(o.label) { onChange(values + ["\(col):\(o.id)"]) }
            }
            Divider()
            Button {
                let e = store.newEntity(col)
                onChange(values + ["\(col):\(e.id)"])
                router.push(.entity(col, e.id))
            } label: { Label("Create new \(store.def(col)?.singular.lowercased() ?? "entry")", systemImage: "plus") }
        } label: { Label("Add \(store.def(col)?.singular.lowercased() ?? "entry")", systemImage: "plus.circle") }
    }
}

// MARK: - Involvement

extension Store {
    /// How a character is part of a side entry ("col:id"), or nil.
    func involvement(_ c: Entity, _ ref: String) -> String? {
        guard let parts = splitRef(ref) else { return nil }
        let (col, id) = (parts.0, parts.1)
        switch col {
        case "characters": return id == c.id ? "directly" : nil
        case "factions":
            guard let f = get("factions", id) else { return nil }
            if f.strings("leaders").contains(c.id) { return "leads \(title("factions", f))" }
            if f.strings("members").contains(c.id) { return "member of \(title("factions", f))" }
            return nil
        case "cultures": return c.strings("peoples").contains(id) ? "one of the \(title("cultures", get("cultures", id)))" : nil
        case "lineages": return c.strings("lineages").contains(id) ? "of \(title("lineages", get("lineages", id)))" : nil
        case "religions": return c.strings("religions").contains(id) ? "follows \(title("religions", get("religions", id)))" : nil
        case "places": return c.string("homeland") == id ? "from \(title("places", get("places", id)))" : nil
        default: return nil
        }
    }

    func side(_ c: Entity, _ refs: [String]) -> String? { refs.lazy.compactMap { self.involvement(c, $0) }.first }
}

private struct RefChips: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let refs: [String]

    var body: some View {
        FlowLayout {
            ForEach(refs, id: \.self) { ref in
                if let p = splitRef(ref) {
                    Button { router.push(.entity(p.0, p.1)) } label: { Chip(text: "\(store.title(ref: ref)) · \(store.def(p.0)?.singular ?? p.0)", gold: true) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct Heading: View {
    let text: String
    var body: some View { Text(text).font(.subheadline.weight(.semibold)) }
}

// MARK: - Panels

struct ConflictPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let conflictID: String

    var body: some View {
        if let w = store.get("conflicts", conflictID) {
            let start = w.number("start"), end = w.number("end")
            let battles = Continuity.orderedEvents(store).filter { w.strings("battles").contains($0.id) }
            let subs = store.list("conflicts").filter { $0.string("parent") == w.id }
            let rivals = store.list("rivalries").filter { $0.strings("conflicts").contains(w.id) }
            Heading(text: "Side A")
            if w.strings("sideA").isEmpty { Text("—").foregroundColor(.secondary) } else { RefChips(refs: w.strings("sideA")) }
            Heading(text: "Side B")
            if w.strings("sideB").isEmpty { Text("—").foregroundColor(.secondary) } else { RefChips(refs: w.strings("sideB")) }
            if !w.strings("others").isEmpty { Heading(text: "Others"); RefChips(refs: w.strings("others")) }
            if let s = start {
                Text("In-world order \(fmt(s))" + (end.map { " – \(fmt($0))" } ?? " – ongoing") + (w.string("era").isEmpty ? "" : " · \(w.string("era"))"))
            } else {
                Text("Set ‘Began’ and ‘Ended’ to place it on the timeline.").foregroundColor(.secondary)
            }
            if let p = store.get("conflicts", w.string("parent")) {
                Button("Part of " + store.title("conflicts", p)) { router.push(.entity("conflicts", p.id)) }
            }
            if !subs.isEmpty {
                Heading(text: "Campaigns & sub-conflicts")
                ForEach(subs) { x in Button(store.title("conflicts", x)) { router.push(.entity("conflicts", x.id)) } }
            }
            Heading(text: "Battles & key events")
            if battles.isEmpty { Text("None linked yet.").foregroundColor(.secondary) }
            ForEach(battles) { ev in
                Button((ev.number("sequence").map { "#\(fmt($0)) " } ?? "") + store.title("events", ev) + (store.get("places", ev.string("place")).map { " at " + store.title("places", $0) } ?? "")) {
                    router.push(.entity("events", ev.id))
                }
            }
            Button {
                let ev = store.newEntity("events", ["type": .string("battle"), "sequence": start.map { JSONValue.number($0) } ?? .null])
                store.update("conflicts", w.id, "battles", .strings(w.strings("battles") + [ev.id]))
                router.push(.entity("events", ev.id))
            } label: { Label("Battle", systemImage: "plus") }
            if !rivals.isEmpty {
                Heading(text: "Rivalries behind it")
                ForEach(rivals) { r in Button(store.title("rivalries", r)) { router.push(.entity("rivalries", r.id)) } }
            }
            if w.string("kind") == "atrocity (handle with care)" {
                Text("Real atrocities: research carefully, centre survivors' voices, and avoid spectacle.").font(.caption).foregroundColor(.wowGoldDeep)
            }
        }
    }
}

struct RivalryPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let rivalryID: String

    var body: some View {
        if let r = store.get("rivalries", rivalryID) {
            let escalations = Continuity.orderedEvents(store).filter { r.strings("escalations").contains($0.id) || $0.id == r.string("originEvent") }
            let heirs = store.list("characters").filter { c in c.strings("lineages").contains { r.strings("inheritedBy").contains($0) } }
            Heading(text: "One side")
            RefChips(refs: r.strings("sideA"))
            Heading(text: "The other side")
            RefChips(refs: r.strings("sideB"))
            Text([r.string("kind"), r.string("intensity"), r.string("status")].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundColor(.secondary)
            Heading(text: "Escalation")
            if escalations.isEmpty { Text("Link an origin event and escalations to chart it.").foregroundColor(.secondary) }
            ForEach(escalations) { ev in
                Button(store.title("events", ev) + (ev.id == r.string("originEvent") ? " (origin)" : "")) { router.push(.entity("events", ev.id)) }
            }
            Button {
                let ev = store.newEntity("events")
                store.update("rivalries", r.id, "escalations", .strings(r.strings("escalations") + [ev.id]))
                router.push(.entity("events", ev.id))
            } label: { Label("Escalation", systemImage: "plus") }
            if !heirs.isEmpty {
                Heading(text: "Inherited by")
                ForEach(heirs) { c in Button(store.title("characters", c)) { router.push(.entity("characters", c.id)) } }
            }
        }
    }
}

struct FactionPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let factionID: String

    var body: some View {
        if let f = store.get("factions", factionID) {
            let me = "factions:\(f.id)"
            let wars = store.list("conflicts").filter { w in [w.strings("sideA"), w.strings("sideB"), w.strings("others")].contains { $0.contains(me) } }
            let rivals = store.list("rivalries").filter { r in [r.strings("sideA"), r.strings("sideB")].contains { $0.contains(me) } }
            let subs = store.list("factions").filter { $0.string("parent") == f.id }
            let oneSided = f.strings("allies").filter { store.get("factions", $0)?.strings("enemies").contains(f.id) ?? false }
            group("Leaders", "characters", f.strings("leaders"))
            group("Members", "characters", f.strings("members"))
            group("Territory", "places", (f.string("seat").isEmpty ? [] : [f.string("seat")]) + f.strings("territory"))
            group("Branches", "factions", subs.map { $0.id })
            group("Allies", "factions", f.strings("allies"))
            group("Enemies", "factions", f.strings("enemies"))
            if !oneSided.isEmpty {
                Text("One-sided alliance: \(oneSided.map { store.title("factions", store.get("factions", $0)) }.joined(separator: ", ")) counts this faction as an enemy.")
                    .font(.caption).foregroundColor(.wowGoldDeep)
            }
            group("Wars", "conflicts", wars.map { $0.id })
            group("Rivalries", "rivalries", rivals.map { $0.id })
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ col: String, _ ids: [String]) -> some View {
        if !ids.isEmpty {
            Heading(text: title)
            ForEach(ids, id: \.self) { id in Button(store.title(col, store.get(col, id))) { router.push(.entity(col, id)) } }
        }
    }
}

struct CharacterConflictPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let characterID: String

    var body: some View {
        if let c = store.get("characters", characterID) {
            let factions = store.list("factions").filter { $0.strings("leaders").contains(c.id) || $0.strings("members").contains(c.id) }
            let rivals = store.list("rivalries").compactMap { r -> (Entity, String)? in
                let inherited = c.strings("lineages").contains { r.strings("inheritedBy").contains($0) } ? "inherited" : nil
                guard let via = store.side(c, r.strings("sideA")) ?? store.side(c, r.strings("sideB")) ?? inherited else { return nil }
                return (r, via)
            }
            let wars = store.list("conflicts").compactMap { w -> (Entity, String)? in
                var roles: [String] = []
                if w.strings("leaders").contains(c.id) { roles.append("leader") }
                if w.strings("figures").contains(c.id) { roles.append("notable figure") }
                if let v = store.side(c, w.strings("sideA")) { roles.append("side A (\(v))") }
                else if let v = store.side(c, w.strings("sideB")) { roles.append("side B (\(v))") }
                else if let v = store.side(c, w.strings("others")) { roles.append("other party (\(v))") }
                return roles.isEmpty ? nil : (w, roles.joined(separator: ", "))
            }
            if !c.string("epithet").isEmpty || !c.string("renown").isEmpty {
                Text([c.string("epithet"), c.string("renown")].filter { !$0.isEmpty }.joined(separator: " · ")).italic()
            }
            if factions.isEmpty && rivals.isEmpty && wars.isEmpty { Text("Not part of any faction, rivalry or war yet.").foregroundColor(.secondary) }
            if !factions.isEmpty {
                Heading(text: "Factions")
                ForEach(factions) { f in Button(store.title("factions", f) + (f.strings("leaders").contains(c.id) ? " · leader" : "")) { router.push(.entity("factions", f.id)) } }
            }
            if !rivals.isEmpty {
                Heading(text: "Rivalries")
                ForEach(rivals, id: \.0.id) { r in Button("\(store.title("rivalries", r.0)) — \(r.1)") { router.push(.entity("rivalries", r.0.id)) } }
            }
            if !wars.isEmpty {
                Heading(text: "Wars & conflicts")
                ForEach(wars, id: \.0.id) { w in Button("\(store.title("conflicts", w.0)) — \(w.1)") { router.push(.entity("conflicts", w.0.id)) } }
            }
        }
    }
}

struct PlaceConflictPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let placeID: String

    var body: some View {
        let ref = "places:\(placeID)"
        let wars = store.list("conflicts").filter { $0.strings("places").contains(placeID) || $0.strings("sideA").contains(ref) || $0.strings("sideB").contains(ref) }
        let factions = store.list("factions").filter { $0.string("seat") == placeID || $0.strings("territory").contains(placeID) }
        if wars.isEmpty && factions.isEmpty { Text("No factions or conflicts here yet.").foregroundColor(.secondary) }
        ForEach(factions) { f in Button(store.title("factions", f) + (f.string("seat") == placeID ? " · seat" : "")) { router.push(.entity("factions", f.id)) } }
        ForEach(wars) { w in Button("⚔ " + store.title("conflicts", w)) { router.push(.entity("conflicts", w.id)) } }
    }
}

/// Conflicts as spans on the in-world timeline.
struct ConflictSpansView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    var body: some View {
        let wars = store.list("conflicts").filter { $0.number("start") != nil }.sorted { ($0.number("start") ?? 0) < ($1.number("start") ?? 0) }
        if !wars.isEmpty {
            let lo = wars.compactMap { $0.number("start") }.min() ?? 0
            let hiRaw = wars.map { $0.number("end") ?? $0.number("start") ?? 0 }.max() ?? 1
            let hi = max(hiRaw, lo + 1)
            ForEach(wars) { w in
                let s = w.number("start") ?? lo, e = w.number("end") ?? hi
                Button { router.push(.entity("conflicts", w.id)) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(store.title("conflicts", w))
                            Spacer()
                            Text(fmt(s) + "–" + (w.number("end").map { fmt($0) } ?? "")).font(.caption).foregroundColor(.secondary)
                        }
                        GeometryReader { geo in
                            let x = (s - lo) / (hi - lo) * geo.size.width
                            let width = max(4, (e - s) / (hi - lo) * geo.size.width)
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.wowVioletSoft.opacity(0.15))
                                Capsule()
                                    .fill(["ended", "remembered / mythic"].contains(w.string("status")) ? Color.wowVioletSoft : Color(hex: "#A23B3B"))
                                    .frame(width: width)
                                    .offset(x: x)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
    }
}

// MARK: - Notable figures

struct FiguresView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    private let renown = ["mythic", "legendary", "famous", "infamous", "regional", "local", "forgotten"]

    var body: some View {
        let chars = store.list("characters")
        let notable = chars.filter { renown.contains($0.string("renown")) }
        let active = Set(store.list("conflicts").flatMap { $0.strings("leaders") + $0.strings("figures") } + store.list("factions").flatMap { $0.strings("leaders") })
        let unranked = chars.filter { !renown.contains($0.string("renown")) && active.contains($0.id) }
        List {
            Section {
                Text("Heroes, rulers, rebels, martyrs and monsters — by renown, with the wars and factions that made their names.").foregroundColor(.secondary)
            }
            if notable.isEmpty {
                Text("Set a character's Renown (local, famous, legendary, infamous, mythic…) to see them here.").foregroundColor(.secondary)
            }
            ForEach(renown, id: \.self) { rn in
                let list = notable.filter { $0.string("renown") == rn }
                if !list.isEmpty {
                    Section(rn.capitalized) { ForEach(list) { figureRow($0) } }
                }
            }
            if !unranked.isEmpty {
                Section("In the thick of it (no renown set)") { ForEach(unranked) { figureRow($0) } }
            }
            Section("Real-world figures to research") {
                ForEach(store.ref.culturePools) { p in
                    DisclosureGroup(p.region) {
                        ForEach(p.figures, id: \.self) { f in
                            Button(f) {
                                store.create("research", ["title": .string(f), "kind": .string("other"), "cultures": .strings([p.id]), "notes": .string("Notable figure from \(p.region)."), "care": .string(p.care), "tags": .strings(["notable figure"])])
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Notable Figures")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let e = store.newEntity("characters", ["renown": .string("famous")])
                    router.push(.entity("characters", e.id))
                } label: { Label("New figure", systemImage: "plus") }
            }
        }
    }

    private func roles(_ c: Entity) -> [String] {
        store.list("conflicts").filter { $0.strings("leaders").contains(c.id) }.map { "led in \(store.title("conflicts", $0))" }
            + store.list("conflicts").filter { $0.strings("figures").contains(c.id) }.map { "figure of \(store.title("conflicts", $0))" }
            + store.list("factions").filter { $0.strings("leaders").contains(c.id) }.map { "leader of \(store.title("factions", $0))" }
    }

    private func figureRow(_ c: Entity) -> some View {
        NavigationLink(value: Route.entity("characters", c.id)) {
            HStack(spacing: 12) {
                PortraitView(params: PortraitParams(c["portrait"], spec: store.ref.portrait), spec: store.ref.portrait).frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.title("characters", c)).font(.headline)
                    if !c.string("epithet").isEmpty { Text(c.string("epithet")).italic().font(.callout) }
                    let r = roles(c)
                    if !r.isEmpty { Text(r.prefix(3).joined(separator: " · ")).font(.caption).foregroundColor(.secondary) }
                    if !c.string("legacy").isEmpty { Text(c.string("legacy")).font(.caption).lineLimit(2) }
                }
            }
        }
    }
}
