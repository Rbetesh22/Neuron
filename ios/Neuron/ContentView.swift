import SwiftUI

struct ContentView: View {
    @EnvironmentObject var api: APIClient
    @State private var selectedTab: Tab = .home

    enum Tab {
        case home, ask, news, sparks, library
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home",    systemImage: "house") }
                .tag(Tab.home)

            AskView()
                .tabItem { Label("Ask",     systemImage: "bubble.left.and.bubble.right") }
                .tag(Tab.ask)

            NewsView()
                .tabItem { Label("News",    systemImage: "newspaper") }
                .tag(Tab.news)

            SparksView()
                .tabItem { Label("Sparks",  systemImage: "bolt") }
                .tag(Tab.sparks)

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(Tab.library)
        }
        .tint(.primary)
    }
}
