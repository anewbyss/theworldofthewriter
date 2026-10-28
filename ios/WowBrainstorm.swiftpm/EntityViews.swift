import SwiftUI

// MARK: - List

struct EntityRow: View {
    @EnvironmentObject var store: Store
    let col: String
    let entity: Entity
    var showType = false

    var body: some View {
        NavigationLink(value: Route.entity(col, entity.id)) {
            HStack(spacing: 12) {
                if col == "characters" {
                    PortraitView(params: PortraitParams(entity["portrait"], spec: store.ref.portrait), spec: store.ref.portrait)
                        .frame(width: 44)
                }
                if col == "maps" {
                    MapPicture(store: store, map: entity)
                        .frame(width: 96, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.title(col, entity)).font(.headline)
                    let sub = subtitle
                    if !sub.isEmpty { Text(sub).font(.caption).foregroundColor(.secondary) }
                    let text = store.textOf(col, entity).replacingOccurrences(of: "\n", with: " ")
                    if !text.isEmpty { Text(text).font(.caption).foregroundColor(.secondary).lineLimit(2) }
                    if !entity.strings("tags").isEmpty {
                        HStack(spacing: 4) { ForEach(entity.strings("tags").prefix(5), id: \.self) { TagChip(tag: $0) } }
                    }
                }
                if showType {
                    Spacer()
                    Chip(text: store.def(col)?.singular ?? col)
                }
            }
        }
    }

    private var subtitle: String {
        let e = entity
        var parts: [String] = []
        switch col {
        case "characters":
            parts = [store.speciesOf(e).compactMap { store.get("species", $0) }.map { store.title("species", $0) }.joined(separator: "/"), e.string("role"), e.string("status")] + e.strings("cultures").compactMap { store.ref.culture($0)?.region }
        case "abilities": parts = [e.string("category"), store.get("powerSystems", e.string("system")).map { store.title("powerSystems", $0) } ?? "", e.string("rank")]
        case "powerSystems": parts = [e.string("kind"), e.string("hardness")]
        case "gear": parts = [e.string("kind"), e.string("rarity"), store.get("characters", e.string("owner")).map { "held by " + store.title("characters", $0) } ?? ""]
        case "curses": parts = [e.string("kind"), e.string("severity"), e.string("status")]
        case "blessings": parts = [e.string("kind"), e.string("strength"), e.string("status")]
        case "traits": parts = [e.string("kind"), e.string("mode")]
        case "paradoxes": parts = [e.string("kind"), e.string("status")]
        case "species": parts = [e.string("kind"), e.string("sapience"), e.number("lifespan").map { "~\(fmt($0)) yrs" } ?? ""]
        case "pets": parts = [store.get("species", e.string("species")).map { store.title("species", $0) } ?? "", e.string("kind"), e.strings("bondedTo").compactMap { store.get("characters", $0) }.map { store.title("characters", $0) }.joined(separator: ", "), e.string("status") == "alive" ? "" : e.string("status")]
        case "factions": parts = [e.string("kind"), e.string("status"), store.get("places", e.string("seat")).map { "seat: " + store.title("places", $0) } ?? ""]
        case "rivalries": parts = [e.string("kind"), e.string("intensity"), e.string("status")]
        case "conflicts": parts = [e.string("kind"), e.string("status"), e.number("start").map { "#\(fmt($0))–" + (e.number("end").map { fmt($0) } ?? "") } ?? e.string("era")]
        case "bonds": parts = e.strings("tradition").map { store.refData.label("kinship", $0) } + [e.string("status")]
        case "labels": parts = [e.string("kind"), e.string("field"), e.string("color")]
        case "lineages": parts = [e.string("kind"), e.string("inheritance")]
        case "cultures": parts = [e.string("kind")] + e.strings("realPeoples").map { store.refData.label("peoples", $0) }
        case "religions": parts = [e.string("kind")] + e.strings("basedOn").map { store.refData.label("religions", $0) }
        case "languages": parts = [e.string("kind")] + e.strings("basedOn").map { store.refData.label("languages", $0) }
        case "origins": parts = [e.string("kind"), e.string("place")]
        case "works": parts = [e.string("medium"), e.string("status"), e.number("order").map { "#\(Int($0))" } ?? ""]
        case "storylines": parts = [store.title("works", store.get("works", e.string("work"))), store.ref.style(e.string("style"))?.name ?? ""]
        case "events": parts = [e.string("when"), e.string("type")]
        case "research": parts = [e.string("kind"), e.string("source")]
        case "places": parts = [e.string("kind"), e.string("realm"), e.string("era"), store.get("places", e.string("parent")).map { "in " + store.title("places", $0) } ?? ""]
        case "maps": parts = [e.string("scale"), store.ref.mapStyle(e.string("mapStyle")).name, e.string("era")]
        case "links": parts = ["\(store.title(ref: e.string("from"))) → \(store.title(ref: e.string("to")))"]
        default: break
        }
        return parts.filter { !$0.isEmpty && $0 != "(missing)" }.joined(separator: " · ")
    }
}

