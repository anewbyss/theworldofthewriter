import Foundation

/// Fictional heredity for the offspring calculator (mirrors web/js/heredity.js).
/// Genotypes use T for the trait variant and o for the alternative.
struct HeredityPrediction {
    enum Kind { case mendel, x, number, chance, unavailable }
    var kind: Kind
    var outcomes: [(label: String, p: Double)] = []
    var manifest: Double = 0
    var genotypes: [String: Double] = [:]
    var daughters: [String: Double] = [:]
    var sons: [String: Double] = [:]
    var mean: Double = 0
    var low: Double = 0
    var high: Double = 0
    var unit = ""
    var note = ""
}

enum Heredity {
    static func isX(_ t: Entity) -> Bool { ["X-linked recessive", "X-linked dominant"].contains(t.string("mode")) }
    static func penetrance(_ t: Entity) -> Double { max(0, min(100, t.number("penetrance") ?? 100)) / 100 }
    static func variant(_ t: Entity) -> String { !t.string("variant").isEmpty ? t.string("variant") : (!t.string("name").isEmpty ? t.string("name") : "trait") }
    static func other(_ t: Entity) -> String { t.string("other").isEmpty ? "no trait" : t.string("other") }

    static func options(_ t: Entity, chromosomes: String) -> [(value: String, label: String)] {
        let v = variant(t), o = other(t)
        switch t.string("mode") {
        case "dominant":
            return [("TT", "\(v) — pure (TT)"), ("To", "\(v) — carries \(o) (To)"), ("T?", "\(v) — genotype unknown"), ("oo", "\(o) (oo)"), ("?", "unknown")]
        case "recessive":
            return [("TT", "\(v) (TT)"), ("To", "\(o) — carrier (To)"), ("o?", "\(o) — may carry"), ("oo", "\(o) — non-carrier (oo)"), ("?", "unknown")]
        case "codominant (blend)":
            return [("TT", "\(v) (TT)"), ("To", "\(t.string("blend").isEmpty ? "blend" : t.string("blend")) (To)"), ("oo", "\(o) (oo)"), ("?", "unknown")]
        case "X-linked recessive", "X-linked dominant":
            if chromosomes == "XY" { return [("T", "\(v) on their X"), ("o", "\(o) on their X"), ("?", "unknown")] }
            if chromosomes == "XX" { return [("TT", "\(v) on both X (TT)"), ("To", "one \(v) X (To)"), ("oo", "no \(v) (oo)"), ("?", "unknown")] }
            return [("?", "set XX or XY above to use this trait")]
        case "one parent line", "spirit-chosen (chance)":
            return [("yes", "has \(v)"), ("no", "doesn't have \(v)")]
        default:
            return []
        }
    }

    static func pT(_ g: String?) -> Double {
        switch g ?? "" {
        case "TT", "T": return 1
        case "To": return 0.5
        case "oo", "o": return 0
        case "T?": return 2.0 / 3.0
        case "o?": return 1.0 / 3.0
        default: return 0.5
        }
    }

    static func shows(_ t: Entity, _ g: String) -> Bool {
        switch t.string("mode") {
        case "dominant", "X-linked dominant": return g.contains("T")
        case "recessive": return g == "TT"
        case "X-linked recessive": return g == "TT" || g == "T"
        case "codominant (blend)": return g != "oo"
        default: return false
        }
    }

    static func label(_ t: Entity, _ g: String) -> String {
        if t.string("mode") == "codominant (blend)" {
            switch g {
            case "TT": return variant(t)
            case "To": return t.string("blend").isEmpty ? "\(variant(t))/\(other(t)) blend" : t.string("blend")
            default: return other(t)
            }
        }
        return shows(t, g) ? variant(t) : other(t)
    }

    static func autosomal(_ p1: Double, _ p2: Double) -> [String: Double] {
        ["TT": p1 * p2, "To": p1 * (1 - p2) + p2 * (1 - p1), "oo": (1 - p1) * (1 - p2)]
    }

    static func polyParams(_ t: Entity, _ a: JSONValue?, _ b: JSONValue?) -> (lo: Double, hi: Double, mean: Double, sd: Double) {
        let lo = t.number("min") ?? 0, hi = t.number("max") ?? 100
        let va = a?.number ?? (lo + hi) / 2, vb = b?.number ?? (lo + hi) / 2
        let fallback = (hi - lo) / 10
        let sd = t.number("spread") ?? (fallback == 0 ? 5 : fallback)
        return (lo, hi, (va + vb) / 2, sd)
    }

