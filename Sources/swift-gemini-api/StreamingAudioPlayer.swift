// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import AVFoundation

#if os(iOS)
import AVFAudio
#endif

class StreamingAudioPlayer {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let playbackQueue = DispatchQueue(label: "streaming.audio.playback.queue")
    
    private var isPlaying = false
    private let sampleRate: Double = 24000
    private let channels: AVAudioChannelCount = 1
    
    private var audioFormat: AVAudioFormat!

    init() {
        // Use non-interleaved float32 format (AVAudioEngine expects this)
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )!
        self.audioFormat = format

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)

        do {
			#if os(iOS)
				try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
				try AVAudioSession.sharedInstance().setActive(true)
			#endif

            try audioEngine.start()
            print("✅ Audio engine started")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }

    func enqueue(_ data: Data) {
		playbackQueue.sync { [weak self] in
            self?.scheduleBuffer(data)
        }
    }

    private func scheduleBuffer(_ data: Data) {
        // Calculate frame count (each frame is 2 bytes for 16-bit mono)
        let frameCount = UInt32(data.count) / 2

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            print("❌ Failed to create buffer")
            return
        }

        buffer.frameLength = frameCount

        // Convert Int16 PCM to Float32 PCM
        data.withUnsafeBytes { rawBufferPointer in
            let int16Pointer = rawBufferPointer.bindMemory(to: Int16.self)
            let floatChannelData = buffer.floatChannelData![0]

            for i in 0..<Int(frameCount) {
                floatChannelData[i] = Float(int16Pointer[i]) / Float(Int16.max)
            }
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)

        if !isPlaying {
            playerNode.play()
            isPlaying = true
            print("▶️ Started playback")
        }
    }

    func stop() {
		playbackQueue.async { [weak self] in
            self?.playerNode.stop()
            self?.isPlaying = false
            print("⏹️ Playback stopped")
        }
    }
}