struct CollectionListView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let col: String
    @State private var query = ""
    @State private var tag = ""

    private var items: [Entity] {
        var list = store.list(col).filter { e in
            (query.isEmpty || (store.title(col, e) + " " + store.textOf(col, e)).localizedCaseInsensitiveContains(query)) &&
            (tag.isEmpty || e.strings("tags").contains(tag))
        }
        if col == "works" { list.sort { ($0.number("order") ?? 1e9) < ($1.number("order") ?? 1e9) } }
        return list
    }

    private var allTags: [String] {
        Array(Set(store.list(col).flatMap { $0.strings("tags") })).sorted()
    }

    var body: some View {
        let def = store.def(col)
        List {
            if col == "powerSystems" { PowerRootsSection() }
            if col == "traits" { TraitTemplatesSection() }
            if col == "species" { SpeciesTemplatesSection() }
            if !allTags.isEmpty {
                Picker("Tag", selection: $tag) {
                    Text("All tags").tag("")
                    ForEach(allTags, id: \.self) { Text($0).tag($0) }
                }
            }
            ForEach(items) { e in EntityRow(col: col, entity: e) }
            if items.isEmpty {
                Text(store.list(col).isEmpty ? "No \(def?.label.lowercased() ?? "entries") yet. Tap + to start." : "No matches.")
                    .foregroundColor(.secondary)
            }
        }
        .searchable(text: $query, prompt: "Filter \(def?.label.lowercased() ?? "")")
        .navigationTitle(def?.label ?? col)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let e = store.newEntity(col)
                    router.push(.entity(col, e.id))
                } label: { Label("New \(def?.singular ?? "")", systemImage: "plus") }
            }
        }
    }
}

extension Store {
    /// Creates a blank entry with sensible starting values.
    func newEntity(_ col: String, _ extra: [String: JSONValue] = [:]) -> Entity {
        var fields = extra
        if col == "characters" && fields["portrait"] == nil {
            fields["portrait"] = PortraitParams.random(spec: ref.portrait).json
        }
        if col == "maps" {
            let scale = fields["scale"]?.string ?? "region"
            if fields["scale"] == nil { fields["scale"] = .string(scale) }
            if fields["mapStyle"] == nil { fields["mapStyle"] = .string("wow") }
            if fields["canvas"] == nil {
                let size = ref.mapSize(scale)
                fields["canvas"] = MapCanvas(width: size.0, height: size.1).json
            }
        }
        if let tf = def(col)?.titleField, fields[tf] == nil { fields[tf] = .string("") }
        return create(col, fields)
    }
}

// MARK: - Editor

