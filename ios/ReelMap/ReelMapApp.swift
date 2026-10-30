import SwiftUI

@main struct ReelMapApp: App {
    @State private var library = Library()
    var body: some Scene { WindowGroup { ContentView(library: library).tint(.green) } }
}
