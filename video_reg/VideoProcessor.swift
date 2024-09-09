import Foundation
import AVFoundation
import Vision

class VideoProcessor {
    
    func extractTextFromVideo(videoURL: URL, frameInterval: Int = 10, progressHandler: @escaping (Double) -> Void, completion: @escaping ([(String, Double)]) -> Void) {
        let asset = AVURLAsset(url: videoURL)
        
        let keys = ["duration"]
        asset.loadValuesAsynchronously(forKeys: keys) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            
            switch status {
            case .loaded:
                let totalDuration = CMTimeGetSeconds(asset.duration)
                if totalDuration == 0 {
                    completion([("Video duration is zero.", 0)])
                    return
                }
                
                self.loadTracksAndProcess(asset: asset, totalDuration: totalDuration, frameInterval: frameInterval, progressHandler: progressHandler, completion: completion)
                
            case .failed:
                completion([("Failed to load duration: \(error?.localizedDescription ?? "Unknown error")", 0)])
                
            default:
                completion([("Failed to load duration for unknown reasons.", 0)])
            }
        }
    }
    
    private func loadTracksAndProcess(asset: AVURLAsset, totalDuration: Double, frameInterval: Int, progressHandler: @escaping (Double) -> Void, completion: @escaping ([(String, Double)]) -> Void) {
        asset.loadTracks(withMediaType: .video) { tracks, error in
            if let error = error {
                completion([("Error loading tracks: \(error.localizedDescription)", 0)])
                return
            }
            
            guard let track = tracks?.first else {
                completion([("No video tracks found.", 0)])
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let reader = try AVAssetReader(asset: asset)
                    let settings = [String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA] as [String : Any]
                    let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
                    reader.add(output)
                    
                    var processedDuration: Double = 0
                    var results: [(String, Double)] = []
                    var frameCount = 0
                    
                    reader.startReading()
                    
                    while let sampleBuffer = output.copyNextSampleBuffer() {
                        frameCount += 1
                        if frameCount % frameInterval != 0 {
                            continue // 跳过帧，减少处理次数
                        }
                        
                        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }
                        
                        let presentationTime = sampleBuffer.presentationTimeStamp
                        processedDuration = CMTimeGetSeconds(presentationTime)
                        
                        self.recognizeText(in: pixelBuffer) { recognizedText in
                            if !recognizedText.isEmpty {
                                results.append((recognizedText, processedDuration))
                            }
                        }
                        
                        // 计算进度并在主线程更新
                        let progress = processedDuration / totalDuration
                        DispatchQueue.main.async {
                            progressHandler(progress)
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(results)
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        completion([("Error creating AVAssetReader: \(error.localizedDescription)", 0)])
                    }
                }
            }
        }
    }
    
    func recognizeText(in pixelBuffer: CVPixelBuffer, completion: @escaping (String) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion("Text recognition error: \(error.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            var recognizedText = ""
            
            for observation in observations {
                if let text = observation.topCandidates(1).first?.string {
                    recognizedText += text
                }
            }
            completion(recognizedText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        request.recognitionLanguages = ["zh-Hans", "zh-Hant"]
        request.usesLanguageCorrection = false
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            completion("Error performing text recognition: \(error.localizedDescription)")
        }
    }
}