struct EntityEditorView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let col: String
    let id: String
    @State private var confirmDelete = false

    var body: some View {
        if let def = store.def(col), let entity = store.get(col, id) {
            Form {
                ForEach(def.fields) { f in
                    Section(f.label) {
                        FieldEditor(col: col, id: id, field: f)
                    }
                }
                if col == "places" {
                    Section("Place web") { PlacePanel(placeID: id) }
                }
                if col == "characters" {
                    Section("Journey") { JourneyPanel(characterID: id) }
                    Section("Family & lineage") { FamilyPanel(characterID: id) }
                }
                if col == "characters" {
                    Section("Gear, curses & blessings") { InventoryPanel(characterID: id) }
                    Section("Chosen family, mentors & bonds") { BondsPanel(characterID: id) }
                    Section("Heirlooms") { CharacterHeirloomsPanel(characterID: id) }
                }
                if col == "bonds" { Section("This bond") { BondPanel(bondID: id) } }
                if col == "species" { Section("Species web") { SpeciesPanel(speciesID: id) } }
                if col == "pets" { Section("Companion") { PetPanel(petID: id) } }
                if col == "characters" { Section("Species & companions") { CharacterBeingPanel(characterID: id) } }
                if col == "places" { Section("Beings here") { PlaceBeingPanel(placeID: id) } }
                if col == "conflicts" { Section("The conflict at a glance") { ConflictPanel(conflictID: id) } }
                if col == "rivalries" { Section("Rivalry") { RivalryPanel(rivalryID: id) } }
                if col == "factions" { Section("Faction web") { FactionPanel(factionID: id) } }
                if col == "characters" { Section("Rivalries, wars & renown") { CharacterConflictPanel(characterID: id) } }
                if col == "places" { Section("Power & war here") { PlaceConflictPanel(placeID: id) } }
                if col == "gear" { Section("Heirloom line") { HeirloomPanel(gearID: id) } }
                if col == "lineages" { Section("Heirlooms") { LineageHeirloomsPanel(lineageID: id) } }
                if col == "places" { Section("Kept here, cursed & blessed") { PlaceInventoryPanel(placeID: id) } }
                if col == "gear" { Section("Custody & enchantments") { GearPanel(gearID: id) } }
                if col == "curses" || col == "blessings" { Section(col == "curses" ? "Who and what is cursed" : "Who and what is blessed") { EffectPanel(col: col, entryID: id) } }
                if col == "paradoxes" { Section("What this paradox explains") { ParadoxPanel(paradoxID: id) } }
                if col == "abilities" { Section("Trace this power") { AbilityTracePanel(abilityID: id) } }
                if col == "powerSystems" { Section("System map") { PowerSystemPanel(systemID: id) } }
                if col == "lineages" { Section("Family tree") { LineagePanel(lineageID: id) } }
                if col == "cultures" { Section("People web") { CulturePanel(cultureID: id) } }
                if col == "religions" { Section("Faith web") { ReligionPanel(religionID: id) } }
                if col == "languages" { Section("Language web") { LanguagePanel(languageID: id) } }
                if Store.checkableCollections.contains(col) {
                    Section("Originality") { OriginalityPanel(col: col, id: id) }
                }
                Section("Connections") { ConnectionsPanel(col: col, id: id) }
                if col == "characters" {
                    Section("Across your media") { AppearancesPanel(characterID: id) }
                }
            }
            .navigationTitle(store.title(col, entity))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if col == "characters" {
                        Button { router.push(.breakdown(id)) } label: { Label("Breakdown", systemImage: "person.text.rectangle") }
                    }
                    Menu {
                        Button {
                            if let copy = store.duplicate(col, id) { router.push(.entity(col, copy.id)) }
                        } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .confirmationDialog("Delete “\(store.title(col, entity))”? A snapshot is kept in Backups.", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.snapshot("Before delete")
                    router.pop()
                    store.remove(col, id)
                }
            }
        } else {
            Text("This entry no longer exists.").foregroundColor(.secondary)
        }
    }
}

struct FieldEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let col: String
    let id: String
    let field: FieldDef

    private var value: JSONValue { store.value(col, id, field.key) }
    private func set(_ v: JSONValue) { store.update(col, id, field.key, v) }

    var body: some View {
        switch field.type {
        case "text":
            TextField(field.label, text: store.stringBinding(col, id, field.key))
        case "textarea":
            TextField(field.label, text: store.stringBinding(col, id, field.key), axis: .vertical)
                .lineLimit(3...30)
        case "number":
            NumberField(initial: value.number) { v in set(v.map { JSONValue.number($0) } ?? JSONValue.null) }
        case "select":
            SelectField(col: col, id: id, field: field)
        case "style":
            StylePicker(selection: store.stringBinding(col, id, field.key, nullWhenEmpty: true))
        case "ref":
            RefPicker(target: field.collection ?? "", selection: store.stringBinding(col, id, field.key, nullWhenEmpty: true))
        case "refs":
            RefsEditor(target: field.collection ?? "", ids: value.stringArray) { set(.strings($0)) }
        case "cultures":
            ToggleChips(items: store.ref.culturePools.map { Option(id: $0.id, label: $0.region) }, selected: value.stringArray) { set(.strings($0)) }
        case "rasas":
            ToggleChips(items: store.ref.rasas.map { Option(id: $0.id, label: "\($0.name) · \($0.meaning)") }, selected: value.stringArray) { set(.strings($0)) }
        case "tags":
            TagsField(initial: value.stringArray) { set(.strings($0)) }
        case "stages":
            StagesEditor(col: col, id: id, key: field.key)
        case "portrait":
            PortraitBuilder(spec: store.ref.portrait, value: store.binding(col, id, field.key))
        case "ink":
            InkFieldPreview(col: col, id: id, key: field.key)
        case "mapstyle":
            let current = store.ref.mapStyle(value.string)
            Picker("Visual style", selection: Binding(get: { current.id }, set: { set(.string($0)) })) {
                ForEach(store.ref.mapStyles) { s in Text(s.name).tag(s.id) }
            }
            Text(current.inspiration).font(.caption).foregroundColor(.secondary)
            if let care = current.care { Text("Care: " + care).font(.caption).foregroundColor(.wowGoldDeep) }
        case "genome":
            GenomeEditor(col: col, characterID: id)
        case "issuekeys":
            IssueKeysEditor(keys: value.stringArray) { set(.strings($0)) }
        case "refdata":
            RefDataPicker(source: field.source ?? "", ids: value.stringArray) { set(.strings($0)) }
        case "mapcanvas":
            Button { router.pop() } label: { Label("Back to the map designer", systemImage: "map") }
        case "anyrefs":
            AnyRefsEditor(values: value.stringArray) { set(.strings($0)) }
        case "anyref":
            AnyRefPicker(selection: store.stringBinding(col, id, field.key, nullWhenEmpty: true))
        default:
            Text("Unsupported field type \(field.type)").foregroundColor(.secondary)
        }
    }
}

