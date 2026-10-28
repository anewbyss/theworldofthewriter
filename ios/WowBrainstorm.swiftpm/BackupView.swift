import SwiftUI
import UniformTypeIdentifiers

/// A file handed to the system exporter (JSON backup, CSV, Markdown).
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupView: View {
    @EnvironmentObject var store: Store
    @State private var exportDoc: ExportDocument?
    @State private var exportName = "wow-brainstorm.json"
    @State private var exportType: UTType = .json
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var mergeImport = true
    @State private var alertMessage: String?
    @State private var snapshots: [SnapshotFile] = []
    @State private var restoreTarget: SnapshotFile?

    private var stamp: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f.string(from: Date())
    }

    var body: some View {
        List {
            Section {
                Text("Everything lives on this iPad. Export regularly and keep copies in iCloud Drive, Files, a USB drive or email. Backups open in the WOW Brainstorm web app too.")
                    .foregroundColor(.secondary)
            }
            Section("Export") {
                if let last = store.meta.lastExport, let d = isoFormatter.date(from: last) {
                    Text("Last export: \(d.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundColor(.secondary)
                }
                Button {
                    do {
                        export(try store.exportData(), name: "wow-brainstorm-\(stamp).json", type: .json)
                    } catch {
                        alertMessage = error.localizedDescription
                    }
                } label: { Label("Export full backup (.json)", systemImage: "square.and.arrow.up") }
                Button {
                    store.snapshot("Manual")
                    snapshots = store.snapshots()
                } label: { Label("Snapshot now", systemImage: "camera.on.rectangle") }
                Button {
                    export(Data(store.seriesBible().utf8), name: "series-bible-\(stamp).md", type: .plainText)
                } label: { Label("Export series bible (Markdown)", systemImage: "book.closed") }
            }
            Section("Import") {
                Text("Merge keeps the newest version of each entry. Replace swaps your whole library — a snapshot is taken first.")
                    .font(.caption).foregroundColor(.secondary)
                Button { mergeImport = true; showImporter = true } label: { Label("Merge a backup", systemImage: "arrow.triangle.merge") }
                Button(role: .destructive) { mergeImport = false; showImporter = true } label: { Label("Replace with backup", systemImage: "arrow.uturn.backward.circle") }
            }
            Section("Spreadsheets (CSV)") {
                ForEach(store.ref.collections) { c in
                    Button(c.label) {
                        export(Data(store.csv(c.id).utf8), name: "wow-\(c.id)-\(stamp).csv", type: .commaSeparatedText)
                    }
                }
            }
            Section("Snapshots on this iPad") {
                if snapshots.isEmpty {
                    Text("Snapshots are taken automatically every 10 minutes of work, on launch, and before imports, restores and deletes.")
                        .font(.caption).foregroundColor(.secondary)
                }
                ForEach(snapshots) { s in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(isoFormatter.date(from: s.at).map { $0.formatted(date: .abbreviated, time: .shortened) } ?? s.at)
                            Text(s.label + " · " + s.counts.filter { $0.value > 0 }.map { "\($0.value) \($0.key)" }.sorted().joined(separator: ", "))
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Menu {
                            Button("Export") {
                                let encoder = JSONEncoder()
                                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                                if let raw = try? encoder.encode(s.backup) {
                                    export(raw, name: "wow-brainstorm-snapshot-\(s.at.prefix(19)).json", type: .json)
                                }
                            }
                            Button("Restore", role: .destructive) { restoreTarget = s }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
            }
            Section("The data format") {
                Text("Backups are plain JSON (format \"wow-brainstorm\", version 1). Field definitions live in shared/schemas.json in the project, so your work is always readable without this app.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .navigationTitle("Backups & Data")
        .onAppear { snapshots = store.snapshots() }
        .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: exportType, defaultFilename: exportName) { result in
            if case .failure(let error) = result { alertMessage = error.localizedDescription }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    let raw = try Data(contentsOf: url)
                    try store.importData(raw, merge: mergeImport)
                    snapshots = store.snapshots()
                    alertMessage = mergeImport ? "Backup merged." : "Backup restored."
                } catch {
                    alertMessage = error.localizedDescription
                }
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
        .alert(alertMessage ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .confirmationDialog("Restore this snapshot? Your current library is snapshotted first.", isPresented: Binding(get: { restoreTarget != nil }, set: { if !$0 { restoreTarget = nil } }), titleVisibility: .visible) {
            Button("Restore", role: .destructive) {
                if let s = restoreTarget {
                    store.restore(s)
                    snapshots = store.snapshots()
                }
                restoreTarget = nil
            }
        }
    }

    private func export(_ data: Data, name: String, type: UTType) {
        exportDoc = ExportDocument(data: data)
        exportName = name
        exportType = type
        showExporter = true
    }
}

// MARK: - Character breakdown

struct BreakdownView: View {
    @EnvironmentObject var store: Store
    let id: String

    var body: some View {
        if let c = store.get("characters", id), let def = store.def("characters") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 20) { portrait(c).frame(width: 180); header(c) }
                        VStack(alignment: .leading, spacing: 12) { portrait(c).frame(width: 160); header(c) }
                    }
                    ForEach(["personality", "motivation", "wound", "contradiction", "arc", "community", "appearance", "voice"], id: \.self) { key in
                        if let f = def.fields.first(where: { $0.key == key }), !c.string(key).isEmpty {
                            block(f.label, c.string(key))
                        }
                    }
                    if let o = store.get("origins", c.string("origin")) {
                        block("Origin — " + store.title("origins", o), o.string("description"))
                    }
                    let abilities = c.strings("abilities").compactMap { store.get("abilities", $0) }
                    if !abilities.isEmpty {
                        Text("Abilities").font(.system(.title3, design: .serif).weight(.bold))
                        ForEach(abilities) { a in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.title("abilities", a)).font(.headline) + Text(a.string("category").isEmpty ? "" : " · " + a.string("category")).foregroundColor(.secondary)
                                if !a.string("description").isEmpty { Text(a.string("description")) }
                                if !a.string("limits").isEmpty { Text("Limits: ").italic() + Text(a.string("limits")) }
                                if !a.string("cost").isEmpty { Text("Cost: ").italic() + Text(a.string("cost")) }
                            }
                        }
                    }
                    if let f = def.fields.first(where: { $0.key == "works" }) {
                        let v = store.displayValue(f, c["works"])
                        if !v.isEmpty { block("Media appearances", v) }
                    }
                    if !c.string("inspiration").isEmpty { block("Inspiration", c.string("inspiration")) }
                }
                .padding(24)
                .textSelection(.enabled)
            }
            .navigationTitle("Character breakdown")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: markdown(c, def)) { Label("Share", systemImage: "square.and.arrow.up") }
                }
            }
        } else {
            Text("Character not found.")
        }
    }

    private func portrait(_ c: Entity) -> some View {
        PortraitView(params: PortraitParams(c["portrait"], spec: store.ref.portrait), spec: store.ref.portrait)
    }

    private func header(_ c: Entity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CHARACTER BREAKDOWN").font(.caption.weight(.bold)).foregroundColor(.wowGoldDeep)
            Text(store.title("characters", c)).font(.system(.largeTitle, design: .serif).weight(.bold))
            if !c.string("aliases").isEmpty { Text(c.string("aliases")).foregroundColor(.secondary) }
            Text([c.string("role"), c.string("status")].filter { !$0.isEmpty }.joined(separator: " · "))
            let cultures = c.strings("cultures").compactMap { store.ref.culture($0)?.region }
            if !cultures.isEmpty { Text(cultures.joined(separator: ", ")).font(.callout).foregroundColor(.secondary) }
            if !c.string("universe").isEmpty { Text("World: " + c.string("universe")).font(.callout) }
        }
    }

    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(.title3, design: .serif).weight(.bold))
            Text(text)
        }
    }

    private func markdown(_ c: Entity, _ def: CollectionDef) -> String {
        var md = "# \(store.title("characters", c))\n\n"
        for f in def.fields where f.key != def.titleField {
            let v = store.displayValue(f, c[f.key])
            if !v.isEmpty { md += "**\(f.label):** \(v)\n\n" }
        }
        for a in c.strings("abilities").compactMap({ store.get("abilities", $0) }) {
            md += "## \(store.title("abilities", a))\n\(a.string("description"))\n"
            if !a.string("limits").isEmpty { md += "\n_Limits:_ \(a.string("limits"))\n" }
            if !a.string("cost").isEmpty { md += "\n_Cost:_ \(a.string("cost"))\n" }
            md += "\n"
        }
        return md
    }
}
