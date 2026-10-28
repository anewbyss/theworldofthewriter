import SwiftUI
import Foundation

/// One entry (character, ability, work…). Stored as a plain JSON object so
/// backups are identical between the iPad and web apps.
struct Entity: Identifiable, Hashable, Codable {
    var fields: [String: JSONValue]

    init(fields: [String: JSONValue]) { self.fields = fields }
    init(from decoder: Decoder) throws { fields = try [String: JSONValue](from: decoder) }
    func encode(to encoder: Encoder) throws { try fields.encode(to: encoder) }

    var id: String { fields["id"]?.string ?? "" }
    subscript(key: String) -> JSONValue {
        get { fields[key] ?? .null }
        set { fields[key] = newValue }
    }
    func string(_ key: String) -> String { fields[key]?.string ?? "" }
    func strings(_ key: String) -> [String] { fields[key]?.stringArray ?? [] }
    func number(_ key: String) -> Double? { fields[key]?.number }
}

struct BackupFile: Codable {
    var format: String
    var formatVersion: Int
    var app: String?
    var exportedAt: String?
    var data: [String: [Entity]]
}

struct StoreMeta: Codable {
    var lastExport: String?
    var lastSnapshot: String?
}

struct SavedLibrary: Codable {
    var data: [String: [Entity]]
    var meta: StoreMeta
}

struct SnapshotFile: Codable, Identifiable {
    var id: String
    var at: String
    var label: String
    var counts: [String: Int]
    var backup: BackupFile
}

struct Option: Identifiable, Hashable {
    let id: String
    let label: String
}

enum StoreError: LocalizedError {
    case notABackup
    case tooNew
    var errorDescription: String? {
        switch self {
        case .notABackup: return "This file is not a WOW Brainstorm backup."
        case .tooNew: return "This backup was made by a newer version of WOW Brainstorm."
        }
    }
}

let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

func nowISO() -> String { isoFormatter.string(from: Date()) }

/// Local-first store: the library lives in the app's Documents folder, with
/// rolling snapshots in Documents/Snapshots.
final class Store: ObservableObject {
    let ref: Reference
    let refData: RefData
    @Published private(set) var data: [String: [Entity]] = [:]
    @Published var meta = StoreMeta()
    @Published var lastSaved: Date?

    private var pendingSave: DispatchWorkItem?
    private var dirtySinceSnapshot = false
    private var timer: Timer?
    private let maxSnapshots = 20
    private let snapshotInterval: TimeInterval = 10 * 60