/// A dropdown with built-in options, the writer's own options, and "Add option…".
struct SelectField: View {
    @EnvironmentObject var store: Store
    let col: String
    let id: String
    let field: FieldDef
    @State private var adding = false
    @State private var newOption = ""

    var body: some View {
        let current = store.value(col, id, field.key).string ?? ""
        let options = store.optionsFor(col, field)
        HStack {
            Picker(field.label, selection: store.stringBinding(col, id, field.key, nullWhenEmpty: true)) {
                Text("—").tag("")
                ForEach(options, id: \.self) { Text($0).tag($0) }
                if !current.isEmpty && !options.contains(current) { Text(current).tag(current) }
            }
            Button { adding = true } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add option")
        }
        .alert("Add your own option to “\(field.label)”", isPresented: $adding) {
            TextField("Option", text: $newOption)
            Button("Add") {
                let name = newOption.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    if !options.contains(name) {
                        store.create("labels", ["name": .string(name), "kind": .string("menu option"), "field": .string("\(col).\(field.key)")])
                    }
                    store.update(col, id, field.key, .string(name))
                }
                newOption = ""
            }
            Button("Cancel", role: .cancel) { newOption = "" }
        }
    }
}

/// Number entry that keeps your typing intact (e.g. "3.") while saving numbers.
struct NumberField: View {
    @State private var text: String
    let onChange: (Double?) -> Void

    init(initial: Double?, onChange: @escaping (Double?) -> Void) {
        _text = State(initialValue: initial.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? "")
        self.onChange = onChange
    }

    var body: some View {
        TextField("Number", text: $text)
            .keyboardType(.numbersAndPunctuation)
            .onChange(of: text) { newValue in
                let t = newValue.trimmingCharacters(in: .whitespaces)
                onChange(t.isEmpty ? nil : Double(t))
            }
    }
}

/// Comma-separated tags; keeps your typing intact while saving an array.
struct TagsField: View {
    @State private var text: String
    let onChange: ([String]) -> Void

    init(initial: [String], onChange: @escaping ([String]) -> Void) {
        _text = State(initialValue: initial.joined(separator: ", "))
        self.onChange = onChange
    }

    var body: some View {
        TextField("comma, separated, tags", text: $text)
            .textInputAutocapitalization(.never)
            .onChange(of: text) { newValue in
                onChange(newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
            }
    }
}

struct StylePicker: View {
    @EnvironmentObject var store: Store
    @Binding var selection: String

    var body: some View {
        let regions = store.ref.narrativeStyles.reduce(into: [String]()) { acc, s in
            if !acc.contains(s.region) { acc.append(s.region) }
        }
        Picker("Narrative style", selection: $selection) {
            Text("— choose a narrative style —").tag("")
            ForEach(regions, id: \.self) { region in
                Section(region) {
                    ForEach(store.ref.narrativeStyles.filter { $0.region == region }) { s in
                        Text(s.name).tag(s.id)
                    }
                }
            }
        }
        if !selection.isEmpty {
            NavigationLink(value: Route.style(selection)) { Text("About this style").font(.callout) }
        }
    }
}

struct RefPicker: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let target: String
    @Binding var selection: String

