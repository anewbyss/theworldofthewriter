import SwiftUI

extension Store {
    /// Species of any being: characters can list several, companions have one.
    func speciesOf(_ e: Entity?) -> [String] {
        guard let e = e else { return [] }
        if let arr = e["species"].array { return arr.compactMap { $0.string } }
        let s = e.string("species")
        return s.isEmpty ? [] : [s]
    }

    /// Can these two have children together, by the writer's species rules?
    func compatible(_ a: Entity, _ b: Entity) -> Bool {
        let A = speciesOf(a), B = speciesOf(b)
        if A.isEmpty || B.isEmpty || A.contains(where: { B.contains($0) }) { return true }
        return A.contains { x in
            B.contains { y in
                (get("species", x)?.strings("interbreeds").contains(y) ?? false) || (get("species", y)?.strings("interbreeds").contains(x) ?? false)
            }
        }
    }

    /// Heredity traits that apply to these beings (a trait with no species applies to all).
    func traitsFor(_ beings: [Entity]) -> [Entity] {
        let sp = Set(beings.flatMap { speciesOf($0) })
        return list("traits").filter { $0.strings("species").isEmpty || $0.strings("species").contains { sp.contains($0) } }
    }
}

private struct Heading: View {
    let text: String
    var body: some View { Text(text).font(.subheadline.weight(.semibold)) }
}

struct SpeciesPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let speciesID: String

    var body: some View {
        if let s = store.get("species", speciesID) {
            let members = store.list("characters").filter { store.speciesOf($0).contains(s.id) }
            let pets = store.list("pets").filter { $0.string("species") == s.id }
            let subs = store.list("species").filter { $0.string("parent") == s.id }
            let back = store.list("species").filter { $0.id != s.id && $0.strings("interbreeds").contains(s.id) && !s.strings("interbreeds").contains($0.id) }
            Text([s.string("kind"), s.string("sapience"), s.number("lifespan").map { "lives ~\(fmt($0)) years" } ?? "", s.string("reproduction")].filter { !$0.isEmpty }.joined(separator: " · "))
            if let p = store.get("species", s.string("parent")) {
                Button("Variant of " + store.title("species", p)) { router.push(.entity("species", p.id)) }
            }
            rows("Subspecies & variants", "species", subs.map { $0.id })
            rows("Innate abilities", "abilities", s.strings("abilities"))
            rows("Can have children with", "species", s.strings("interbreeds") + back.map { $0.id })
            if members.isEmpty { Text("No characters of this species yet.").foregroundColor(.secondary) }
            rows("Characters", "characters", members.map { $0.id })
            rows("Companions", "pets", pets.map { $0.id })
            rows("Habitat", "places", s.strings("habitat"))
            rows("Peoples", "cultures", s.strings("peoples"))
        }
    }

    @ViewBuilder
    private func rows(_ title: String, _ col: String, _ ids: [String]) -> some View {
        if !ids.isEmpty {
            Heading(text: title)
            ForEach(Array(ids.enumerated()), id: \.offset) { _, id in Button(store.title(col, store.get(col, id))) { router.push(.entity(col, id)) } }
        }
    }
}

