import SwiftUI

/// Lands & stewards: who has lived on, cared for and ruled each land (mirrors web/js/lands.js).
extension Store {
    func stewardSpan(_ s: Steward) -> String {
        if s.ongoing == true { return "\(formatYear(s.start)) – today" }
        if let e = s.end { return "\(formatYear(s.start)) – \(formatYear(e))" }
        return formatYear(s.start)
    }

    func placesOnLand(_ id: String) -> [Entity] { list("places").filter { $0.strings("realLand").contains(id) } }

    /// Lore entries that mention the land by name: "Palestine / the Land of Israel" → Palestin, Israe.
    func landRelated(_ land: LandRef) -> [(LoreSource, [LoreEntry])] {
        let skip: Set<String> = ["Land", "Valley", "Islands", "Island", "Plain", "Highlands", "Central", "Great", "Black", "Hills", "Kingdom"]
        let words = land.name.components(separatedBy: CharacterSet(charactersIn: " /&(),"))
            .filter { w in w.count >= 4 && !skip.contains(w) && (w.first?.isUppercase ?? false) }
        let keys = Array(Set(words.map { String($0.prefix(max(4, $0.count - 1))) }))
        return LoreSource.all.filter { $0.id != "animals" && $0.id != "creatures" }.compactMap { s in
            let xs = loreEntries(s.id).filter { e in
                let text = "\(e.group.name) \(e.item.name) \(e.item.meta) \(e.item.note)"
                return keys.contains { text.contains($0) }
            }
            return xs.isEmpty ? nil : (s, xs)
        }
    }
}

struct LandsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var query = ""

    var body: some View {
        let q = query.lowercased()
        let lands = store.ref.lands.filter { l in q.isEmpty || "\(l.name) \(l.stewards.map { $0.name }.joined(separator: " "))".lowercased().contains(q) }
        let pools = lands.reduce(into: [String]()) { acc, l in if !acc.contains(l.pools.first ?? "") { acc.append(l.pools.first ?? "") } }
        List {
            Section {
                Text("\(store.ref.lands.count) lands traced through the peoples who lived on them, cared for them and ruled them — from Indigenous custodians tens of thousands of years ago to today's states.")
                    .font(.callout).foregroundColor(.secondary)
                Text("Stewardship is more than rule: many peoples cared for land long before, under and after the powers that claimed it. Overlapping bars are often the point — occupation, shared custody and contested claims. Dates are approximate.")
                    .font(.caption).foregroundColor(.wowGoldDeep)
            }
            ForEach(pools, id: \.self) { p in
                Section(store.ref.culture(p)?.region ?? p) {
                    ForEach(lands.filter { ($0.pools.first ?? "") == p }) { l in
                        Button { router.push(.land(l.id)) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(l.name).font(.headline)
                                    if !store.placesOnLand(l.id).isEmpty { Image(systemName: "checkmark.seal.fill").foregroundColor(.wowGold) }
                                }
                                Text(l.stewards.map { $0.name }.joined(separator: " → ")).font(.caption).foregroundColor(.secondary).lineLimit(3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Filter lands and stewards")
        .navigationTitle("Lands & Stewards")
    }
}

struct LandDetailView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let landID: String

    var body: some View {
        if let land = store.ref.lands.first(where: { $0.id == landID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(eyebrow: land.pools.map { store.ref.culture($0)?.region ?? $0 }.joined(separator: " · "), title: land.name, subtitle: land.summary.isEmpty ? nil : land.summary)
                    Button {
                        let made = store.newEntity("places", ["name": .string(land.name), "kind": .string("region"), "realLand": .strings([land.id]), "cultures": .strings(land.pools),
                                                              "history": .string(land.stewards.map { "\($0.name) (\(store.stewardSpan($0)))\($0.note.isEmpty ? "" : ": " + $0.note)" }.joined(separator: "\n"))])
                        router.push(.entity("places", made.id))
                    } label: { Label("Place based on this land", systemImage: "plus") }
                    .buttonStyle(.borderedProminent).tint(.wowGold).foregroundColor(.wowVioletDeep)
                    if !land.care.isEmpty {
                        Text("Care: " + land.care).font(.callout).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.wowGold.opacity(0.18)))
                    }
                    Card {
                        Text("Stewards across time").font(.headline)
                        Text("Gold bars continue today.").font(.caption).foregroundColor(.secondary)
                        ScrollView(.horizontal) { chart(land) }
                    }
                    Card {
                        Text("In order").font(.headline)
                        ForEach(land.stewards, id: \.self) { s in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name).font(.callout.weight(.semibold))
                                Text(store.stewardSpan(s)).font(.caption).foregroundColor(.wowGoldDeep)
                                if !s.note.isEmpty { Text(s.note).font(.caption).foregroundColor(.secondary) }
                            }
                            Divider()
                        }
                    }
                    Card {
                        Text("Your places drawing on it").font(.headline)
                        let mine = store.placesOnLand(land.id)
                        if mine.isEmpty { Text("None yet.").foregroundColor(.secondary) }
                        ForEach(mine) { p in Button(store.title("places", p)) { router.push(.entity("places", p.id)) } }
                    }
                    if !land.sources.isEmpty {
                        Card {
                            Text("Read further").font(.headline)
                            ForEach(land.sources, id: \.self) { Text("• " + $0).font(.callout) }
                        }
                    }
                    let related = store.landRelated(land)
                    if !related.isEmpty {
                        Card {
                            Text("In the libraries").font(.headline)
                            ForEach(related, id: \.0.id) { pair in
                                Label(pair.0.label, systemImage: pair.0.icon).font(.caption.weight(.bold)).padding(.top, 4)
                                FlowLayout {
                                    ForEach(pair.1) { e in Chip(text: e.item.name) }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(land.name)
        } else {
            Text("Unknown land.").foregroundColor(.secondary)
        }
    }

    private func chart(_ land: LandRef) -> some View {
        let lo = land.stewards.map { $0.start }.min() ?? 0
        let scale = lo < -6000 ? TimeScale(id: "land", label: "", lo: lo * 1.1, log: true) : TimeScale(id: "land", label: "", lo: lo - (currentYear - lo) * 0.03)
        let W: CGFloat = 900
        let row: CGFloat = 26
        return ZStack(alignment: .topLeading) {
            ForEach(Array(land.stewards.enumerated()), id: \.offset) { pair in
                let i = pair.offset
                let s = pair.element
                let x1 = CGFloat(scale.x(s.start)) * W
                let x2 = CGFloat(scale.x(s.ongoing == true ? currentYear : (s.end ?? s.start))) * W
                let bw = max(5, x2 - x1)
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(s.ongoing == true ? Color.wowGold : Color(hex: "#7A5C2E")).frame(width: bw, height: 16)
                    Text(s.name).font(.caption).lineLimit(1).fixedSize()
                }
                .offset(x: x1, y: CGFloat(i) * row)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(s.name), \(store.stewardSpan(s))")
            }
        }
        .frame(width: W + 260, height: CGFloat(land.stewards.count) * row, alignment: .topLeading)
    }
}
