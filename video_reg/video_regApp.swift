import SwiftUI

@main
struct video_regApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView() // 只加载 ContentView，移除 onAppear 逻辑
        }
    }
}

