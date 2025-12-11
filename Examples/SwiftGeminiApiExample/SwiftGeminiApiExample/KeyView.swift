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

struct KeyView: View {
    @State private var showingAPIKeyPrompt = false

    // Retrieve the saved api key from UserDefaults
    @AppStorage("apiKey") private var apiKey:String?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack {
                Spacer()
                Button(action: {
                    showingAPIKeyPrompt = true
                }) {
                    Image(systemName: "key.fill") // Key icon
                        .font(.title)
                        .foregroundColor(((apiKey?.isEmpty) != nil) ? .blue : .red)
//                        .padding()
                        .background(Circle().fill(Color.white).shadow(radius: 5).frame(width: 40, height: 40))
                }
                .padding()
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .sheet(isPresented: $showingAPIKeyPrompt) {
            // API key prompt sheet
            KeyViewSheet(apiKey: $apiKey)
        }
    }
}

struct KeyViewSheet: View {
    @Binding var apiKey: String?
    @State private var secret = ""
    @State private var isPasswordValid = true
    
    var body: some View {
        VStack {
            Text("Enter Gemini Key")
                .font(.title)
                .padding()
            
            SecureField("API Key", text: $secret)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !isPasswordValid {
                Text("API key cannot be empty")
                    .foregroundColor(.red)
                    .padding(.top, 5)
            }
            
            Button("Save") {
                if secret.isEmpty {
                    isPasswordValid = false
                } else {
                    apiKey = secret // This automatically saves it to UserDefaults
                    isPasswordValid = true
                    // Close the sheet
                    dismiss()
                }
            }
//            .padding()
            .disabled(secret.isEmpty)
            .background(secret.isEmpty ? Color.gray : Color.blue)
            .cornerRadius(8)
        }
        .padding()
    }
    
    // Dismiss the sheet when saving
    @Environment(\.dismiss) private var dismiss
}

#Preview {
    KeyView()
}