    static func predict(_ t: Entity, _ genA: JSONValue?, _ genB: JSONValue?, _ chromA: String, _ chromB: String, lineParent: Int) -> HeredityPrediction {
        let P = penetrance(t)
        let mode = t.string("mode")
        if mode == "polygenic (number)" {
            let pp = polyParams(t, genA, genB)
            let r = 1.2816 * pp.sd
            var out = HeredityPrediction(kind: .number)
            out.mean = pp.mean
            out.low = max(pp.lo, pp.mean - r)
            out.high = min(pp.hi, pp.mean + r)
            out.unit = t.string("unit")
            return out
        }
        if mode == "one parent line" {
            let g = (lineParent == 2 ? genB : genA)?.string
            let p = (g == "yes" ? 1.0 : 0.0) * P
            return HeredityPrediction(kind: .chance, outcomes: [(variant(t), p), (other(t), 1 - p)], manifest: p)
        }
        if mode == "spirit-chosen (chance)" {
            let parent = genA?.string == "yes" || genB?.string == "yes"
            let p = (t.number(parent ? "chanceIfParent" : "chanceOtherwise") ?? 0) / 100
            return HeredityPrediction(kind: .chance, outcomes: [(variant(t), p), (other(t), 1 - p)], manifest: p)
        }
        if isX(t) {
            var mother: String?, father: String?
            if chromA == "XX" && chromB == "XY" { mother = genA?.string ?? "?"; father = genB?.string ?? "?" }
            else if chromA == "XY" && chromB == "XX" { mother = genB?.string ?? "?"; father = genA?.string ?? "?" }
            guard let m = mother, let f = father else {
                var out = HeredityPrediction(kind: .unavailable)
                out.note = "X-linked traits need one XX and one XY parent."
                return out
            }
            let pm = pT(m), pf = pT(f)
            let daughters = autosomal(pm, pf)
            let sons = ["T": pm, "o": 1 - pm]
            let dShow = daughters.reduce(0) { $0 + (shows(t, $1.key) ? $1.value : 0) }
            let sShow = shows(t, "T") ? pm : 0
            var out = HeredityPrediction(kind: .x)
            out.daughters = daughters
            out.sons = sons
            out.manifest = (dShow + sShow) / 2 * P
            out.outcomes = [("XX children: \(variant(t))", dShow * P), ("XY children: \(variant(t))", sShow * P)]
            return out
        }
        let g = autosomal(pT(genA?.string), pT(genB?.string))
        let showP = g.reduce(0) { $0 + (shows(t, $1.key) ? $1.value : 0) }
        var out = HeredityPrediction(kind: .mendel)
        out.genotypes = g
        out.manifest = showP * P
        if mode == "codominant (blend)" {
            out.outcomes = [(label(t, "TT"), (g["TT"] ?? 0) * P), (label(t, "To"), (g["To"] ?? 0) * P), (label(t, "oo"), (g["oo"] ?? 0) + ((g["TT"] ?? 0) + (g["To"] ?? 0)) * (1 - P))]
        } else {
            out.outcomes = [(variant(t), showP * P), (other(t), 1 - showP * P)]
        }
        return out
    }

    /// Roll one child's value for a trait.
    static func sample(_ t: Entity, _ genA: JSONValue?, _ genB: JSONValue?, _ chromA: String, _ chromB: String, childChrom: String, lineParent: Int) -> (value: JSONValue, manifests: Bool, label: String) {
        let P = penetrance(t)
        let mode = t.string("mode")
        if mode == "polygenic (number)" {
            let pp = polyParams(t, genA, genB)
            let u = max(Double.random(in: 0..<1), 1e-9), w = Double.random(in: 0..<1)
            let z = (-2 * log(u)).squareRoot() * cos(2 * Double.pi * w)
            let val = (max(pp.lo, min(pp.hi, pp.mean + z * pp.sd)) * 10).rounded() / 10
            let unit = t.string("unit")
            return (.number(val), true, unit.isEmpty ? fmt(val) : "\(fmt(val)) \(unit)")
        }
        if mode == "one parent line" || mode == "spirit-chosen (chance)" {
            let p = predict(t, genA, genB, chromA, chromB, lineParent: lineParent).manifest
            let yes = Double.random(in: 0..<1) < p
            return (.string(yes ? "yes" : "no"), yes, yes ? variant(t) : other(t))
        }
        func allele(_ g: String?) -> String { Double.random(in: 0..<1) < pT(g) ? "T" : "o" }
        func pair(_ a: String, _ b: String) -> String { a == b ? a + b : "To" }
        var g: String
        if isX(t) {
            let valid = (chromA == "XX" && chromB == "XY") || (chromA == "XY" && chromB == "XX")
            if !valid { return (.string("?"), false, "unknown") }
            let mother = chromA == "XX" ? genA?.string : genB?.string
            let father = chromA == "XX" ? genB?.string : genA?.string
            let fromMother = allele(mother)
            g = childChrom == "XY" ? fromMother : pair(fromMother, allele(father))
        } else {
            g = pair(allele(genA?.string), allele(genB?.string))
        }
        let manifests = shows(t, g) && Double.random(in: 0..<1) < P
        let text = manifests ? label(t, g) : (shows(t, g) ? "\(other(t)) (\(variant(t)) dormant)" : label(t, g))
        return (.string(g), manifests, text)
    }
}
