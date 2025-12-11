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

import SwiftUI
import swift_gemini_api

struct ModalitiesView: View {
	@State var client: GeminiAPI?
	
	@AppStorage("apiKey") private var apiKey:String?
	
	@State private var isEmbeddings = false
	@State private var isText = false
	@State private var isTranscribing = false
	@State private var isImageRecognition = false
	@State private var isVideoRecognition = false
	@State private var isSpeechGeneration = false
	
	var body: some View {
		HStack{
			Button("Get Embeddings"){
				isEmbeddings = true
				Task {
					let embeddings = try? await client?.embedding.embedTexts(["Hello World!"])
					print("Embeddings: \(embeddings ?? [])\n")
					isEmbeddings = false
				}
			}
			.disabled(isEmbeddings)
			
			Button("Get Text"){
				isText = true
				Task {
					let response = try await client?.text.generateText("What is BCI?")
					print("Response:\n")
					for response in response! {
						print(response)
					}
					isEmbeddings = false
				}
			}
			.disabled(isText)
			
			Button("Transcribe audio"){
				isTranscribing = true
				Task {
					do {
						// this needs App Sandbox set to NO in entitlements
						let embeddings = try await client?.audio.audio(atPath: "/Users/Shared/MLKDream_64kb.mp3", prompt: "Transcribe audio and generate subtitles in SRT format.")
						print("Transcription: \(embeddings ?? "")\n")
					} catch let error {
						print("Caught a transcription error: \(error)")
					}
					isTranscribing = false
				}
			}
			.disabled(isTranscribing)
			
			Button("Describe image"){
				isImageRecognition = true
				Task {
					do {
						// this needs App Sandbox set to NO in entitlements
						let response = try await client?.image.image(atPath: "/Users/Shared/attention.png", prompt: "Describe image in JSON format with coordinates of bounding boxes and semantic labels. Be very specific in describing images that contain multiple objects, not only text.")
						print("Description: \(response ?? "")\n")
					} catch let error {
						print("Caught an image description error: \(error)")
					}
					isImageRecognition = false
				}
			}
			.disabled(isImageRecognition)
			
			Button("Transcribe video"){
				isVideoRecognition = true
				Task {
					do {
						// this needs App Sandbox set to NO in entitlements
						let response = try await client?.video.video(atPath: "/Users/Shared/ai.mp4", prompt: "Describe each scene, and include text transcription of that scene. If scene didn't change but more audio was processed, then inlcude just transcription. Comply to a JSON structure like [{scene:\"description\", transcription: \"transcribed text\", timestamp: 1970..., visual_features: [{bounding_box: [x1, y1, x2, y2], label: \"label\"}, ...]}, ...]")
						print("Description: \(response ?? "")\n")
					} catch let error {
						print("Caught an video description error: \(error)")
					}
					isVideoRecognition = false
				}
			}
			.disabled(isVideoRecognition)
			
			Button("Generate speech"){
				isSpeechGeneration = true
				Task {
					do {
						// this needs App Sandbox set to NO in entitlements
						let pcmData = try await client?.speech.synthesizeSpeech("Say cheerfully: Lets talk about today's call")
						let wavData = GeminiSpeech.pcmToWav(pcmData: pcmData!)

						let outURL = URL(fileURLWithPath: "/Users/Shared/out.wav")
						try wavData.write(to: outURL)

						print("WAV audio saved at: \(outURL.path)")
					} catch let error {
						print("Caught an speech generation error: \(error)")
					}
					isSpeechGeneration = false
				}
			}
			.disabled(isSpeechGeneration)
		}
		.onAppear(){
			client = GeminiAPI(apiKey: apiKey ?? "")
		}
	}
}
