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

public struct GeminiVideo {
    let apiKey: String
    let model: String
    let filesAPI: GeminiFilesAPI

	public init(
        apiKey: String,
        model: String = "models/gemini-2.5-flash",
        filesAPI: GeminiFilesAPI
    ) {
        self.apiKey = apiKey
        self.model = model
        self.filesAPI = filesAPI
    }

    /// Poll interval in seconds
    private let pollInterval: TimeInterval = 2
    /// Timeout in seconds
    private let timeout: TimeInterval = 60

    /// Analyze and quiz based on video
	public func video(
        atPath path: PathConvertible,
        displayName: String = "Video",
        prompt: String = "Summarize this video. Then create a quiz with an answer key based on the information in this video.",
        retries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0
    ) async throws -> String {

        // Step 1: Upload file using GeminiFilesAPI
		let fileURI: String = try await filesAPI.uploadFile(path: path, displayName: displayName)

        // Step 2: Wait for file to become available, state set to ACTIVE
        try await filesAPI.waitForFileActiveState(fileURI: fileURI)

        // Step 3: Generate content with file_uri
        let genURL = URL(string: "https://\(filesAPI.host)/\(filesAPI.version)/\(model):generateContent")!
        var genReq = URLRequest(url: genURL)
        genReq.httpMethod = "POST"
        genReq.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        genReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let mimeType = GeminiFilesAPI.mimeType(forPath: path)

        let requestBody: [String: Any] = [
            "contents": [[
                "parts": [
                    ["file_data": [
                        "mime_type": mimeType,
                        "file_uri": fileURI
                    ]],
                    ["text": prompt]
                ]
            ]]
        ]

        genReq.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        return try await retry({
            let (data, _) = try await URLSession.shared.data(for: genReq)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
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
