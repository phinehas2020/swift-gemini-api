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

struct ContentView: View {
	@ObservedObject var recorder = AudioRecorder()
	@State var writer: StreamingWAVWriter?
	
	// Retrieve the saved api key from UserDefaults
	@AppStorage("apiKey") private var apiKey:String?
	
	var body: some View {
		KeyView()
		
		VStack() {
			LiveView()
			
			Rectangle()
				.fill(Color.gray)
				.frame(height: 1)
			
			ModalitiesView()
		}
		.padding()
	}
}

#Preview {
    ContentView()
}
