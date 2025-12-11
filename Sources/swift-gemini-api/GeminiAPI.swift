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

public class GeminiAPI {
    let apiKey: String
    let host: String
    let version: String

    // Subcomponents
    public let files: GeminiFilesAPI
	public let speech: GeminiSpeech
	public let video: GeminiVideo
	public let audio: GeminiAudio
	public let embedding: GeminiEmbedding
	public let text: GeminiText
	public let image: GeminiImage

    public init(
        apiKey: String,
        host: String = "generativelanguage.googleapis.com",
        version: String = "v1beta"
    ) {
        self.apiKey = apiKey
        self.host = host
        self.version = version

        // Files must be initialized first as it's required by other APIs
        self.files = GeminiFilesAPI(apiKey: apiKey, host: host, version: version)

        // Initialize feature APIs
        self.speech = GeminiSpeech(apiKey: apiKey, model: "gemini-2.5-flash-preview-tts", host: host, version: version)
        self.video = GeminiVideo(apiKey: apiKey, model: "models/gemini-2.5-flash", filesAPI: self.files)
        self.audio = GeminiAudio(apiKey: apiKey, model: "models/gemini-2.5-flash", host: host, version: version, filesAPI: self.files)
        self.embedding = GeminiEmbedding(apiKey: apiKey, model: "gemini-embedding-001", host: host, version: version)
        self.text = GeminiText(apiKey: apiKey, model: "gemini-2.5-flash", host: host, version: version)
        self.image = GeminiImage(apiKey: apiKey, model: "gemini-2.5-flash", host: host, version: version)
    }
}
