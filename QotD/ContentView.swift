import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var showUserGuide = false

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(selection: $model.sidebar) {
                Label("Quotes", systemImage: "quote.bubble")
                    .tag(AppSidebar.quotes)
                Label("Settings", systemImage: "gearshape")
                    .tag(AppSidebar.settings)
            }
            .listStyle(.sidebar)
            .navigationTitle("QotD")
            .frame(minWidth: 160)
        } detail: {
            switch model.sidebar {
            case .quotes:
                QuotesListView()
            case .settings:
                SettingsView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showUserGuide = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .help("User Guide")
            }
        }
        .sheet(isPresented: $showUserGuide, onDismiss: {
            UserGuideStore.markSeen()
        }) {
            UserGuideView()
        }
        .onAppear {
            model.reloadFromDisk()
            if !UserGuideStore.hasSeen {
                showUserGuide = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .qotdOpenQuotes)) { _ in
            model.sidebar = .quotes
        }
        .onReceive(NotificationCenter.default.publisher(for: .qotdOpenSettings)) { _ in
            model.sidebar = .settings
        }
    }
}
