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

extension FixedWidthInteger {
    var littleEndianData: Data {
        withUnsafeBytes(of: self.littleEndian, { Data($0) })
    }
}

func createWAVFile(from pcmData: Data) -> Data {
    let sampleRate: UInt32 = 24_000
    let bitsPerSample: UInt32 = 16
    let numChannels: UInt32 = 1
    
    let byteRate = sampleRate * numChannels * bitsPerSample / 8
    let blockAlign = numChannels * bitsPerSample / 8
    let dataSize = UInt32(pcmData.count)
    let chunkSize = 36 + dataSize

    var header = Data()

    header.append("RIFF".data(using: .ascii)!)
    header.append(UInt32(chunkSize).littleEndianData)
    header.append("WAVE".data(using: .ascii)!)
    header.append("fmt ".data(using: .ascii)!)
    header.append(UInt32(16).littleEndianData) // Subchunk1Size
    header.append(UInt16(1).littleEndianData)  // PCM format
    header.append(UInt16(numChannels).littleEndianData)
    header.append(UInt32(sampleRate).littleEndianData)
    header.append(UInt32(byteRate).littleEndianData)
    header.append(UInt16(blockAlign).littleEndianData)
    header.append(UInt16(bitsPerSample).littleEndianData)
    header.append("data".data(using: .ascii)!)
    header.append(UInt32(dataSize).littleEndianData)
    header.append(pcmData)

    return header
}

func timestamp() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
    let timestamp = dateFormatter.string(from: Date())
    
    return timestamp
}

func convertBufferTo16kMonoPCM(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
	// Target format: 16kHz, mono, 16-bit PCM, interleaved
	guard let targetFormat = AVAudioFormat(
		commonFormat: .pcmFormatInt16,
		sampleRate: 16_000,
		channels: 1,
		interleaved: true
	) else {
		throw NSError(domain: "Recorder", code: -1,
					  userInfo: [NSLocalizedDescriptionKey: "Failed to create target format"])
	}

	// Create AVAudioConverter
	guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
		throw NSError(domain: "Recorder", code: -2,
					  userInfo: [NSLocalizedDescriptionKey: "Failed to create converter"])
	}

	// Calculate approximate output frame capacity
	let ratio = targetFormat.sampleRate / buffer.format.sampleRate
	let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

	// Create output buffer
	guard let outBuffer = AVAudioPCMBuffer(
		pcmFormat: targetFormat,
		frameCapacity: outCapacity
	) else {
		throw NSError(domain: "Recorder", code: -3,
					  userInfo: [NSLocalizedDescriptionKey: "Failed to create output buffer"])
	}

	// Perform the conversion synchronously
	try converter.convert(to: outBuffer, from: buffer)

	return outBuffer
}


func base64EncodeBuffer(_ buffer: AVAudioPCMBuffer) -> String? {
    // Make sure the buffer format is Int16 for direct byte extraction
    guard let int16ChannelData = buffer.int16ChannelData else {
        print("Buffer is not in 16-bit PCM format")
        return nil
    }
    let channelData = int16ChannelData[0]   // Mono: first channel
    let dataSize = Int(buffer.frameLength) * MemoryLayout<Int16>.size
    let audioData = Data(bytes: channelData, count: dataSize)
    
    return audioData.base64EncodedString()
}

func hasSpeech(in pcmData: Data, sampleRate: Int = 16000, threshold: Float = 0.01) -> Bool {
    let samples = pcmData.withUnsafeBytes {
        Array(UnsafeBufferPointer<Int16>(start: $0.baseAddress!.assumingMemoryBound(to: Int16.self),
                                         count: pcmData.count / MemoryLayout<Int16>.size))
    }

    let energy = samples.reduce(0.0) { sum, sample in
        let normalized = Float(sample) / Float(Int16.max)
        return sum + normalized * normalized
    } / Float(samples.count)

    return energy > threshold
}
