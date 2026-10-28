import SwiftUI
import UniformTypeIdentifiers

/// World economy: population and GDP since 1960, region totals, rankings, trends and imported
/// UN datasets (mirrors web/js/economy.js).
struct EconomyData: Decodable {
    struct Source: Decodable, Hashable { let id: String; let name: String; let by: String; let url: String; let via: String }
    struct Series: Decodable, Identifiable, Hashable {
        let code: String
        let name: String
        let pool: String?
        let modern: String?
        let pop: [Double?]
        let gdp: [Double?]
        var id: String { code }
    }
    let years: [Int]
    let sources: [Source]
    let countries: [Series]
    let aggregates: [Series]

    /// Decoded on first use, so the app starts as fast as before.
    static let shared: EconomyData = {
        do { return try JSONDecoder().decode(EconomyData.self, from: Data(economyJSON.utf8)) }
        catch { fatalError("Economy data failed to load: \(error)") }
    }()

    func series(_ code: String) -> Series? { countries.first { $0.code == code } ?? aggregates.first { $0.code == code } }
    func byModern(_ id: String) -> Series? { countries.first { $0.modern == id } }

    func latest(_ arr: [Double?]) -> (year: Int, value: Double)? {
        for i in stride(from: arr.count - 1, through: 0, by: -1) { if let v = arr[i] { return (years[i], v) } }
        return nil
    }

    static func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased().filter { $0 >= "a" && $0 <= "z" }
    }

    static let unNames: [String: String] = [
        "State of Palestine": "PSE", "United States of America": "USA", "Republic of Korea": "KOR", "Democratic People's Republic of Korea": "PRK",
        "United Republic of Tanzania": "TZA", "Lao People's Democratic Republic": "LAO", "Republic of Moldova": "MDA", "Democratic Republic of the Congo": "COD",
        "Congo": "COG", "United Kingdom of Great Britain and Northern Ireland": "GBR", "China, Hong Kong SAR": "HKG", "China, Macao SAR": "MAC",
        "Micronesia (Fed. States of)": "FSM", "Kosovo (under UNSC res. 1244)": "XKX", "Gambia": "GMB", "Bahamas": "BHS", "Curaçao": "CUW",
        "Saint Martin (French part)": "MAF", "Sint Maarten (Dutch part)": "SXM", "Kyrgyzstan": "KGZ", "Slovakia": "SVK", "Russia": "RUS",
        "Egypt": "EGY", "Yemen": "YEM", "Venezuela": "VEN", "Iran": "IRN", "Syria": "SYR", "Viet Nam": "VNM", "Côte d'Ivoire": "CIV", "Turkey": "TUR",
        "Netherlands (Kingdom of the)": "NLD", "United States Virgin Islands": "VIR", "Saint Kitts and Nevis": "KNA", "Saint Lucia": "LCA",
        "Saint Vincent and the Grenadines": "VCT", "Hong Kong": "HKG", "Macao": "MAC", "Macau": "MAC", "Cape Verde": "CPV", "Swaziland": "SWZ",
    ]

    /// Match a name from any UN file to a country: "Bolivia (Plurinational State of)" → Bolivia.
    func find(_ name: String, modernNames: [String: String]) -> Series? {
        var index: [String: Series] = [:]
        for c in countries {
            let m = c.modern.flatMap { modernNames[$0] } ?? ""
            for k in [c.name, c.name.components(separatedBy: ",").first ?? "", c.name.components(separatedBy: " (").first ?? "", m,
                      (m.components(separatedBy: " (").first ?? "").components(separatedBy: " / ").first ?? ""] where !k.isEmpty {
                index[Self.norm(k)] = c
            }
        }
        for a in aggregates { index[Self.norm(a.name)] = a }
        for (alias, code) in Self.unNames { if let c = series(code) { index[Self.norm(alias)] = c } }
        return index[Self.norm(name)] ?? index[Self.norm(name.components(separatedBy: " (").first ?? "")] ?? index[Self.norm(name.components(separatedBy: ",").first ?? "")]
    }
}

