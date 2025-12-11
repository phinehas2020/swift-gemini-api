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
import Foundation
import swift_gemini_api

struct LiveView: View {
	// Retrieve the saved api key from UserDefaults
	@AppStorage("apiKey") private var apiKey:String?
	
	@State var setupComplete = false
	@ObservedObject var recorder = AudioRecorder()
	@State private var client: GeminiLiveClient?
	@State var writer: StreamingWAVWriter?
	@State var playback = true
	@State var mute = false
	@State var prompt:String = "Can you explain to me what is Brain Computer Interfaces?"
	
	
	func onSetupComplete(flag:Bool) {
		print("onSetupComplete called with \(flag)")
		DispatchQueue.main.async {
			setupComplete = flag
		}
	}
	
	func turn_on_the_lights(args: [String: Any]) -> [String: Any]{
		return [
			"Lights": "On"
		]
	}
	
	func sayToGeminiLive(_ text:String) async throws {
		print("sayToGeminiLive")
		let speech = GeminiSpeech(apiKey: apiKey!)
		let pcmData = try await speech.synthesizeSpeech(text)
		print("Generated PCM \(pcmData.count) bytes for \(text)")
		client?.sendAudio(data:pcmData)
		print("Sent audio to GeminiLive")
	}
	
	var body: some View {
		VStack() {
			if setupComplete {
			Text("Prompt")
				.font(.headline)

			TextEditor(text: $prompt)
				.frame(height: 150)
				.padding(5)
				
			HStack() {
					Button("Send Prompt") {
						Task {
							client?.sendTextPrompt(prompt)
						}
					}
				
					Button("Send Prompt as Audio") {
						Task {
							try await sayToGeminiLive(prompt)
						}
					}
					
					Button("Ask to search") {
						Task {
							client?.sendTextPrompt("Can you search for: \(prompt)")
						}
					}
					
					Button("Use a tool (schedule a meeting)") {
						Task {
//                            client?.sendTextPrompt("Schedule a meeting with Nataliya on October 1st, 2025 at noon EST about BCI")
							client?.sendTextPrompt(prompt)
						}
					}
					
					Button("Disconnect") {
						client?.disconnect()
						recorder.stopRecording()
					}
					
					
					Button(action: {
						if recorder.isRecording {
							recorder.stopRecording()
						} else {
							recorder.startRecording()
						}
					}) {
						Text(recorder.isRecording ? "Stop Recording" : "Start Recording")
					}
			}
			} else {
				Button("Start Gemini Live Session") {
					Task {
						client?.setOutputTranscription { transcription in
							print("setOutputTranscription \(transcription)")
						}
						
						let turn_on_the_lights_id = "turn_on_the_lights"
						
						client?.addFunctionDeclarations(["name": turn_on_the_lights_id])
						
						client?.setToolCall { name, id, args in
							switch name {
							case turn_on_the_lights_id:
								print("Turning on the lights!")
								let response = turn_on_the_lights(args: args)
								client?.sendFunctionResponse(id, response: response)
							default:
								break
							}
							print("Tool call: \(name), \(id), \(args)")
						}
						
						client?.connect(apiKey: apiKey!)
					}
				}
			}
		}
		.padding()
		.onAppear() {
			client = GeminiLiveClient(
				onSetupComplete: self.onSetupComplete,
				verbose: false,
				input_audio_transcription: false,
				output_audio_transcription: false,
			)
			
			// for debugging
//            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//            let outputURL = dir.appendingPathComponent("streamed_output_\(timestamp()).wav")
//            writer = try? StreamingWAVWriter(outputURL: outputURL)
			
			recorder.setOnChunk {chunk in
				// for debugging
//                try? writer?.appendBase64Chunk(chunk)
				client?.sendAudio(base64:chunk)
			}
		}
	}
}

#Preview {
    LiveView()
}
