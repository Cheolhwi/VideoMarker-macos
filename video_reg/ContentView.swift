import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var recognizedResults: [(String, Double)] = [] // 存储文本和时间
    @State private var isProcessing: Bool = false // 控制进度条的显示
    @State private var progress: Double = 0.0 // 控制进度条的进度
    @State private var player = AVPlayer() // AVPlayer 实例
    @State private var playerItem: AVPlayerItem? // 当前的播放项目
    @State private var showFileImporter = false // 控制是否显示文件选择器
    @State private var selectedVideoURL: URL? // 存储用户选择的视频URL
    @State private var errorMessage: String? // 显示错误消息
    
    // 两列布局
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // 视频播放器
            if let selectedVideoURL = selectedVideoURL {
                VideoPlayerView(player: player) // 使用系统级播放器 AVPlayerView
                    .frame(height: 400) // 设置播放器的高度
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.horizontal)
            } else {
                Text("No video selected")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            // 使用两列布局
            if !recognizedResults.isEmpty {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) { // 通过 LazyVGrid 创建两列布局
                        ForEach(recognizedResults, id: \.1) { (text, time) in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("[\(formatTime(seconds: time))]") // 时间戳放在文字前
                                        .foregroundColor(.blue)
                                        .underline()
                                        .onTapGesture {
                                            seekToTime(seconds: time)
                                        }
                                    Text(text)
                                        .font(.body)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                                .shadow(radius: 2)
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 300) // 设置 ScrollView 高度
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            } else {
                Text("No text recognized yet.")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    showFileImporter = true // 显示文件选择器
                }) {
                    HStack {
                        Image(systemName: "folder.fill")
                        Text("Select Video File")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                }
                .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            print("Selected video file URL: \(url)") // 调试日志
                            selectedVideoURL = url
                            errorMessage = nil // 清除之前的错误消息
                            setupPlayer(with: url) // 设置播放器
                        }
                    case .failure(let error):
                        errorMessage = "Failed to select file: \(error.localizedDescription)"
                        print("File selection error: \(error.localizedDescription)") // 调试日志
                        selectedVideoURL = nil
                    }
                }
                
                Button(action: {
                    if selectedVideoURL != nil {
                        processVideo() // 处理用户选择的视频
                    }
                }) {
                    HStack {
                        Image(systemName: "text.magnifyingglass")
                        Text(isProcessing ? "Processing..." : "Process Video")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isProcessing ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                }
                .disabled(isProcessing || selectedVideoURL == nil)
            }
            .padding(.horizontal)
            
            if isProcessing {
                VStack {
                    ProgressView(value: progress, total: 1.0)
                        .padding()
                    Text("Processing \(Int(progress * 100))%")
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 20)
        .background(Color(NSColor.windowBackgroundColor)) // 修复背景颜色问题
        .edgesIgnoringSafeArea(.all)
    }
    
    // 视频处理逻辑仅在按钮点击时调用
    func processVideo() {
        isProcessing = true // 设置为正在处理
        progress = 0.0 // 初始化进度
        
        if let videoURL = selectedVideoURL {
            print("Processing video at URL: \(videoURL)") // 调试日志
            let processor = VideoProcessor()
            
            processor.extractTextFromVideo(videoURL: videoURL, frameInterval: 15, progressHandler: { currentProgress in
                DispatchQueue.main.async {
                    self.progress = currentProgress // 更新进度条
                }
            }, completion: { results in
                DispatchQueue.main.async {
                    self.recognizedResults = self.removeDuplicates(results) // 更新识别文本并去重
                    self.isProcessing = false // 处理完成，更新状态
                }
            })
        }
    }
    
    // 设置播放器并加载用户选择的视频，不自动播放
    func setupPlayer(with url: URL) {
        print("Setting up player with video URL: \(url)") // 调试日志
        self.playerItem = AVPlayerItem(url: url)
        self.player.replaceCurrentItem(with: playerItem)
    }
    
    // 跳转到指定时间
    func seekToTime(seconds: Double) {
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: targetTime)
        player.play() // 自动播放
    }
    
    // 去除重复的识别结果
    func removeDuplicates(_ results: [(String, Double)]) -> [(String, Double)] {
        var uniqueResults = [(String, Double)]()
        var seenTexts = Set<String>()
        
        for result in results {
            if !seenTexts.contains(result.0) {
                uniqueResults.append(result)
                seenTexts.insert(result.0)
            }
        }
        return uniqueResults
    }
    
    // 将时间格式化为 "分钟:秒" 格式
    func formatTime(seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