func formatAmount(_ v: Double?, _ unit: String) -> String {
    guard let v = v, !v.isNaN else { return "—" }
    let a = abs(v)
    func trim(_ x: Double, _ d: Int) -> String {
        let s = String(format: "%.\(d)f", x)
        return s.contains(".") ? String(s.reversed().drop { $0 == "0" }.drop { $0 == "." }.reversed()) : s
    }
    let s: String
    if a >= 1e12 { s = "\(trim(v / 1e12, 2)) trillion" }
    else if a >= 1e9 { s = "\(trim(v / 1e9, 2)) billion" }
    else if a >= 1e6 { s = "\(trim(v / 1e6, 1)) million" }
    else if a >= 1000 { s = NumberFormatter.localizedString(from: NSNumber(value: v.rounded()), number: .decimal) }
    else { s = trim(v, 2) }
    if unit == "US$" { return "$" + s }
    return unit.isEmpty || unit == "people" ? s : "\(s) \(unit)"
}

struct EconMetric: Identifiable, Hashable {
    let id: String
    let label: String
    let unit: String
    let agg: String
    var imported: Entity? = nil
    var values: [String: [Int: Double]] = [:]

    func value(_ c: EconomyData.Series, _ i: Int, _ year: Int) -> Double? {
        switch id {
        case "pop": return c.pop[i]
        case "gdp": return c.gdp[i].map { $0 * 1e6 }
        case "gdppc":
            guard let g = c.gdp[i], let p = c.pop[i], p > 0 else { return nil }
            return g * 1e6 / p
        default: return values[c.code]?[year]
        }
    }
}

extension Store {
    /// Imported datasets live in the Research Pool, so backups carry them between apps.
    func econMetrics() -> [EconMetric] {
        let econ = EconomyData.shared
        let modernNames = Dictionary(ref.modern.flatMap { $0.items.map { ($0.id, $0.name) } }, uniquingKeysWith: { a, _ in a })
        var out = [EconMetric(id: "pop", label: "Population", unit: "people", agg: "sum"),
                   EconMetric(id: "gdp", label: "GDP (current US$)", unit: "US$", agg: "sum"),
                   EconMetric(id: "gdppc", label: "GDP per person (US$)", unit: "US$", agg: "ratio")]
        for r in list("research") {
            guard let series = r["series"].object else { continue }
            var values: [String: [Int: Double]] = [:]
            for (name, obj) in series {
                guard let c = econ.find(name, modernNames: modernNames), let years = obj.object else { continue }
                for (y, v) in years { if let yr = Int(y), let n = v.number { values[c.code, default: [:]][yr] = n } }
            }
            out.append(EconMetric(id: r.id, label: r.string("title").isEmpty ? "Imported data" : r.string("title"), unit: r.string("unit"),
                                  agg: r.string("agg").isEmpty ? "mean" : r.string("agg"), imported: r, values: values))
        }
        return out
    }
}

