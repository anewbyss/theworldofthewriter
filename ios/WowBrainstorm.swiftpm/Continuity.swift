import Foundation

/// Continuity rules — mirrors web/js/continuity.js.
struct ContinuityIssue: Identifiable {
    enum Level: Int { case bad = 0, warn = 1, info = 2 }
    let id = UUID()
    let level: Level
    let message: String
    let refs: [(col: String, id: String)]
}

enum Continuity {
    static func orderedEvents(_ store: Store) -> [Entity] {
        var workOrder: [String: Double] = [:]
        for w in store.list("works") { workOrder[w.id] = w.number("order") ?? 0 }
        return store.list("events").sorted { a, b in
            let sa = a.number("sequence") ?? .infinity
            let sb = b.number("sequence") ?? .infinity
            if sa != sb { return sa < sb }
            let wa = workOrder[a.string("work")] ?? 0
            let wb = workOrder[b.string("work")] ?? 0
            if wa != wb { return wa < wb }
            return a.string("createdAt") < b.string("createdAt")
        }
    }

    static func check(_ store: Store) -> [ContinuityIssue] {
        var issues: [ContinuityIssue] = []
        func push(_ level: ContinuityIssue.Level, _ msg: String, _ refs: [(col: String, id: String)]) {
            issues.append(ContinuityIssue(level: level, message: msg, refs: refs))
        }
        var chars: [String: Entity] = [:]
        for c in store.list("characters") { chars[c.id] = c }
        var works: [String: Entity] = [:]
        for w in store.list("works") { works[w.id] = w }
        func name(_ c: Entity) -> String { c.string("name").isEmpty ? "Unnamed character" : c.string("name") }

        // 1. Timeline life & death order.
        var dead: [String: Entity] = [:]
        var seen: [String: Entity] = [:]
        for ev in orderedEvents(store) {
            let type = ev.string("type")
            let title = ev.string("title")
            for cid in ev.strings("characters") {
                guard let c = chars[cid] else { continue }
                if type == "birth", let first = seen[cid] {
                    push(.warn, "\(name(c)) is born in \"\(title)\" but already appeared earlier in \"\(first.string("title"))\".", [("characters", cid), ("events", ev.id)])
                }
                if let d = dead[cid], type != "return", type != "transformation" {
                    push(.bad, "\(name(c)) appears in \"\(title)\" after dying in \"\(d.string("title"))\" with no return or transformation event between.", [("characters", cid), ("events", ev.id)])
                }
                if type == "death" { dead[cid] = ev }
                if type == "return" || type == "transformation" { dead[cid] = nil }
                if seen[cid] == nil { seen[cid] = ev }

                let ability = ev.string("ability")
                if type == "acquires ability", !ability.isEmpty, !c.strings("abilities").contains(ability) {
                    push(.info, "\(name(c)) acquires an ability in \"\(title)\" that isn't listed on their profile.", [("characters", cid), ("abilities", ability)])
                }
                let work = ev.string("work")
                if let w = works[work], !c.strings("works").contains(work) {
                    push(.info, "\(name(c)) is in \"\(title)\" (shown in \(w.string("title"))) but that work isn't in their media appearances.", [("characters", cid), ("works", work)])
                }
            }
        }

        // 2. Status vs. timeline.
        for c in store.list("characters") {
            let hasDeath = store.list("events").contains { $0.string("type") == "death" && $0.strings("characters").contains(c.id) }
            if c.string("status") == "dead" && !hasDeath {
                push(.info, "\(name(c)) is marked dead but has no death event on the timeline.", [("characters", c.id)])
            }
            if c.string("status") == "alive", let d = dead[c.id] {
                push(.warn, "\(name(c)) is marked alive but the timeline ends with their death in \"\(d.string("title"))\".", [("characters", c.id), ("events", d.id)])
            }
        }

        // 3. Storylines vs. media appearances.
        for s in store.list("storylines") {
            let work = s.string("work")
            guard let w = works[work] else { continue }
            for cid in s.strings("characters") {
                if let c = chars[cid], !c.strings("works").contains(work) {
                    let st = s.string("title").isEmpty ? "Untitled" : s.string("title")
                    push(.info, "\(name(c)) is in storyline \"\(st)\" for \(w.string("title")), but that work isn't in their media appearances.", [("characters", cid), ("storylines", s.id)])
                }
            }
        }

        // 4. Duplicate names.
        func dupes(_ col: String, _ field: String) {
            var seenNames: [String: String] = [:]
            for e in store.list(col) {
                let n = e.string(field).trimmingCharacters(in: .whitespaces).lowercased()
                if n.isEmpty { continue }
                if let other = seenNames[n] {
                    push(.warn, "Two \(col) share the name \"\(e.string(field))\".", [(col, other), (col, e.id)])
                } else {
                    seenNames[n] = e.id
                }
            }
        }
        dupes("characters", "name")
        dupes("abilities", "name")
        dupes("works", "title")

        // 5. Loose threads.
        for c in store.list("characters") where c.strings("works").isEmpty {
            push(.info, "\(name(c)) doesn't appear in any book or media yet.", [("characters", c.id)])
        }
        let held = Set(store.list("characters").flatMap { $0.strings("abilities") })
        for a in store.list("abilities") where !held.contains(a.id) {
            let n = a.string("name").isEmpty ? "Untitled" : a.string("name")
            push(.info, "Ability \"\(n)\" isn't held by any character.", [("abilities", a.id)])
        }

        return issues.enumerated().sorted { l, r in
            l.element.level.rawValue != r.element.level.rawValue ? l.element.level.rawValue < r.element.level.rawValue : l.offset < r.offset
        }.map { $0.element }
    }
}
