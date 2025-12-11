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

public struct GeminiEmbedding {
    let apiKey: String
    let model: String
    let host: String
    let version: String
    let verbose: Bool

	public init(
        apiKey: String,
        model: String = "gemini-embedding-001",
        host:String = "generativelanguage.googleapis.com",
        version:String = "v1beta",
        verbose: Bool = false
    ) {
        self.apiKey = apiKey
        self.model = model
        self.host = host
        self.version = version
        self.verbose = verbose
    }

    /// Request embeddings for one or multiple texts
    /// - Parameters:
    ///   - texts: Array of strings to embed
    ///   - outputDimensionality: Optional output vector size (e.g. 768)
    /// - Returns: Array of embedding vectors (one per text)
	public func embedTexts(_ texts: [String], outputDimensionality: Int? = 768, retries: Int = 3, initialDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 30.0) async throws -> [[Double]] {
        if verbose {
            print("Calling Gemini Embedding API...")
        }

        let url = URL(string: "https://\(host)/\(version)/models/\(model):embedContent")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        print(url.absoluteString)
        
        let content: [String: Any] = [
           "parts": [["text": texts[0]]]
        ]
       
        var bodyDict: [String: Any] = [
           "content": content
        ]
       
        if let dim = outputDimensionality {
            bodyDict["output_dimensionality"] = dim
        }
       
        if !model.hasPrefix("models/") {
           bodyDict["model"] = "models/\(model)"
        } else {
           bodyDict["model"] = model
        }
        
        req.httpBody = try JSONSerialization.data(withJSONObject: bodyDict, options: .prettyPrinted)

        // Using the retry function with configurable delay and exponential backoff
        return try await retry({
            // The actual task to attempt
            let (data, response) = try await URLSession.shared.data(for: req)

            guard let httpResp = response as? HTTPURLResponse else {
                throw GeminiAPIError.invalidResponse
            }

            guard (200..<300).contains(httpResp.statusCode) else {
                let responseBody = String(data: data, encoding: .utf8) ?? "<no body>"
                print("HTTP \(httpResp.statusCode) Error: \(responseBody)")
                throw GeminiAPIError.requestFailed
            }

            // Parse response embeddings
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let embeddingDict = json["embedding"] as? [String: Any],
                  let values = embeddingDict["values"] as? [Double] else {
                throw GeminiAPIError.invalidResponse
            }

            return [values]
        }, retries: retries, initialDelay: initialDelay, maxDelay: maxDelay)
    }
}