struct EconomyView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var metricID = "pop"
    @State private var year = EconomyData.shared.years.last ?? 2023
    @State private var region = ""
    @State private var picks = ["WLD"]
    @State private var logScale = false
    @State private var showAll = false
    @State private var importing = false
    @State private var message: String?

    private let econ = EconomyData.shared
    private let colors: [Color] = [.wowViolet, .wowGoldDeep, Color(hex: "#D14B3C"), Color(hex: "#2F6FB0"), Color(hex: "#1E8A6E"), .wowVioletSoft, Color(hex: "#7A5C2E")]

    var body: some View {
        let metrics = store.econMetrics()
        let m = metrics.first { $0.id == metricID } ?? metrics[0]
        let i = econ.years.firstIndex(of: year) ?? (econ.years.count - 1)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(eyebrow: "Research", title: "World economy", subtitle: "Population and GDP for \(econ.countries.count) countries and territories from \(econ.years.first ?? 1960) to today, by region and over time — and any UN dataset you import. Use it to ground your world's wealth, poverty, growth and collapse in real proportions.")
                Card {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(metrics) { x in
                                Button {
                                    metricID = x.id
                                    year = min(year, lastYear(x))
                                } label: { Chip(text: x.label + (x.imported != nil ? " · imported" : ""), on: x.id == m.id) }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Text("\(year)").font(.system(.largeTitle, design: .serif).weight(.bold)).foregroundColor(.wowViolet)
                    Slider(value: Binding(get: { Double(year) }, set: { year = Int($0.rounded()) }), in: Double(econ.years.first ?? 1960)...Double(econ.years.last ?? 2025), step: 1)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { regionMap(m, i).frame(minWidth: 480); chart(m) }
                    VStack(spacing: 16) { regionMap(m, i); chart(m) }
                }
                ranking(m, i)
                Card {
                    Text("Import UN data (CSV)").font(.headline)
                    Text("Download a table from UNdata (data.un.org), the UN World Population Prospects, the UN National Accounts or the UNDP Human Development data as CSV, then import it here. It becomes a metric on this page and is saved in your Research Pool, so backups carry it to the web app.")
                        .font(.callout).foregroundColor(.secondary)
                    Button { importing = true } label: { Label("Choose a CSV file", systemImage: "square.and.arrow.down") }.buttonStyle(.borderedProminent)
                }
                Card {
                    Text("Sources & care").font(.headline)
                    ForEach(econ.sources, id: \.self) { s in
                        Text("\(s.name) — \(s.by). Bundled via \(s.via).").font(.caption)
                    }
                    Text("GDP is in current US dollars: not adjusted for inflation or for what money buys locally, so it understates poorer countries' living standards and makes the past look smaller than it was. It also counts only market activity — not care work, subsistence farming or what is extracted from a place by others. Regions follow this app's culture regions, not the UN's. Before 1960 there is no comparable UN series; for deep history, see the Time Atlas.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("World Economy")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            switch result {
            case .success(let url):
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let text = try? String(contentsOf: url, encoding: .utf8) { message = importCSV(text, name: url.deletingPathExtension().lastPathComponent) }
                else { message = "Couldn't read that file." }
            case .failure(let error): message = error.localizedDescription
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} }
    }

    private func lastYear(_ m: EconMetric) -> Int {
        for (i, y) in econ.years.enumerated().reversed() where econ.countries.contains(where: { m.value($0, i, y) != nil }) { return y }
        return econ.years.last ?? 2023
    }

    private func regionValue(_ m: EconMetric, _ pool: String, _ i: Int) -> Double? {
        let cs = econ.countries.filter { pool == "global" || $0.pool == pool }
        let y = econ.years[i]
        if m.agg == "ratio" {
            var g = 0.0, p = 0.0
            for c in cs { if let gd = c.gdp[i], let pp = c.pop[i], pp > 0 { g += gd * 1e6; p += pp } }
            return p > 0 ? g / p : nil
        }
        let vals = cs.compactMap { m.value($0, i, y) }
        guard !vals.isEmpty else { return nil }
        let sum = vals.reduce(0, +)
        return m.agg == "sum" ? sum : sum / Double(vals.count)
    }

    // MARK: Region map

    private func regionMap(_ m: EconMetric, _ i: Int) -> some View {
        let vals = Dictionary(uniqueKeysWithValues: TimeAtlasView.tiles.map { t in (t.0, t.0 == "diasporas" ? nil : regionValue(m, t.0, i)) })
        let mx = vals.filter { $0.key != "global" }.compactMap { $0.value }.max() ?? 1
        return Card {
            Text("By region").font(.headline)
            Text("Gold deepens with the region's total; tap a region to rank its countries.").font(.caption).foregroundColor(.secondary)
            GeometryReader { geo in
                let cell = geo.size.width / 10
                ZStack(alignment: .topLeading) {
                    ForEach(TimeAtlasView.tiles, id: \.0) { t in
                        let v = vals[t.0] ?? nil
                        let share = t.0 == "global" ? 1 : (v ?? 0) / mx
                        let dark = t.0 == "global" || share > 0.6
                        Button { region = region == t.0 ? "" : t.0 } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.0 == "global" ? "World" : (store.ref.culture(t.0)?.region ?? t.0).components(separatedBy: " (").first ?? "")
                                    .font(.system(size: max(cell * 0.1, 7), weight: .semibold)).lineLimit(3).minimumScaleFactor(0.6)
                                Spacer(minLength: 0)
                                Text(t.0 == "diasporas" ? "" : formatAmount(v, m.unit)).font(.system(size: max(cell * 0.1, 7), weight: .bold)).lineLimit(2).minimumScaleFactor(0.5)
                            }
                            .foregroundColor(dark ? .white : .primary)
                            .padding(cell * 0.07)
                            .frame(width: cell - 6, height: cell - 6, alignment: .topLeading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(t.0 == "global" ? Color.wowViolet : Color.wowGoldDeep.opacity(v == nil ? 0.08 : 0.15 + share * 0.8)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(region == t.0 ? Color.wowVioletBright : Color.wowVioletSoft.opacity(0.3), lineWidth: region == t.0 ? 3 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(t.0): \(formatAmount(v, m.unit))")
                        .offset(x: CGFloat(t.1) * cell + 3, y: CGFloat(t.2) * cell + 3)
                    }
                }
            }
            .aspectRatio(2, contentMode: .fit)
        }
    }

    // MARK: Chart

    private func chart(_ m: EconMetric) -> some View {
        let lines = picks.compactMap { econ.series($0) }.map { c in
            (c, econ.years.enumerated().compactMap { pair in m.value(c, pair.offset, pair.element).map { (pair.element, $0) } }.filter { !logScale || $0.1 > 0 })
        }
        let all = lines.flatMap { $0.1.map { $0.1 } }
        let lo = logScale ? (all.min() ?? 1) : min(0, all.min() ?? 0)
        let hi = all.max() ?? 1
        let y0 = Double(econ.years.first ?? 1960), y1 = Double(econ.years.last ?? 2025)
        return Card {
            Text("Over time").font(.headline)
            FlowLayout {
                ForEach(Array(lines.enumerated()), id: \.offset) { pair in
                    Button { picks.removeAll { $0 == pair.element.0.code } } label: {
                        HStack(spacing: 4) {
                            Circle().fill(colors[pair.offset % colors.count]).frame(width: 9, height: 9)
                            Text(pair.element.0.name).font(.caption)
                            Image(systemName: "xmark").font(.caption2)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().stroke(colors[pair.offset % colors.count]))
                    }
                    .buttonStyle(.plain)
                }
                Menu {
                    Section("World, regions & income groups") { ForEach(econ.aggregates) { a in Button(a.name) { add(a.code) } } }
                    Section("Countries") { ForEach(econ.countries) { c in Button(c.name) { add(c.code) } } }
                } label: { Label("Add", systemImage: "plus.circle") }
                Toggle("Log", isOn: $logScale).toggleStyle(.button).font(.caption)
            }
            Canvas { ctx, size in
                let pad: CGFloat = 8
                func X(_ y: Double) -> CGFloat { pad + CGFloat((y - y0) / max(y1 - y0, 1)) * (size.width - 2 * pad) }
                func Y(_ v: Double) -> CGFloat {
                    let f = logScale ? (log10(v) - log10(lo)) / max(log10(hi) - log10(lo), 1e-9) : (v - lo) / max(hi - lo, 1e-9)
                    return size.height - pad - CGFloat(f) * (size.height - 2 * pad)
                }
                for decade in stride(from: 1960, through: Int(y1), by: 10) {
                    var p = Path()
                    p.move(to: CGPoint(x: X(Double(decade)), y: pad))
                    p.addLine(to: CGPoint(x: X(Double(decade)), y: size.height - pad))
                    ctx.stroke(p, with: .color(.secondary.opacity(0.2)), lineWidth: 1)
                    ctx.draw(Text(String(decade)).font(.caption2).foregroundColor(.secondary), at: CGPoint(x: X(Double(decade)) + 2, y: size.height - 2), anchor: .bottomLeading)
                }
                for (k, line) in lines.enumerated() where line.1.count > 1 {
                    var p = Path()
                    p.addLines(line.1.map { CGPoint(x: X(Double($0.0)), y: Y($0.1)) })
                    ctx.stroke(p, with: .color(colors[k % colors.count]), lineWidth: 3)
                }
                var cursor = Path()
                cursor.move(to: CGPoint(x: X(Double(year)), y: pad))
                cursor.addLine(to: CGPoint(x: X(Double(year)), y: size.height - pad))
                ctx.stroke(cursor, with: .color(.wowGold), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                ctx.draw(Text(formatAmount(hi, m.unit)).font(.caption2).foregroundColor(.secondary), at: CGPoint(x: pad, y: pad), anchor: .topLeading)
            }
            .frame(height: 240)
        }
    }

    private func add(_ code: String) { if !picks.contains(code) { picks = Array((picks + [code]).suffix(6)) } }

    // MARK: Ranking

    private func ranking(_ m: EconMetric, _ i: Int) -> some View {
        let i10 = econ.years.firstIndex(of: year - 10)
        let world = m.agg == "sum" ? regionValue(m, "global", i) : nil
        let rows = econ.countries.filter { region.isEmpty || region == "global" || $0.pool == region }
            .compactMap { c -> (EconomyData.Series, Double, Double?)? in
                guard let v = m.value(c, i, year) else { return nil }
                return (c, v, i10.flatMap { m.value(c, $0, year - 10) })
            }
            .sorted { $0.1 > $1.1 }
        return Card {
            HStack {
                Text("\(m.label), \(year)" + (region.isEmpty ? "" : " · " + (region == "global" ? "World" : store.ref.culture(region)?.region ?? region))).font(.headline)
                Spacer()
                if !region.isEmpty { Button("All regions") { region = "" }.font(.caption) }
            }
            if rows.isEmpty { Text("No values for this year.").foregroundColor(.secondary) }
            ForEach(Array((showAll ? rows : Array(rows.prefix(25))).enumerated()), id: \.offset) { pair in
                let r = pair.element
                HStack(alignment: .firstTextBaseline) {
                    Text("\(pair.offset + 1)").font(.caption).foregroundColor(.secondary).frame(width: 28, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.0.name).font(.callout)
                        if let old = r.2, old != 0 {
                            Text("10 years earlier: \(formatAmount(old, m.unit)) (\(r.1 >= old ? "+" : "")\(Int(((r.1 - old) / abs(old) * 100).rounded()))%)").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(formatAmount(r.1, m.unit)).font(.callout.weight(.semibold))
                        if let w = world, w > 0 { Text(String(format: "%.1f%% of world", r.1 / w * 100)).font(.caption2).foregroundColor(.secondary) }
                    }
                    Button { add(r.0.code) } label: { Image(systemName: "chart.xyaxis.line") }.buttonStyle(.borderless)
                }
                Divider()
            }
            if rows.count > 25 { Button(showAll ? "Show top 25" : "Show all \(rows.count)") { showAll.toggle() } }
        }
    }

    // MARK: Import

    /// Reads UNdata ("Country or Area","Year","Value"), UN WPP ("Location","Time"…), World Bank long format and similar tables.
    private func importCSV(_ text: String, name: String) -> String {
        let rows = parseCSV(text)
        guard rows.count > 1 else { return "That file has no rows." }
        let header = rows[0].map { $0.trimmingCharacters(in: .whitespaces) }
        func find(_ prefixes: [String]) -> Int? { header.firstIndex { h in prefixes.contains { h.lowercased().hasPrefix($0) } } }
        let ci = find(["country", "area", "location", "region, subregion", "entity"]) ?? 0
        let yi = find(["year", "time", "date", "period"]) ?? 1
        let vi = header.firstIndex { $0.lowercased() == "value" } ?? header.count - 1
        var series: [String: JSONValue] = [:]
        var objects: [String: [String: JSONValue]] = [:]
        var n = 0
        for r in rows.dropFirst() where r.count > max(ci, yi, vi) {
            let place = r[ci].trimmingCharacters(in: .whitespaces)
            guard !place.isEmpty, let y = Int(r[yi].trimmingCharacters(in: .whitespaces)),
                  let v = Double(r[vi].replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)) else { continue }
            objects[place, default: [:]][String(y)] = .number(v)
            n += 1
        }
        guard n > 0 else { return "No values found. The file needs country, year and value columns." }
        for (k, v) in objects { series[k] = .object(v) }
        // Big numbers are counts or money (add countries up); small ones are rates or indexes (average them).
        let all = objects.values.flatMap { $0.values.compactMap { $0.number } }.sorted()
        let agg = (all.isEmpty ? 0 : all[all.count / 2]) > 100_000 ? "sum" : "mean"
        let rec = store.create("research", ["title": .string(name), "kind": .string("dataset"), "source": .string(name), "notes": .string("Imported from \(name).csv: \(n) values."),
                                            "tags": .strings(["dataset", "economy"]), "series": .object(series), "unit": .string(""), "agg": .string(agg)])
        metricID = rec.id
        let matched = objects.keys.filter { econ.find($0, modernNames: [:]) != nil }.count
        return "Imported \(n) values for \(objects.count) places (\(matched) matched to countries on the map). Regions \(agg == "sum" ? "add countries up" : "average countries")."
    }

    private func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], cell = "", quoted = false
        let chars = Array(text)
        var k = 0
        while k < chars.count {
            let ch = chars[k]
            if quoted {
                if ch == "\"" && k + 1 < chars.count && chars[k + 1] == "\"" { cell.append("\""); k += 1 }
                else if ch == "\"" { quoted = false }
                else { cell.append(ch) }
            } else if ch == "\"" { quoted = true }
            else if ch == "," { row.append(cell); cell = "" }
            else if ch == "\n" || ch == "\r" || ch == "\r\n" {
                row.append(cell); rows.append(row); row = []; cell = ""
            } else { cell.append(ch) }
            k += 1
        }
        if !cell.isEmpty || !row.isEmpty { row.append(cell); rows.append(row) }
        return rows.filter { r in r.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }
}