    init() {
        ref = Reference.load()
        refData = RefData(ref: ref)
        for c in ref.collections { data[c.id] = [] }
        load()
        if hasData && secondsSinceSnapshot > snapshotInterval { snapshot("Session start") }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.dirtySinceSnapshot && self.hasData && self.secondsSinceSnapshot > self.snapshotInterval {
                self.snapshot("Auto")
            }
        }
    }

    // MARK: Files

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var libraryURL: URL { Store.documents.appendingPathComponent("wow-library.json") }
    private var snapshotsDir: URL {
        let url = Store.documents.appendingPathComponent("Snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func load() {
        guard let raw = try? Data(contentsOf: libraryURL) else { return }
        do {
            let saved = try JSONDecoder().decode(SavedLibrary.self, from: raw)
            for (k, v) in saved.data { data[k] = v }
            meta = saved.meta
        } catch {
            // Keep the unreadable file aside instead of overwriting it.
            let aside = Store.documents.appendingPathComponent("wow-library-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: libraryURL, to: aside)
            print("Library failed to load: \(error)")
        }
    }

    private func scheduleSave() {
        dirtySinceSnapshot = true
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }

    func saveNow() {
        pendingSave?.cancel()
        do {
            let raw = try JSONEncoder().encode(SavedLibrary(data: data, meta: meta))
            try raw.write(to: libraryURL, options: .atomic)
            lastSaved = Date()
        } catch {
            print("Save failed: \(error)")
        }
    }

    // MARK: Queries

    var hasData: Bool { data.values.contains { !$0.isEmpty } }

    func def(_ col: String) -> CollectionDef? { ref.collection(col) }

    func list(_ col: String) -> [Entity] { data[col] ?? [] }

    func get(_ col: String, _ id: String?) -> Entity? {
        guard let id = id, !id.isEmpty else { return nil }
        return list(col).first { $0.id == id }
    }

    func value(_ col: String, _ id: String, _ key: String) -> JSONValue {
        get(col, id)?[key] ?? .null
    }

    func title(_ col: String, _ entity: Entity?) -> String {
        guard let e = entity else { return "(missing)" }
        let field = def(col)?.titleField ?? "title"
        let t = e.string(field)
        if t.isEmpty && col == "bonds" {
            func who(_ id: String) -> String {
                let n = get("characters", id)?.string("name") ?? ""
                return n.isEmpty ? "Someone" : n
            }
            return "\(who(e.string("from"))) — \(e.string("type").isEmpty ? "bond" : e.string("type")) — \(who(e.string("to")))"
        }
        return t.isEmpty ? "Untitled \((def(col)?.singular ?? "entry").lowercased())" : t
    }

    func title(ref anyRef: String?) -> String {
        guard let anyRef = anyRef, let parts = splitRef(anyRef) else { return "" }
        return title(parts.0, get(parts.0, parts.1))
    }

    func options(_ col: String) -> [Option] {
        list(col).map { Option(id: $0.id, label: title(col, $0)) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    func counts() -> [String: Int] {
        var out: [String: Int] = [:]
        for c in ref.collections { out[c.id] = list(c.id).count }
        return out
    }

    func recent(_ n: Int) -> [(col: String, entity: Entity)] {
        var all: [(col: String, entity: Entity)] = []
        for c in ref.collections { for e in list(c.id) { all.append((c.id, e)) } }
        return Array(all.sorted { $0.entity.string("updatedAt") > $1.entity.string("updatedAt") }.prefix(n))
    }

    /// Plain text of an entry — used for search and originality.
    func textOf(_ col: String, _ e: Entity) -> String {
        guard let c = def(col) else { return "" }
        var parts: [String] = []
        for f in c.fields {
            let v = e[f.key]
            switch f.type {
            case "text", "textarea": if let s = v.string { parts.append(s) }
            case "tags": parts.append(v.stringArray.joined(separator: " "))
            case "stages": if let o = v.object { parts.append(o.values.compactMap { $0.string }.joined(separator: " ")) }
            default: break
            }
        }
        return parts.joined(separator: "\n")
    }

    func search(_ q: String) -> [(col: String, entity: Entity)] {
        let query = q.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        var out: [(col: String, entity: Entity)] = []
        for c in ref.collections {
            for e in list(c.id) where textOf(c.id, e).lowercased().contains(query) {
                out.append((c.id, e))
            }
        }
        return out
    }

    /// Built-in options for a select field plus any the writer has added.
    func optionsFor(_ col: String, _ f: FieldDef) -> [String] {
        let base = f.options ?? []
        let custom = list("labels").filter { $0.string("kind") == "menu option" && $0.string("field") == "\(col).\(f.key)" && !$0.string("name").isEmpty }.map { $0.string("name") }
        return base + custom.filter { !base.contains($0) }
    }

    /// Every tag in use, with the entries carrying it.
    func tagIndex() -> [(tag: String, uses: [(col: String, entity: Entity)])] {
        var map: [String: [(col: String, entity: Entity)]] = [:]
        for c in ref.collections { for e in list(c.id) { for t in e.strings("tags") { map[t, default: []].append((c.id, e)) } } }
        return map.map { (tag: $0.key, uses: $0.value) }.sorted { $0.uses.count != $1.uses.count ? $0.uses.count > $1.uses.count : $0.tag < $1.tag }
    }

    func labelFor(_ name: String, kind: String = "tag") -> Entity? {
        list("labels").first { $0.string("kind") == kind && $0.string("name") == name }
    }

    func renameTag(_ from: String, to: String) {
        for c in ref.collections {
            for e in list(c.id) where e.strings("tags").contains(from) {
                var seen = Set<String>()
                let tags = e.strings("tags").map { $0 == from ? to : $0 }.filter { seen.insert($0).inserted }
                update(c.id, e.id, "tags", .strings(tags))
            }
        }
        if let l = labelFor(from) { update("labels", l.id, "name", .string(to)) }
    }

    // MARK: Mutations

    @discardableResult
    func create(_ col: String, _ fields: [String: JSONValue] = [:]) -> Entity {
        let now = nowISO()
        var f = fields
        f["id"] = .string(UUID().uuidString.lowercased())
        f["createdAt"] = .string(now)
        f["updatedAt"] = .string(now)
        let e = Entity(fields: f)
        data[col, default: []].insert(e, at: 0)
        scheduleSave()
        return e
    }

    func update(_ col: String, _ id: String, _ key: String, _ value: JSONValue) {
        guard var items = data[col], let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx][key] = value
        items[idx]["updatedAt"] = .string(nowISO())
        data[col] = items
        scheduleSave()
    }

    func duplicate(_ col: String, _ id: String) -> Entity? {
        guard let e = get(col, id), let c = def(col) else { return nil }
        var f = e.fields
        f[c.titleField] = .string(e.string(c.titleField) + " (copy)")
        return create(col, f)
    }

    func remove(_ col: String, _ id: String) {
        data[col] = list(col).filter { $0.id != id }
        for c in ref.collections {
            guard var items = data[c.id] else { continue }
            for i in items.indices {
                for f in c.fields where f.collection == col {
                    if f.type == "ref" && items[i][f.key].string == id { items[i][f.key] = .null }
                    if f.type == "refs" { items[i][f.key] = .strings(items[i].strings(f.key).filter { $0 != id }) }
                }
            }
            data[c.id] = items
        }
        let me = "\(col):\(id)"
        data["links"] = list("links").filter { $0.string("from") != me && $0.string("to") != me }
        for c in ref.collections {
            let multi = c.fields.filter { $0.type == "anyrefs" }
            guard !multi.isEmpty, var items = data[c.id] else { continue }
            for i in items.indices { for f in multi { items[i][f.key] = .strings(items[i].strings(f.key).filter { $0 != me }) } }
            data[c.id] = items
        }
        // Unlink map features that pointed at a deleted place or map.
        if col == "places" || col == "maps", var maps = data["maps"] {
            for i in maps.indices {
                var canvas = mapCanvas(maps[i])
                var changed = false
                for j in canvas.features.indices {
                    if col == "places" && canvas.features[j].placeId == id { canvas.features[j].placeId = nil; changed = true }
                    if col == "maps" && canvas.features[j].mapId == id { canvas.features[j].mapId = nil; changed = true }
                }
                if changed { maps[i]["canvas"] = canvas.json }
            }
            data["maps"] = maps
        }
        scheduleSave()
    }

    // MARK: Bindings

    func binding(_ col: String, _ id: String, _ key: String) -> Binding<JSONValue> {
        Binding(get: { self.value(col, id, key) }, set: { self.update(col, id, key, $0) })
    }

    func stringBinding(_ col: String, _ id: String, _ key: String, nullWhenEmpty: Bool = false) -> Binding<String> {
        Binding(
            get: { self.value(col, id, key).string ?? "" },
            set: { self.update(col, id, key, (nullWhenEmpty && $0.isEmpty) ? .null : .string($0)) }
        )
    }

    // MARK: Backup & restore

    func backupFile() -> BackupFile {
        BackupFile(format: ref.formatName, formatVersion: ref.formatVersion, app: "ipad", exportedAt: nowISO(), data: data)
    }

    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let out = try encoder.encode(backupFile())
        meta.lastExport = nowISO()
        scheduleSave()
        return out
    }

    func importData(_ raw: Data, merge: Bool) throws {
        let file: BackupFile
        do {
            file = try JSONDecoder().decode(BackupFile.self, from: raw)
        } catch {
            throw StoreError.notABackup
        }
        guard file.format == ref.formatName else { throw StoreError.notABackup }
        guard file.formatVersion <= ref.formatVersion else { throw StoreError.tooNew }
        snapshot("Before import")
        if merge {
            for c in ref.collections {
                var current = list(c.id)
                for e in file.data[c.id] ?? [] {
                    if let idx = current.firstIndex(where: { $0.id == e.id }) {
                        if e.string("updatedAt") > current[idx].string("updatedAt") { current[idx] = e }
                    } else {
                        current.append(e)
                    }
                }
                data[c.id] = current
            }
        } else {
            for c in ref.collections { data[c.id] = file.data[c.id] ?? [] }
        }
        scheduleSave()
    }

    // MARK: Snapshots

    private var secondsSinceSnapshot: TimeInterval {
        guard let s = meta.lastSnapshot, let d = isoFormatter.date(from: s) else { return .infinity }
        return Date().timeIntervalSince(d)
    }

    func snapshot(_ label: String) {
        let at = nowISO()
        let snap = SnapshotFile(id: UUID().uuidString, at: at, label: label, counts: counts(), backup: backupFile())
        let name = "snapshot-" + at.replacingOccurrences(of: ":", with: "-") + ".json"
        do {
            let raw = try JSONEncoder().encode(snap)
            try raw.write(to: snapshotsDir.appendingPathComponent(name), options: .atomic)
        } catch {
            print("Snapshot failed: \(error)")
        }
        pruneSnapshots()
        meta.lastSnapshot = at
        dirtySinceSnapshot = false
        scheduleSave()
    }

    private func snapshotURLs() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: snapshotsDir, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private func pruneSnapshots() {
        for url in snapshotURLs().dropFirst(maxSnapshots) { try? FileManager.default.removeItem(at: url) }
    }

    func snapshots() -> [SnapshotFile] {
        snapshotURLs().compactMap { url in
            guard let raw = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(SnapshotFile.self, from: raw)
        }
    }

    func restore(_ snap: SnapshotFile) {
        snapshot("Before restore")
        for c in ref.collections { data[c.id] = snap.backup.data[c.id] ?? [] }
        scheduleSave()
    }

    // MARK: Display & CSV

    func displayValue(_ f: FieldDef, _ v: JSONValue) -> String {
        if v.isNull { return "" }
        switch f.type {
        case "ref": return v.string.map { title(f.collection ?? "", get(f.collection ?? "", $0)) } ?? ""
        case "refs": return v.stringArray.map { title(f.collection ?? "", get(f.collection ?? "", $0)) }.joined(separator: "; ")
        case "cultures": return v.stringArray.map { ref.culture($0)?.region ?? $0 }.joined(separator: "; ")
        case "style": return ref.style(v.string)?.name ?? (v.string ?? "")
        case "rasas": return v.stringArray.map { ref.rasa($0)?.name ?? $0 }.joined(separator: "; ")
        case "tags": return v.stringArray.joined(separator: "; ")
        case "anyref": return title(ref: v.string)
        case "anyrefs": return v.stringArray.map { title(ref: $0) }.joined(separator: "; ")
        case "mapstyle": return ref.mapStyle(v.string).name
        case "refdata": return v.stringArray.map { refData.label(f.source ?? "", $0) }.joined(separator: "; ")
        case "portrait", "ink", "stages", "mapcanvas", "genome", "issuekeys": return ""
        default: return v.string ?? ""
        }
    }

    func csv(_ col: String) -> String {
        guard let c = def(col) else { return "" }
        let fields = c.fields.filter { !["portrait", "ink", "stages", "mapcanvas", "genome", "issuekeys"].contains($0.type) }
        func cell(_ s: String) -> String {
            (s.contains(",") || s.contains("\"") || s.contains("\n")) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
        }
        var rows = [(["id"] + fields.map { $0.label }).map(cell).joined(separator: ",")]
        for e in list(col) {
            rows.append(([e.id] + fields.map { displayValue($0, e[$0.key]) }).map(cell).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    /// A Markdown "series bible" of everything, for sharing or printing.
    func seriesBible() -> String {
        var md = "# Series Bible\n\n_Exported from WOW Brainstorm, \(Date().formatted(date: .long, time: .shortened))_\n"
        for col in ["works", "characters", "lineages", "traits", "abilities", "powerSystems", "gear", "curses", "blessings", "origins", "cultures", "religions", "languages", "factions", "rivalries", "conflicts", "places", "maps", "storylines", "events", "paradoxes", "research"] {
            guard let c = def(col), !list(col).isEmpty else { continue }
            md += "\n## \(c.label)\n"
            for e in list(col) {
                md += "\n### \(title(col, e))\n"
                for f in c.fields where f.key != c.titleField {
                    let v = displayValue(f, e[f.key])
                    if !v.isEmpty { md += "- **\(f.label):** \(v)\n" }
                }
                if col == "storylines", let style = ref.style(e.string("style")), let beats = e["stages"].object {
                    for st in style.stages {
                        if let t = beats[st.id]?.string, !t.isEmpty { md += "- **\(st.name):** \(t)\n" }
                    }
                }
            }
        }
        return md
    }
}

func splitRef(_ s: String) -> (String, String)? {
    let parts = s.split(separator: ":", maxSplits: 1).map(String.init)
    return parts.count == 2 ? (parts[0], parts[1]) : nil
}