    var body: some View {
        let singular = store.def(target)?.singular.lowercased() ?? "entry"
        Picker("Choose \(singular)", selection: $selection) {
            Text("—").tag("")
            ForEach(store.options(target)) { o in Text(o.label).tag(o.id) }
        }
        HStack {
            Button {
                let e = store.newEntity(target)
                selection = e.id
                router.push(.entity(target, e.id))
            } label: { Label("New \(singular)", systemImage: "plus") }
            .buttonStyle(.borderless)
            Spacer()
            if !selection.isEmpty {
                Button("Open") { router.push(.entity(target, selection)) }.buttonStyle(.borderless)
            }
        }
    }
}

struct RefsEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let target: String
    let ids: [String]
    let onChange: ([String]) -> Void

    var body: some View {
        let singular = store.def(target)?.singular.lowercased() ?? "entry"
        ForEach(ids, id: \.self) { rid in
            HStack {
                Button(store.title(target, store.get(target, rid))) { router.push(.entity(target, rid)) }
                    .buttonStyle(.borderless)
                Spacer()
                Button { onChange(ids.filter { $0 != rid }) } label: { Image(systemName: "minus.circle.fill").foregroundColor(.red) }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove")
            }
        }
        Menu {
            ForEach(store.options(target).filter { !ids.contains($0.id) }) { o in
                Button(o.label) { onChange(ids + [o.id]) }
            }
            Divider()
            Button {
                let e = store.newEntity(target)
                onChange(ids + [e.id])
                router.push(.entity(target, e.id))
            } label: { Label("Create new \(singular)", systemImage: "plus") }
        } label: {
            Label("Add \(singular)", systemImage: "plus.circle")
        }
    }
}

struct ToggleChips: View {
    let items: [Option]
    let selected: [String]
    let onChange: ([String]) -> Void

    var body: some View {
        FlowLayout {
            ForEach(items) { it in
                let on = selected.contains(it.id)
                Button {
                    onChange(on ? selected.filter { $0 != it.id } : selected + [it.id])
                } label: { Chip(text: it.label, on: on) }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StagesEditor: View {
    @EnvironmentObject var store: Store
    let col: String
    let id: String
    let key: String

    var body: some View {
        if let style = store.ref.style(store.value(col, id, "style").string) {
            VStack(alignment: .leading, spacing: 4) {
                Text(style.name).font(.headline)
                Text(style.summary).font(.callout).foregroundColor(.secondary)
                if let care = style.care {
                    Text("Cultural care: \(care)").font(.caption).foregroundColor(.wowGoldDeep)
                }
            }
            ForEach(style.stages) { st in
                VStack(alignment: .leading, spacing: 6) {
                    Text(st.name).font(.subheadline.weight(.semibold))
                    Text(st.prompt).font(.caption).foregroundColor(.secondary)
                    TextField(st.name, text: binding(st.id), axis: .vertical)
                        .lineLimit(2...30)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.wowVioletSoft.opacity(0.08)))
                }
                .padding(.leading, 10)
                .overlay(alignment: .leading) { Rectangle().fill(Color.wowGold).frame(width: 3) }
            }
        } else {
            Text("Choose a narrative style above to lay out its beats here.").foregroundColor(.secondary)
        }
    }

    private func binding(_ stageID: String) -> Binding<String> {
        Binding(
            get: { store.value(col, id, key).object?[stageID]?.string ?? "" },
            set: { newValue in
                var obj = store.value(col, id, key).object ?? [:]
                obj[stageID] = .string(newValue)
                store.update(col, id, key, .object(obj))
            }
        )
    }
}

struct AnyRefPicker: View {
    @EnvironmentObject var store: Store
    @Binding var selection: String
    @State private var col = ""

    var body: some View {
        let current = splitRef(selection)
        let activeCol = col.isEmpty ? (current?.0 ?? "characters") : col
        Picker("Type", selection: Binding(get: { activeCol }, set: { col = $0; selection = "" })) {
            ForEach(store.ref.collections.filter { $0.id != "links" }) { c in Text(c.singular).tag(c.id) }
        }
        Picker("Entry", selection: Binding(
            get: { current?.0 == activeCol ? (current?.1 ?? "") : "" },
            set: { selection = $0.isEmpty ? "" : "\(activeCol):\($0)" }
        )) {
            Text("—").tag("")
            ForEach(store.options(activeCol)) { o in Text(o.label).tag(o.id) }
        }
    }
}
