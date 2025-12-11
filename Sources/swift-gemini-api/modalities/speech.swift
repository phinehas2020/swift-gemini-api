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

public struct GeminiSpeech {
    let apiKey: String
    let model: String
    let host: String
    let version: String

    public init(
        apiKey: String,
        model: String = "gemini-2.5-flash-preview-tts", //"gemini-2.5-flash",
        host:String = "generativelanguage.googleapis.com",
        version:String = "v1beta"
    ) {
        self.apiKey = apiKey
        self.model = model
        self.host = host
        self.version = version
    }

    /// Generate speech audio (PCM) from input text
    public func synthesizeSpeech(
        _ text: String,
        voiceName: Voice = Voice.KORE,
        retries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0
    ) async throws -> Data {
        var req = URLRequest(url: URL(string: "https://\(host)/\(version)/models/\(model):generateContent")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": text]
                ]
            ]],
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "speechConfig": [
                    "voiceConfig": [
                        "prebuiltVoiceConfig": [
                            "voiceName": voiceName.rawValue
                        ]
                    ]
                ]
            ],
            "model": model
        ]

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await retry({
            let (data, _) = try await URLSession.shared.data(for: req)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let inlineData = parts.first?["inlineData"] as? [String: Any],
                  let base64Audio = inlineData["data"] as? String,
                  let pcmData = Data(base64Encoded: base64Audio) else {
                throw GeminiAPIError.generationFailed
            }

            return pcmData
        }, retries: retries, initialDelay: initialDelay, maxDelay: maxDelay)
    }

    /// Convert raw PCM (16-bit signed LE, mono, 24000 Hz) to WAV data
    public static func pcmToWav(pcmData: Data, sampleRate: UInt32 = 24000, channels: UInt16 = 1, bitsPerSample: UInt16 = 16) -> Data {
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(pcmData.count)
        let chunkSize = 36 + dataSize

        var header = Data()

        // RIFF chunk descriptor
        header.append("RIFF".data(using: .ascii)!)                        // ChunkID
        header.append(UInt32(chunkSize).littleEndianData)                 // ChunkSize
        header.append("WAVE".data(using: .ascii)!)                        // Format

        // fmt sub-chunk
        header.append("fmt ".data(using: .ascii)!)                        // Subchunk1ID
        header.append(UInt32(16).littleEndianData)                        // Subchunk1Size (16 for PCM)
        header.append(UInt16(1).littleEndianData)                         // AudioFormat (1 = PCM)
        header.append(channels.littleEndianData)                          // NumChannels
        header.append(sampleRate.littleEndianData)                        // SampleRate
        header.append(byteRate.littleEndianData)                          // ByteRate
        header.append(blockAlign.littleEndianData)                        // BlockAlign
        header.append(bitsPerSample.littleEndianData)                     // BitsPerSample

        // data sub-chunk
        header.append("data".data(using: .ascii)!)                        // Subchunk2ID
        header.append(dataSize.littleEndianData)                          // Subchunk2Size

        var wavData = Data()
        wavData.append(header)
        wavData.append(pcmData)

        return wavData
    }
}
