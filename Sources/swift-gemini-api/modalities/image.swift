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
import UniformTypeIdentifiers

public struct GeminiImage {
    let apiKey: String
    let model: String
    let host: String
    let version: String

	public init(
        apiKey: String,
        model: String = "gemini-2.5-flash",
        host:String = "generativelanguage.googleapis.com",
        version:String = "v1beta"
    ) {
        self.apiKey = apiKey
        self.model = model
        self.host = host
        self.version = version
    }

    /// Detect MIME type from file extension
    private func mimeType(forPath path: PathConvertible) -> String {
        let url = path.asURL()!
        if let type = UTType(filenameExtension: url.pathExtension),
           let mimeType = type.preferredMIMEType {
            return mimeType
        }
        return "application/octet-stream"
    }

    /// Describe an image by uploading inline base64 data
    public func image(
        atPath path: PathConvertible,
        prompt: String = "Caption this image.",
        retries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0
    ) async throws -> String {
        // Load and base64-encode image data
        guard let imageData = try? Data(contentsOf: path.asURL()!) else {
            throw GeminiAPIError.fileNotFound
        }

        let mimeType = mimeType(forPath: path)
        let base64Encoded = imageData.base64EncodedString()

        guard !base64Encoded.isEmpty else {
            throw GeminiAPIError.encodingFailed
        }

        // Prepare Gemini API request
        let url = URL(string: "https://\(host)/\(version)/models/\(model):generateContent?key=\(apiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    [
                        "inline_data": [
                            "mime_type": mimeType,
                            "data": base64Encoded
                        ]
                    ],
                    [
                        "text": prompt
                    ]
                ]
            ]]
        ]

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await retry({
            // Send request
            let (responseData, _) = try await URLSession.shared.data(for: req)

            // Parse result
            guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else {
                throw GeminiAPIError.generationFailed
            }

            return text
            
        }, retries: retries, initialDelay: initialDelay, maxDelay: maxDelay)
    }
}
