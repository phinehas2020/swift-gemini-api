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

public struct GeminiAudio {
    let apiKey: String
    let model: String
    let host: String
    let version: String
    let filesAPI: GeminiFilesAPI

	public init(
        apiKey: String,
        model: String = "models/gemini-2.5-flash",
        host: String = "generativelanguage.googleapis.com",
        version: String = "v1beta",
        filesAPI: GeminiFilesAPI
    ) {
        self.apiKey = apiKey
        self.model = model
        self.host = host
        self.version = version
        self.filesAPI = filesAPI
    }

    /// Analyze and describe audio clip at path
	public func audio(
        atPath path: PathConvertible,
        displayName: String = "Audio",
        prompt: String = "Describe this audio clip",
        retries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0
    ) async throws -> String {

        // Step 1: Upload file using GeminiFilesAPI
		let fileURI: String = try await filesAPI.uploadFile(path: path, displayName: displayName)

        // Step 2: Wait for file to become ACTIVE
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
                    ["text": prompt],
                    ["file_data": [
                        "mime_type": mimeType,
                        "file_uri": fileURI
                    ]]
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
