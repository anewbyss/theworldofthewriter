import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @Binding var selection: SidebarItem?
    @State private var quickTitle = ""
    @State private var quickText = ""
    @State private var spark = ""
    @State private var saved = false
    @State private var welcome = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(eyebrow: "Welcome back", title: "WOW Brainstorm", subtitle: "Write, track, research and build continuity across every book and medium. No generative AI — your words, your world.")

                if needsBackupReminder {
                    Button { selection = .backup } label: {
                        Label(store.meta.lastExport == nil ? "You haven't exported a backup yet. Back up now →" : "Your last backup export was over a week ago. Back up now →", systemImage: "exclamationmark.triangle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.wowGold.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                }

                let filled = store.ref.collections.filter { $0.id != "links" && $0.id != "labels" && !store.list($0.id).isEmpty }
                if filled.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR WORLD IS WAITING").font(.caption.weight(.bold)).foregroundColor(.wowGold)
                        Text("Where will it begin?").font(.system(.title, design: .serif).weight(.bold)).foregroundColor(.white)
                        Text("Pick a door. Everything you make links to everything else: characters to peoples, powers to lineages, wars to maps.").foregroundColor(.white.opacity(0.8))
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.wowViolet, .wowVioletBright], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    DoorsGrid { d in
                        let (item, route) = store.destination(of: d)
                        go(item, route)
                    }
                }
                HStack {
                    Text("Today's inspiration").font(.system(.title3, design: .serif).weight(.bold))
                    Spacer()
                    Button("Open the welcome screen") { welcome = true }.font(.callout)
                }
                InspirationRow { go($0, $1) }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filled) { c in
                        Button { selection = c.id == "events" ? SidebarItem.continuity : SidebarItem.collection(c.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(systemName: c.icon).foregroundColor(.wowGoldDeep)
                                Text("\(store.list(c.id).count)").font(.system(size: 32, weight: .bold, design: .serif)).foregroundColor(.wowViolet)
                                Text(c.label).font(.callout).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(uiColor: .secondarySystemGroupedBackground)))
                        }
                        .buttonStyle(.plain)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        quickCapture.frame(minWidth: 380)
                        VStack(spacing: 16) { sparkCard; recentCard }.frame(width: 320)
                    }
                    VStack(spacing: 16) { quickCapture; sparkCard; recentCard }
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if spark.isEmpty { rollSpark() } }
        .fullScreenCover(isPresented: $welcome) {
            OpeningView { item, route in
                welcome = false
                go(item, route)
            }
            .environmentObject(store)
            .environmentObject(router)
        }
    }

    /// Switch sidebar page (if it changes), then open an entry once the page's stack has reset.
    private func go(_ item: SidebarItem?, _ route: Route?) {
        let changes = item != nil && item != selection
        if let item = item { selection = item }
        if let route = route {
            DispatchQueue.main.asyncAfter(deadline: .now() + (changes ? 0.35 : 0)) { router.push(route) }
        }
    }

    private var needsBackupReminder: Bool {
        guard store.hasData else { return false }
        guard let last = store.meta.lastExport, let d = isoFormatter.date(from: last) else { return true }
        return Date().timeIntervalSince(d) > 7 * 86400
    }

    private func rollSpark() { spark = store.ref.sparkTables["storySpark"]?.randomElement() ?? "" }

    private var quickCapture: some View {
        Card(accent: true) {
            Text("Quick capture").font(.system(.title3, design: .serif).weight(.bold))
            TextField("Title", text: $quickTitle).textFieldStyle(.roundedBorder)
            TextField("Catch the idea before it flies — type, dictate, or Scribble with Apple Pencil…", text: $quickText, axis: .vertical)
                .lineLimit(4...12)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Save note") {
                    guard !(quickTitle.isEmpty && quickText.isEmpty) else { return }
                    store.create("notes", ["title": .string(quickTitle.isEmpty ? "Quick note" : quickTitle), "text": .string(quickText), "tags": .strings(["capture"])])
                    quickTitle = ""
                    quickText = ""
                    saved = true
                }
                .buttonStyle(.borderedProminent)
                Button {
                    let e = store.newEntity("notes", ["title": .string("Handwritten page")])
                    router.push(.ink("notes", e.id, "ink"))
                } label: { Label("Handwrite instead", systemImage: "applepencil") }
                .buttonStyle(.bordered)
                if saved { Text("Saved to Ink Pages").font(.caption).foregroundColor(.secondary) }
            }
        }
    }

    private var sparkCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STORY SPARK").font(.caption.weight(.bold)).foregroundColor(.wowGold)
            Text(spark).font(.system(.title3, design: .serif)).foregroundColor(.white)
            Text("From the dice tables — your job is to make it yours.").font(.caption).foregroundColor(.white.opacity(0.75))
            HStack {
                Button("Roll again") { rollSpark() }.buttonStyle(.borderedProminent).tint(.wowGold).foregroundColor(.wowVioletDeep)
                Button("More dice") { selection = .spark }.foregroundColor(.wowGold)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.wowViolet, .wowVioletBright], startPoint: .topLeading, endPoint: .bottomTrailing)))
    }

    private var recentCard: some View {
        Card {
            Text("Recently touched").font(.headline)
            let items = store.recent(8)
            if items.isEmpty {
                Text("Nothing yet. Start with a character, a power, or a story spark.").foregroundColor(.secondary)
            }
            ForEach(items, id: \.entity.id) { item in
                Button { router.push(.entity(item.col, item.entity.id)) } label: {
                    HStack {
                        Text(store.title(item.col, item.entity)).lineLimit(1)
                        Spacer()
                        Chip(text: store.def(item.col)?.singular ?? "")
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
