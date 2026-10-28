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
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var selection: SidebarItem? = .home

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
                Section("Powers") {
                    collectionRow("abilities")
                    collectionRow("powerSystems")
                    collectionRow("lineages")
                    collectionRow("origins")
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
                    row(.graph, "Connection Web", "point.3.connected.trianglepath.dotted", count: store.list("links").count)
                    row(.originality, "Originality", "magnifyingglass.circle")
                }
                Section("Research") {
                    row(.coverage, "World Coverage & Gaps", "chart.pie")
                    row(.atlas, "Culture Atlas", "globe.europe.africa")
                    row(.faiths, "Faiths Library", "building.columns")
                    row(.tongues, "Languages Library", "character.book.closed")
                    row(.styles, "Narrative Styles", "scroll")
                    collectionRow("research")
                    row(.spark, "Spark Dice", "dice")
                }
                Section("Keep") {
                    row(.search, "Search", "magnifyingglass")
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
    }

    private func row(_ item: SidebarItem, _ label: String, _ icon: String, count: Int? = nil) -> some View {
        HStack {
            Label(label, systemImage: icon)
            if let count = count {
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
