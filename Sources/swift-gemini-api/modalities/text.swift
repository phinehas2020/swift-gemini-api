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

public struct GeminiText {
    let apiKey: String
    let model: String
    let host: String
    let version: String
    let verbose: Bool

	public init(
        apiKey: String,
        model: String = "gemini-2.5-flash",
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
    
    private func parseJson(jsonData: Data) -> [String]? {
        do {
            // Parse the JSON data into a dictionary
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
               let candidates = jsonObject["candidates"] as? [[String: Any]] {
                
                // Initialize an empty array to store all texts
                var texts: [String] = []
                
                // Iterate over the candidates array
                for candidate in candidates {
                    if let content = candidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]] {
                        
                        // Iterate over the parts and extract the text field
                        for part in parts {
                            if let text = part["text"] as? String {
                                texts.append(text)
                            }
                        }
                    }
                }
                
                return texts
            }
        } catch {
            print("Error parsing JSON: \(error)")
        }
        
        return nil
    }

    /// Request embeddings for one or multiple texts
    /// - Parameters:
    ///   - texts: Array of strings to embed
    ///   - outputDimensionality: Optional output vector size (e.g. 768)
    /// - Returns: Array of embedding vectors (one per text)
	public func generateText(_ texts: String, retries: Int = 3, initialDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 30.0) async throws -> [String] {
        
        if verbose {
            print("Calling Gemini Text API...")
        }

        let url = URL(string: "https://\(host)/\(version)/models/\(model):generateContent")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        print(url.absoluteString)
        
        let contents: [String: Any] = [
           "parts": [["text": texts]]
        ]
       
        var bodyDict: [String: Any] = [
           "contents": contents
        ]
       
       
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
            
            if verbose {
                // print data as pretty JSON
                print(String(data: data, encoding: .utf8) ?? "<no body>")
            }

            // Parse response embeddings
            return self.parseJson(jsonData:data) ?? []
        }, retries: retries, initialDelay: initialDelay, maxDelay: maxDelay)
    }
}
