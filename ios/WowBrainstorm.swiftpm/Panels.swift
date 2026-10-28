import SwiftUI

struct OriginalityPanel: View {
    @EnvironmentObject var store: Store
    let col: String
    let id: String
    @State private var result: OriginalityResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Compares this entry with ~80 common tropes and your own work. A heuristic, not legal advice.")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("Check") { result = store.checkOriginality(col, id) }
                    .buttonStyle(.borderedProminent).tint(.wowGold).foregroundColor(.wowVioletDeep)
            }
            if let r = result { OriginalityResultView(result: r) }
        }
    }
}

struct OriginalityResultView: View {
    @EnvironmentObject var router: Router
    let result: OriginalityResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let score = result.score {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(score)").font(.system(size: 44, weight: .bold, design: .serif))
                    Spacer()
                    Text(result.label).font(.headline)
                }
                ProgressView(value: Double(score), total: 100).tint(.wowGold)
            } else {
                Text(result.label).foregroundColor(.secondary)
            }
            ForEach(result.representation) { m in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Representation check: \(m.trope.name)").font(.subheadline.weight(.semibold))
                    if let note = m.trope.note { Text(note).font(.caption) }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.12)))
            }
            if !result.tropeMatches.isEmpty {
                Text("Close to familiar tropes").font(.subheadline.weight(.semibold))
                ForEach(result.tropeMatches) { m in
                    HStack(alignment: .top) {
                        Chip(text: "\(Int((m.sim * 100).rounded()))%")
                        VStack(alignment: .leading) {
                            Text(m.trope.name)
                            if !m.matched.isEmpty { Text("matched: " + m.matched.joined(separator: ", ")).font(.caption).foregroundColor(.secondary) }
                        }
                    }
                }
            }
            if !result.ownMatches.isEmpty {
                Text("Echoes of your own entries").font(.subheadline.weight(.semibold))
                ForEach(result.ownMatches) { m in
                    HStack(alignment: .top) {
                        Chip(text: "\(Int((m.sim * 100).rounded()))%")
                        VStack(alignment: .leading) {
                            Button(m.label) { router.push(.entity(m.col, m.entityID)) }.buttonStyle(.borderless)
                            if !m.shared.isEmpty { Text("shared: " + m.shared.joined(separator: ", ")).font(.caption).foregroundColor(.secondary) }
                        }
                    }
                }
            }
            Text("Ways to twist it").font(.subheadline.weight(.semibold))
            ForEach(result.suggestions, id: \.self) { s in
                Label(s, systemImage: "arrow.triangle.turn.up.right.diamond").font(.callout)
            }
        }
    }
}

struct ConnectionsPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let col: String
    let id: String
    @State private var label = ""
    @State private var targetCol = "characters"
    @State private var targetID = ""

    var body: some View {
        let me = "\(col):\(id)"
        let links = store.list("links").filter { $0.string("from") == me || $0.string("to") == me }
        if links.isEmpty {
            Text("No connections yet.").foregroundColor(.secondary)
        }
        ForEach(links) { l in
            let outgoing = l.string("from") == me
            let other = outgoing ? l.string("to") : l.string("from")
            HStack {
                Image(systemName: outgoing ? "arrow.right" : "arrow.left").foregroundColor(.wowGoldDeep)
                Text(l.string("label").isEmpty ? "linked" : l.string("label")).italic()
                if let parts = splitRef(other) {
                    Button(store.title(ref: other)) { router.push(.entity(parts.0, parts.1)) }.buttonStyle(.borderless)
                }
                Spacer()
                Button("Edit") { router.push(.entity("links", l.id)) }.buttonStyle(.borderless).font(.caption)
            }
        }
        DisclosureGroup("Add connection") {
            TextField("Relationship (rival, teacher of, inspired by…)", text: $label)
            Picker("Type", selection: $targetCol) {
                ForEach(store.ref.collections.filter { $0.id != "links" }) { c in Text(c.singular).tag(c.id) }
            }
            Picker("Entry", selection: $targetID) {
                Text("—").tag("")
                ForEach(store.options(targetCol).filter { $0.id != id }) { o in Text(o.label).tag(o.id) }
            }
            Button("Connect") {
                guard !targetID.isEmpty else { return }
                store.create("links", [
                    "from": .string(me),
                    "to": .string("\(targetCol):\(targetID)"),
                    "label": .string(label.isEmpty ? "connected to" : label),
                ])
                label = ""
                targetID = ""
            }
            .disabled(targetID.isEmpty)
        }
        .onChange(of: targetCol) { _ in targetID = "" }
    }
}

struct AppearancesPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let characterID: String

    var body: some View {
        let c = store.get("characters", characterID)
        let works = (c?.strings("works") ?? []).compactMap { store.get("works", $0) }
            .sorted { ($0.number("order") ?? 1e9) < ($1.number("order") ?? 1e9) }
        let events = Continuity.orderedEvents(store).filter { $0.strings("characters").contains(characterID) }
        if works.isEmpty && events.isEmpty {
            Text("Not in any work or timeline event yet.").foregroundColor(.secondary)
        }
        ForEach(works) { w in
            Button {
                router.push(.entity("works", w.id))
            } label: {
                Label((w.number("order").map { "#\(Int($0)) " } ?? "") + store.title("works", w), systemImage: "book")
            }
            .buttonStyle(.borderless)
        }
        ForEach(events) { ev in
            Button {
                router.push(.entity("events", ev.id))
            } label: {
                Label([ev.string("when"), ev.string("title"), ev.string("type") == "event" ? "" : ev.string("type")].filter { !$0.isEmpty }.joined(separator: " — "), systemImage: "calendar")
            }
            .buttonStyle(.borderless)
        }
    }
}
