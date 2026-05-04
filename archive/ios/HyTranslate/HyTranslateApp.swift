import SwiftUI
import SwiftData

@main
struct HyTranslateApp: App {

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: TranslationRecord.self)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { TranslateView() }
                .tabItem { Label("翻译", systemImage: "character.bubble") }
            NavigationStack { HistoryView() }
                .tabItem { Label("历史", systemImage: "clock") }
            NavigationStack { SettingsView() }
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