struct CharacterBeingPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let characterID: String

    var body: some View {
        if let c = store.get("characters", characterID) {
            let species = store.speciesOf(c).compactMap { store.get("species", $0) }
            let pets = store.list("pets").filter { $0.strings("bondedTo").contains(c.id) }
            let missing = species.flatMap { s in s.strings("abilities").filter { !c.strings("abilities").contains($0) } }
            let lifespans = species.compactMap { $0.number("lifespan") }.filter { $0 > 0 }
            if species.isEmpty { Text("No species set.").foregroundColor(.secondary) }
            ForEach(species) { s in Button(store.title("species", s) + (s.string("kind").isEmpty ? "" : " · " + s.string("kind"))) { router.push(.entity("species", s.id)) } }
            if let lo = lifespans.min(), let hi = lifespans.max() {
                Text(species.count > 1 ? "Mixed heritage — lifespan somewhere between \(fmt(lo)) and \(fmt(hi)) years." : "Typical lifespan ~\(fmt(lo)) years.")
                    .font(.caption).foregroundColor(.secondary)
            }
            if !missing.isEmpty {
                Heading(text: "Species gifts not yet on their profile")
                ForEach(Array(Set(missing)).sorted(), id: \.self) { a in
                    Button { store.update("characters", c.id, "abilities", .strings(c.strings("abilities") + [a])) } label: {
                        Label(store.title("abilities", store.get("abilities", a)), systemImage: "plus.circle")
                    }
                }
            }
            Heading(text: "Companions")
            if pets.isEmpty { Text("None yet.").foregroundColor(.secondary) }
            ForEach(pets) { p in
                Button { router.push(.entity("pets", p.id)) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.title("pets", p))
                        let info = [store.get("species", p.string("species")).map { store.title("species", $0) } ?? "", p.string("kind"), p.string("bond"), p.string("status") == "alive" ? "" : p.string("status")]
                        Text(info.filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            EntryPickerMenu(col: "pets", title: "Bond a companion", filter: { !$0.strings("bondedTo").contains(c.id) }) { p in
                store.addRef("pets", p.id, "bondedTo", c.id)
            }
        }
    }
}

struct PetPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let petID: String

    var body: some View {
        if let p = store.get("pets", petID) {
            let kids = store.list("pets").filter { $0.strings("parents").contains(p.id) }
            if let s = store.get("species", p.string("species")) {
                Button(store.title("species", s) + (s.number("lifespan").map { " · ~\(fmt($0)) years" } ?? "")) { router.push(.entity("species", s.id)) }
            } else {
                Text("No species set.").foregroundColor(.secondary)
            }
            if p.strings("bondedTo").isEmpty { Text("Not bonded to anyone yet.").foregroundColor(.secondary) }
            ForEach(p.strings("bondedTo"), id: \.self) { id in Button("Bonded to " + store.title("characters", store.get("characters", id))) { router.push(.entity("characters", id)) } }
            ForEach(p.strings("parents"), id: \.self) { id in Button("Parent: " + store.title("pets", store.get("pets", id))) { router.push(.entity("pets", id)) } }
            ForEach(kids) { k in Button("Offspring: " + store.title("pets", k)) { router.push(.entity("pets", k.id)) } }
            Button { router.push(.offspring(p.id)) } label: { Label("Breeding calculator with this companion", systemImage: "figure.and.child.holdinghands") }
        }
    }
}

struct PlaceBeingPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let placeID: String

    var body: some View {
        let species = store.list("species").filter { $0.strings("habitat").contains(placeID) }
        let pets = store.list("pets").filter { $0.string("home") == placeID }
        if species.isEmpty && pets.isEmpty { Text("No species or companions recorded here.").foregroundColor(.secondary) }
        ForEach(species) { s in Button("Lives here: " + store.title("species", s)) { router.push(.entity("species", s.id)) } }
        ForEach(pets) { p in Button("At home here: " + store.title("pets", p)) { router.push(.entity("pets", p.id)) } }
    }
}

struct SpeciesTemplatesSection: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    var body: some View {
        DisclosureGroup("Start from folklore") {
            Text("Starting points from real folklore. Read their traditions first, credit them, and make your version your own.")
                .font(.caption).foregroundColor(.secondary)
            ForEach(Array(store.ref.speciesTemplates.enumerated()), id: \.offset) { _, t in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t["name"]?.string ?? "Species").font(.headline)
                        Text(t["roots"]?.string ?? "").font(.caption)
                        if let care = t["care"]?.string { Text("Care: " + care).font(.caption).foregroundColor(.wowGoldDeep) }
                    }
                    Spacer()
                    Button("Start") {
                        let e = store.newEntity("species", t)
                        router.push(.entity("species", e.id))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
