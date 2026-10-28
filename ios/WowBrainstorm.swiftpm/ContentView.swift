import SwiftUI

enum SidebarItem: Hashable {
    case home
    case collection(String)
    case continuity
    case graph
    case originality
    case styles
    case atlas
    case spark
    case backup
    case search
    case faiths
    case tongues
    case coverage
    case offspring
    case labels
    case figures
    case lore(String)
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var selection: SidebarItem? = .home
    @AppStorage("showOpening") private var showOpening = true
    @State private var openingShown = false
    @State private var launched = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    row(.home, "Home", "house")
                    collectionRow("characters")
                    collectionRow("storylines")
                    collectionRow("works")
                    collectionRow("notes")
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WOW Brainstorm").font(.system(.title2, design: .serif).weight(.bold)).foregroundColor(.wowGoldDeep)
                        Text("write · track · research · connect").font(.caption2).foregroundColor(.secondary)
                    }
                    .textCase(nil)
                    .padding(.bottom, 8)
                }
                Section("Beings") {
                    collectionRow("species")
                    collectionRow("pets")
                }
                Section("Powers") {
                    collectionRow("abilities")
                    collectionRow("powerSystems")
                    collectionRow("gear")
                    collectionRow("curses")
                    collectionRow("blessings")
                    collectionRow("origins")
                }
                Section("Bloodlines") {
                    collectionRow("lineages")
                    collectionRow("bonds")
                    collectionRow("traits")
                    row(.offspring, "Offspring Calculator", "figure.and.child.holdinghands")
                }
                Section("Conflict") {
                    collectionRow("factions")
                    collectionRow("rivalries")
                    collectionRow("conflicts")
                    row(.figures, "Notable Figures", "crown")
                }
                Section("World") {
                    collectionRow("cultures")
                    collectionRow("religions")
                    collectionRow("languages")
                    collectionRow("places")
                    collectionRow("maps")
                }
                Section("Track") {
                    row(.continuity, "Timeline & Continuity", "calendar.day.timeline.left", count: store.list("events").count)
                    collectionRow("paradoxes")
                    row(.graph, "Connection Web", "point.3.connected.trianglepath.dotted", count: store.list("links").count)
                    row(.originality, "Originality", "magnifyingglass.circle")
                }
                Section("Research") {
                    row(.coverage, "World Coverage & Gaps", "chart.pie")
                    row(.atlas, "Culture Atlas", "globe.europe.africa")
                    row(.faiths, "Faiths Library", "building.columns")
                    row(.tongues, "Languages Library", "character.book.closed")
                    row(.styles, "Narrative Styles", "scroll")
                    row(.lore("creatures"), "Bestiary", "pawprint")
                    row(.lore("wars"), "History & Myth", "building.columns")
                    collectionRow("research")
                    row(.spark, "Spark Dice", "dice")
                }
                Section("Keep") {
                    row(.search, "Search", "magnifyingglass")
                    row(.labels, "Labels & Tags", "tag")
                    row(.backup, "Backups & Data", "externaldrive")
                }
            }
            .navigationTitle("WOW")
        } detail: {
            NavigationStack(path: $router.path) {
                detail(selection ?? .home)
                    .withRoutes()
            }
        }
        .onChange(of: selection) { _ in router.reset() }
        .onAppear {
            if !launched { launched = true; openingShown = showOpening }
        }
        .fullScreenCover(isPresented: $openingShown) {
            OpeningView { item, route in
                openingShown = false
                go(item, route)
            }
            .environmentObject(store)
            .environmentObject(router)
        }
    }

    /// Switch sidebar page, then open an entry once the page's stack has reset.
    private func go(_ item: SidebarItem?, _ route: Route?) {
        if let item = item { selection = item }
        if let route = route {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.push(route) }
        }
    }

    private func row(_ item: SidebarItem, _ label: String, _ icon: String, count: Int? = nil) -> some View {
        HStack {
            Label(label, systemImage: icon)
            if let count = count, count > 0 {
                Spacer()
                Text("\(count)").font(.caption).foregroundColor(.secondary)
            }
        }
        .tag(item)
    }

    private func collectionRow(_ col: String) -> some View {
        let c = store.def(col)
        return row(.collection(col), c?.label ?? col, c?.icon ?? "doc", count: store.list(col).count)
    }

    @ViewBuilder
    private func detail(_ item: SidebarItem) -> some View {
        switch item {
        case .home: HomeView(selection: $selection)
        case .collection(let col): CollectionListView(col: col)
        case .continuity: ContinuityView()
        case .graph: GraphView()
        case .originality: OriginalityView()
        case .styles: StylesView()
        case .atlas: AtlasView()
        case .spark: SparkView()
        case .backup: BackupView()
        case .search: SearchView()
        case .faiths: FaithsLibraryView()
        case .tongues: LanguagesLibraryView()
        case .coverage: CoverageView()
        case .offspring: OffspringCalculatorView()
        case .labels: LabelsView()
        case .figures: FiguresView()
        case .lore(let source): LoreLibraryView(source: source).id(source)
        }
    }
}

struct SearchView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""

    var body: some View {
        List {
            ForEach(store.search(query), id: \.entity.id) { item in
                EntityRow(col: item.col, entity: item.entity, showType: true)
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search everything")
        .overlay {
            if query.isEmpty {
                Text("Search every character, ability, story and note.").foregroundColor(.secondary)
            }
        }
        .navigationTitle("Search")
    }
}
