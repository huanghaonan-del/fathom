import SwiftUI

@main
struct FathomApp: App {
    @State private var store = VocabularyStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
