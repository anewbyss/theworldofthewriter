import Foundation

/// Continuity rules — mirrors web/js/continuity.js.
struct ContinuityIssue: Identifiable {
    enum Level: Int { case bad = 0, warn = 1, info = 2 }
    let id = UUID()
    let level: Level
    let message: String
    let refs: [(col: String, id: String)]
}

func fmt(_ n: Double) -> String { n == n.rounded() && abs(n) < 1e15 ? String(Int(n)) : String(n) }

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

        // 4. Places across time and space.
        var places: [String: Entity] = [:]
        for p in store.list("places") { places[p.id] = p }
        func pname(_ p: Entity?) -> String { (p?.string("name") ?? "").isEmpty ? "Unnamed place" : p!.string("name") }
        func isWithin(_ child: String, _ parent: String) -> Bool {
            var id = places[child]?.string("parent")
            var depth = 0
            while let c = id, !c.isEmpty, depth < 25 {
                if c == parent { return true }
                id = places[c]?.string("parent")
                depth += 1
            }
            return false
        }
        var atSeq: [String: (place: String, ev: Entity)] = [:]
        for ev in orderedEvents(store) {
            guard let seq = ev.number("sequence"), let p = places[ev.string("place")] else { continue }
            let title = ev.string("title").isEmpty ? "Untitled" : ev.string("title")
            if let from = p.number("existsFrom"), seq < from {
                push(.warn, "\"\(title)\" happens at \(pname(p)) (order \(fmt(seq))) before it exists (from \(fmt(from))).", [("events", ev.id), ("places", p.id)])
            }
            if let to = p.number("existsTo"), seq > to {
                push(.warn, "\"\(title)\" happens at \(pname(p)) (order \(fmt(seq))) after it's gone (until \(fmt(to))).", [("events", ev.id), ("places", p.id)])
            }
            for cid in ev.strings("characters") {
                let key = "\(cid)|\(seq)"
                if let prev = atSeq[key] {
                    if prev.place != p.id && !isWithin(prev.place, p.id) && !isWithin(p.id, prev.place), let c = chars[cid] {
                        let prevTitle = prev.ev.string("title").isEmpty ? "Untitled" : prev.ev.string("title")
                        push(.bad, "\(name(c)) is in two places at once (order \(fmt(seq))): \(pname(places[prev.place])) in \"\(prevTitle)\" and \(pname(p)) in \"\(title)\".", [("characters", cid), ("events", prev.ev.id), ("events", ev.id)])
                    }
                } else {
                    atSeq[key] = (p.id, ev)
                }
            }
        }
        for p in store.list("places") {
            var id = p.string("parent")
            var depth = 0
            while !id.isEmpty && depth < 25 {
                if id == p.id {
                    push(.warn, "\(pname(p)) ends up inside itself — check its parent places.", [("places", p.id)])
                    break
                }
                id = places[id]?.string("parent") ?? ""
                depth += 1
            }
            if let par = places[p.string("parent")], let parTo = par.number("existsTo"), let from = p.number("existsFrom"), from > parTo {
                push(.info, "\(pname(p)) starts (\(fmt(from))) after the place it lies within, \(pname(par)), is gone (\(fmt(parTo))).", [("places", p.id), ("places", par.id)])
            }
        }
        for m in store.list("maps") {
            let ef = m.number("eraFrom"), et = m.number("eraTo")
            if ef == nil && et == nil { continue }
            for f in store.mapCanvas(m).features {
                guard let pid = f.placeId, let p = places[pid] else { continue }
                let from = f.from ?? p.number("existsFrom"), to = f.to ?? p.number("existsTo")
                let startsInTime = from == nil || et == nil || from! <= et!
                let endsInTime = to == nil || ef == nil || to! >= ef!
                if !(startsInTime && endsInTime) {
                    let mt = m.string("title").isEmpty ? "Untitled" : m.string("title")
                    push(.info, "Map \"\(mt)\" shows \(pname(p)), which doesn't exist during the map's era.", [("maps", m.id), ("places", p.id)])
                }
            }
        }

        // 5. Families, lineages and powers.
        var abilities: [String: Entity] = [:]
        for a in store.list("abilities") { abilities[a.id] = a }
        var systems: [String: Entity] = [:]
        for s in store.list("powerSystems") { systems[s.id] = s }
        var lineages: [String: Entity] = [:]
        for l in store.list("lineages") { lineages[l.id] = l }
        func aname(_ a: Entity?) -> String { (a?.string("name") ?? "").isEmpty ? "Untitled ability" : a!.string("name") }
        func ancestors(_ cid: String) -> Set<String> {
            var out = Set<String>()
            var stack = chars[cid]?.strings("parents") ?? []
            while let p = stack.popLast() {
                if out.contains(p) || chars[p] == nil { continue }
                out.insert(p)
                stack.append(contentsOf: chars[p]?.strings("parents") ?? [])
            }
            return out
        }
        var birth: [String: Double] = [:]
        for ev in orderedEvents(store) where ev.string("type") == "birth" {
            guard let s = ev.number("sequence") else { continue }
            for cid in ev.strings("characters") where birth[cid] == nil { birth[cid] = s }
        }
        for c in store.list("characters") {
            let anc = ancestors(c.id)
            if anc.contains(c.id) {
                push(.bad, "\(name(c)) is their own ancestor — check the parent links.", [("characters", c.id)])
            }
            for pid in c.strings("parents") {
                if let pb = birth[pid], let cb = birth[c.id], pb >= cb, let p = chars[pid] {
                    push(.warn, "\(name(c)) is born (order \(fmt(cb))) no later than their parent \(name(p)) (order \(fmt(pb))).", [("characters", c.id), ("characters", pid)])
                }
            }
            let held = c.strings("abilities")
            for aid in held {
                guard let a = abilities[aid] else { continue }
                for pre in a.strings("prerequisites") where abilities[pre] != nil && !held.contains(pre) {
                    push(.warn, "\(name(c)) has \(aname(a)) but not its prerequisite \(aname(abilities[pre])).", [("characters", c.id), ("abilities", aid), ("abilities", pre)])
                }
                if let lin = lineages[a.string("lineage")], !c.strings("lineages").contains(lin.id) {
                    let fromKin = anc.contains { chars[$0]?.strings("lineages").contains(lin.id) ?? false }
                    let fromTeacher = c.strings("teachers").contains { t in
                        (chars[t]?.strings("lineages").contains(lin.id) ?? false) || (chars[t]?.strings("abilities").contains(aid) ?? false)
                    }
                    if !fromKin && !fromTeacher {
                        let ln = lin.string("name").isEmpty ? "a lineage" : lin.string("name")
                        push(.info, "\(name(c)) holds \(aname(a)), which passes down through \(ln), but has no tie to that lineage (membership, ancestor or teacher).", [("characters", c.id), ("abilities", aid), ("lineages", lin.id)])
                    }
                }
            }
        }
        for a in store.list("abilities") {
            var seenPre = Set<String>()
            var stack = a.strings("prerequisites")
            while let x = stack.popLast() {
                if x == a.id {
                    push(.warn, "\(aname(a)) ends up requiring itself — check its prerequisites.", [("abilities", a.id)])
                    break
                }
                if seenPre.contains(x) || abilities[x] == nil { continue }
                seenPre.insert(x)
                stack.append(contentsOf: abilities[x]?.strings("prerequisites") ?? [])
            }
            if let sys = systems[a.string("system")], !a.string("rank").isEmpty {
                let ranks = sys.string("ranks").split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
                let rank = a.string("rank").trimmingCharacters(in: .whitespaces).lowercased()
                if !ranks.isEmpty && !ranks.contains(rank) {
                    let sn = sys.string("name").isEmpty ? "its system" : sys.string("name")
                    push(.info, "\(aname(a)) has rank \"\(a.string("rank"))\", which isn't one of \(sn)'s ranks (\(ranks.joined(separator: ", "))).", [("abilities", a.id), ("powerSystems", sys.id)])
                }
            }
        }
        for l in store.list("lineages") {
            if let f = chars[l.string("founder")], !f.strings("lineages").contains(l.id) {
                let ln = l.string("name").isEmpty ? "a lineage" : l.string("name")
                push(.info, "\(name(f)) founded \(ln) but isn't listed as a member of it.", [("lineages", l.id), ("characters", f.id)])
            }
        }
        for col in ["powerSystems", "religions", "languages", "cultures"] {
            var items: [String: Entity] = [:]
            for x in store.list(col) { items[x.id] = x }
            for x in store.list(col) {
                var id = x.string("parent")
                var depth = 0
                while !id.isEmpty && depth < 25 {
                    if id == x.id {
                        let n = x.string("name").isEmpty ? "An entry" : x.string("name")
                        push(.warn, "\(n) ends up as its own ancestor — check its “parent”.", [(col, x.id)])
                        break
                    }
                    id = items[id]?.string("parent") ?? ""
                    depth += 1
                }
            }
        }

        // 6. Duplicate names.
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
        dupes("places", "name")
        for col in ["powerSystems", "lineages", "cultures", "religions", "languages"] { dupes(col, "name") }

        // 7. Loose threads.
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
