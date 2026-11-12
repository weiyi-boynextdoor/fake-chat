import SwiftUI

@main
struct FakeChatApp: App {
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store).preferredColorScheme(.light)
        }
    }
}
