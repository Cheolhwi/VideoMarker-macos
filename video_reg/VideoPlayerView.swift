import AVKit
import SwiftUI

// VideoPlayerView 将 NSViewRepresentable 嵌入 SwiftUI 来使用 AVPlayerView
struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.showsFullScreenToggleButton = true // 显示全屏切换按钮
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

