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

public class StreamingWAVWriter {
    private let fileHandle: FileHandle
    private let fileURL: URL
    private let sampleRate: UInt32 = 16000
    private let bitsPerSample: UInt16 = 16
    private let numChannels: UInt16 = 1
    private var totalPCMBytesWritten: UInt32 = 0
    private var isClosed = false

    init(outputURL: URL) throws {
        self.fileURL = outputURL
        
        // Create empty file
        FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: nil)
        guard let handle = try? FileHandle(forUpdating: outputURL) else {
            throw NSError(domain: "StreamingWAVWriter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create file handle"])
        }
        self.fileHandle = handle

        // Write placeholder WAV header (will be updated live)
        let placeholderHeader = try makeWAVHeader(pcmDataSize: 0)
        fileHandle.write(placeholderHeader)
    }

    func appendBase64Chunk(_ base64: String) throws {
        guard let chunkData = Data(base64Encoded: base64) else {
            throw NSError(domain: "StreamingWAVWriter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid base64 chunk"])
        }

        try fileHandle.seekToEnd()
        fileHandle.write(chunkData)
        totalPCMBytesWritten += UInt32(chunkData.count)

        try updateHeader()
    }

    private func updateHeader() throws {
        let dataSize = totalPCMBytesWritten
        let totalFileSize = dataSize + 44 - 8 // RIFF chunk size (excluding first 8 bytes)

        // Update ChunkSize at offset 4
        try fileHandle.seek(toOffset: 4)
        fileHandle.write(totalFileSize.littleEndianData)

        // Update Subchunk2Size at offset 40
        try fileHandle.seek(toOffset: 40)
        fileHandle.write(dataSize.littleEndianData)

        // Return to end for next write
        try fileHandle.seekToEnd()
    }

    func close() throws {
        guard !isClosed else { return }
        isClosed = true
        try updateHeader()
        try fileHandle.close()
    }

    private func makeWAVHeader(pcmDataSize: UInt32) throws -> Data {
        var header = Data()

        let byteRate = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample) / 8
        let blockAlign = UInt16(numChannels * bitsPerSample / 8)
        let totalDataLen = pcmDataSize + 44 - 8

        header.append("RIFF".data(using: .ascii)!)
        header.append(totalDataLen.littleEndianData)
        header.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        header.append("fmt ".data(using: .ascii)!)
        header.append(UInt32(16).littleEndianData)       // Subchunk1Size for PCM
        header.append(UInt16(1).littleEndianData)        // AudioFormat: PCM = 1
        header.append(numChannels.littleEndianData)
        header.append(sampleRate.littleEndianData)
        header.append(byteRate.littleEndianData)
        header.append(blockAlign.littleEndianData)
        header.append(bitsPerSample.littleEndianData)

        // data chunk
        header.append("data".data(using: .ascii)!)
        header.append(pcmDataSize.littleEndianData)

        return header
    }
}

//private extension FixedWidthInteger {
//    var littleEndianData: Data {
//        var value = self.littleEndian
//        return Data(bytes: &value, count: MemoryLayout<Self>.size)
//    }
//}
