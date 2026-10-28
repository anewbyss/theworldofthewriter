import Foundation

/// Originality checker — a transparent word-overlap heuristic, not AI.
/// Mirrors web/js/originality.js exactly so both apps give the same scores.
struct OriginalityResult {
    struct TropeMatch: Identifiable {
        let trope: Trope
        let sim: Double
        let matched: [String]
        var id: String { trope.id }
    }
    struct OwnMatch: Identifiable {
        let key: String
        let label: String
        let col: String
        let entityID: String
        let sim: Double
        let shared: [String]
        var id: String { key }
    }
    let score: Int?
    let label: String
    let tropeMatches: [TropeMatch]
    let representation: [TropeMatch]
    let ownMatches: [OwnMatch]
    let suggestions: [String]
}

struct OtherEntry {
    let col: String
    let entityID: String
    let label: String
    let text: String
}

enum Originality {
    static func stem(_ w: String) -> String {
        if w.count > 5 && w.hasSuffix("ing") { return String(w.dropLast(3)) }
        if w.count > 4 && w.hasSuffix("ed") { return String(w.dropLast(2)) }
        if w.count > 4 && w.hasSuffix("es") { return String(w.dropLast(2)) }
        if w.count > 3 && w.hasSuffix("s") && !w.hasSuffix("ss") { return String(w.dropLast(1)) }
        return w
    }

    static func tokens(_ text: String, stopwords: Set<String>) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stopwords.contains($0) }
            .map(stem)
    }

    static func bigrams(_ toks: [String]) -> Set<String> {
        var out = Set<String>()
        if toks.count > 1 {
            for i in 0..<(toks.count - 1) { out.insert(toks[i] + " " + toks[i + 1]) }
        }
        return out
    }

    static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        if a.isEmpty || b.isEmpty { return 0 }
        let inter = a.intersection(b).count
        return Double(inter) / Double(a.count + b.count - inter)
    }

    static func dice(_ a: Set<String>, _ b: Set<String>) -> Double {
        if a.isEmpty || b.isEmpty { return 0 }
        return 2 * Double(a.intersection(b).count) / Double(a.count + b.count)
    }

    static func check(_ text: String, others: [OtherEntry], ref: Reference) -> OriginalityResult {
        let stop = Set(ref.stopwords)
        let toks = tokens(text, stopwords: stop)
        let set = Set(toks)
        let grams = bigrams(toks)

        var tropeMatches: [OriginalityResult.TropeMatch] = []
        var representation: [OriginalityResult.TropeMatch] = []
        for t in ref.tropes {
            var hits = 0
            var matched: [String] = []
            for kw in t.keywords {
                let kt = tokens(kw, stopwords: stop)
                if !kt.isEmpty && kt.allSatisfy({ set.contains($0) }) {
                    hits += 1
                    matched.append(kw)
                }
            }
            let tropeTokens = Set(tokens(([t.name] + t.keywords).joined(separator: " "), stopwords: stop))
            let containment = tropeTokens.isEmpty ? 0 : Double(tropeTokens.intersection(set).count) / Double(tropeTokens.count)
            let kwScore = min(1, Double(hits) * 0.34)
            let sim = min(1, kwScore * 0.8 + containment * 0.4)
            let m = OriginalityResult.TropeMatch(trope: t, sim: sim, matched: matched)
            if t.kind == "representation" {
                if hits >= 2 || sim >= 0.4 { representation.append(m) }
            } else if sim >= 0.15 {
                tropeMatches.append(m)
            }
        }
        tropeMatches.sort { $0.sim > $1.sim }

        var own: [OriginalityResult.OwnMatch] = []
        for o in others {
            let ot = tokens(o.text, stopwords: stop)
            if ot.count < 3 { continue }
            let oset = Set(ot)
            let sim = 0.6 * jaccard(set, oset) + 0.4 * dice(grams, bigrams(ot))
            if sim >= 0.2 {
                var seen = Set<String>()
                let shared = ot.filter { set.contains($0) && seen.insert($0).inserted }.prefix(8)
                own.append(.init(key: "\(o.col):\(o.entityID)", label: o.label, col: o.col, entityID: o.entityID, sim: sim, shared: Array(shared)))
            }
        }
        own.sort { $0.sim > $1.sim }

        let topTrope = tropeMatches.first?.sim ?? 0
        let topOwn = own.first?.sim ?? 0
        let score: Int? = toks.count < 3 ? nil : Int((100 * (1 - max(topTrope * 0.9, topOwn))).rounded())
        let label: String
        if let s = score {
            label = s >= 75 ? "Fresh" : s >= 50 ? "Familiar territory" : "Well-worn"
        } else {
            label = "Write a little more to check"
        }

        var hash: UInt32 = 0
        for unit in toks.joined(separator: " ").utf16 { hash = hash &* 31 &+ UInt32(unit) }
        let n = ref.twists.count
        let suggestions = n == 0 ? [] : (0..<3).map { ref.twists[Int((UInt64(hash) + UInt64($0 * 3)) % UInt64(n))] }

        return OriginalityResult(
            score: score, label: label,
            tropeMatches: Array(tropeMatches.prefix(5)),
            representation: representation,
            ownMatches: Array(own.prefix(5)),
            suggestions: suggestions
        )
    }
}

extension Store {
    static let checkableCollections = ["characters", "abilities", "origins", "storylines", "works"]

    func otherEntries(excluding id: String?) -> [OtherEntry] {
        var out: [OtherEntry] = []
        for col in Store.checkableCollections {
            guard let c = def(col) else { continue }
            for e in list(col) where e.id != id {
                out.append(OtherEntry(col: col, entityID: e.id, label: "\(title(col, e)) (\(c.singular))", text: title(col, e) + " " + textOf(col, e)))
            }
        }
        return out
    }

    func checkOriginality(_ col: String, _ id: String) -> OriginalityResult? {
        guard let e = get(col, id) else { return nil }
        return Originality.check(title(col, e) + " " + textOf(col, e), others: otherEntries(excluding: id), ref: ref)
    }
}
