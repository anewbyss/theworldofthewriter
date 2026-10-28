import SwiftUI

@main
struct WowBrainstormApp: App {
    @StateObject private var store = Store()
    @StateObject private var router = Router()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(router)
                .tint(.wowViolet)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { store.saveNow() }
        }
    }
}

/// Places the app can navigate to inside the detail column.
enum Route: Hashable {
    case entity(String, String)
    case style(String)
    case culture(String)
    case breakdown(String)
    case ink(String, String, String)
}

final class Router: ObservableObject {
    @Published var path = NavigationPath()
    func push(_ r: Route) { path.append(r) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func reset() { path = NavigationPath() }
}

extension View {
    func withRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .entity(let col, let id): EntityEditorView(col: col, id: id)
            case .style(let id): StyleDetailView(styleID: id)
            case .culture(let id): CultureDetailView(cultureID: id)
            case .breakdown(let id): BreakdownView(id: id)
            case .ink(let col, let id, let key): InkPageView(col: col, id: id, key: key)
            }
        }
    }
}
