import Foundation

/// An entry from a built-in reference library, for "refdata" fields.
struct RefItem: Identifiable, Hashable {
    let id: String
    let label: String
    let hint: String
}

struct RefGroup: Identifiable {
    let group: String
    let items: [RefItem]
    var id: String { group }
}

/// Lookups into the reference libraries (mirrors web/js/refdata.js).
final class RefData {
    let ref: Reference
    private var cache: [String: [String: RefItem]] = [:]

    init(ref: Reference) { self.ref = ref }

    private func unique<T: Hashable>(_ xs: [T]) -> [T] {
        var seen = Set<T>()
        return xs.filter { seen.insert($0).inserted }
    }

    func groups(_ source: String) -> [RefGroup] {
        switch source {
        case "religions":
            return unique(ref.religions.map { $0.family }).map { fam in
                RefGroup(group: fam, items: ref.religions.filter { $0.family == fam }.flatMap { r in
                    [RefItem(id: r.id, label: r.name, hint: r.origin)] + r.branches.map { RefItem(id: $0.id, label: "\(r.name) — \($0.name)", hint: $0.note) }
                })
            }
        case "languages":
            return ref.languageFamilies.map { f in
                RefGroup(group: f.name, items: f.languages.map { RefItem(id: $0.id, label: $0.name, hint: [f.name, $0.status].filter { !$0.isEmpty }.joined(separator: " · ")) })
            }
        case "peoples":
            return ref.culturePools.compactMap { p -> RefGroup? in
                guard let list = p.peopleList else { return nil }
                return RefGroup(group: p.region, items: list.map { RefItem(id: $0.id, label: $0.name, hint: p.region) })
            }
        case "langFeatures":
            return [RefGroup(group: "Language features", items: ref.langFeatures.map { RefItem(id: $0.id, label: $0.name, hint: "\($0.description) e.g. \($0.examples)") })]
        case "writing":
            return unique(ref.writingSystems.map { $0.type }).map { t in
                RefGroup(group: t, items: ref.writingSystems.filter { $0.type == t }.map { RefItem(id: $0.id, label: $0.name, hint: $0.used) })
            }
        case "kinship":
            return [RefGroup(group: "Kinship & bond traditions", items: ref.kinshipTraditions.map { RefItem(id: $0.id, label: $0.name, hint: "\($0.roots). \($0.description)") })]
        case "powerArchetypes":
            return [RefGroup(group: "Real-world power concepts", items: ref.powerArchetypes.map { RefItem(id: $0.id, label: $0.name, hint: "\($0.roots). \($0.summary)") })]
        case "animals", "creatures", "wars", "rivalryLore", "mythHistory":
            return ref.lore(source).map { g in
                RefGroup(group: g.name, items: g.items.map { RefItem(id: $0.id, label: $0.name, hint: [$0.meta, $0.note].filter { !$0.isEmpty }.joined(separator: " — ")) })
            }
        default:
            return []
        }
    }

    func item(_ source: String, _ id: String) -> RefItem? {
        if cache[source] == nil {
            var m: [String: RefItem] = [:]
            for g in groups(source) { for it in g.items { m[it.id] = it } }
            cache[source] = m
        }
        return cache[source]?[id]
    }

    func label(_ source: String, _ id: String) -> String { item(source, id)?.label ?? id }

    func religion(_ id: String) -> (religion: ReligionRef?, branch: ReligionBranch?) {
        let rid = String(id.split(separator: ":").first ?? "")
        let r = ref.religions.first { $0.id == rid }
        return (r, r?.branches.first { $0.id == id })
    }

    func language(_ id: String) -> (family: LanguageFamily?, language: LanguageRef?) {
        let fid = String(id.split(separator: ":").first ?? "")
        let f = ref.languageFamilies.first { $0.id == fid }
        return (f, f?.languages.first { $0.id == id })
    }
}
