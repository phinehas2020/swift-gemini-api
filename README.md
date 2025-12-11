# swift-gemini-api

![](/Documentation/Assets/logo%20small.png)

A flexible Swift package for interacting with Google's Gemini API. This library supports both the standard **REST API** (Multimodal generation, Text-to-Speech, Vision) and the **Gemini Live API** (Real-time bidirectional WebSocket streaming).

Created by [Nataliya Kosmyna](https://github.com/nataliyakosmyna).

This is not an officially supported Google product. This project is not
eligible for the [Google Open Source Software Vulnerability Rewards
Program](https://bughunters.google.com/open-source-security).

## Features

*   **Gemini Live Client**: Full WebSocket implementation for real-time, bidirectional audio and text interaction with Gemini.
    *   Real-time audio streaming (Input & Output).
    *   Voice Activity Detection (VAD) configuration.
    *   Tool/Function calling support.
    *   Google Search integration.
    *   Customizable voices and system prompts.
*   **Gemini REST API**: A structured facade for standard request/response interactions.
    *   **Text**: Chat and text generation.
    *   **Speech**: Text-to-Speech (TTS) synthesis.
    *   **Vision/Audio/Video**: Multimodal analysis.
    *   **Files**: Media upload management.
*   **Swift Concurrency**: Built using `async`/`await` and Actors for thread safety.
*   **Observation**: Uses the `@Observable` macro for seamless SwiftUI integration.

## Requirements

*   **iOS**: 14.0+
*   **macOS**: 15.0+
*   **Swift**: 6.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/paradigms-of-intelligence/swift-gemini-api.git", from: "1.0.0")
]
```

## Demo app

### Locate the Example Xcode project in the root folder

![root project folder](/Documentation/Assets/root.png)

### Launch it in Xcode and make sure correct project is selected before you click the run button

![Xcode](/Documentation/Assets/xcode.png)

### Setup the Gemini API Key

![Click on the red key icon](/Documentation/Assets/01.png)

### Enter Gemini API Key

![Enter Gemini API Key](/Documentation/Assets/02.png)

### Click Save

![Click Save](/Documentation/Assets/03.png)

### Click Start Gemini Live Session

If key is setup correctly you will see `Blue Key` instead of a `Red Key`

![Start Gemini Live Session](/Documentation/Assets/04.png)

### Successfully connected

If they Gemini API key was set correctly and valid, you will see the interface connect successfully.

To start streaming the voice (microphone audio input), you will need to click on `Start Recording` which will prompt you to confirm privacy access to your microphone, once it's confirmed, you can speak to the Gemini from Swift 🎉

![Gemini Live Interface](/Documentation/Assets/05.png)

### Layout

Top red pane is Live API, bottom blue pane is REST API.

![live and rest APIs layout](/Documentation/Assets/06.png)

## Usage

### 1. Gemini Live (Real-time WebSocket)

The GeminiLiveClient handles persistent connections for continuous conversation.

**Note**: Audio playback is 24KHz, and audio input should be in 16KHz.

#### Initialization

```swift
import swift_gemini_api

// Initialize the client
let liveClient = GeminiLiveClient(
    model: "gemini-live-2.5-flash-preview", // <-- set current Gemini model
    systemPrompt: "You are a helpful AI assistant.",
    voice: .KORE,
    enableGoogleSearch: true,
    input_audio_transcription: true,
    output_audio_transcription: true
)

```

#### Handling Events

Set up closures to handle incoming data, transcriptions, and tool calls before connecting.

```swift
// Handle text coming back from the model (what the AI is saying)
liveClient.setOutputTranscription { text in
    print("AI: \(text)")
}

// Handle transcription of what the user said
liveClient.setInputTranscription { text in
    print("User: \(text)")
}

// Handle connection setup
liveClient.onSetupComplete = { success in
    if success {
        print("Connected and ready to talk!")
    }
}
```

#### Connecting

```swift
liveClient.connect(apiKey: "YOUR_API_KEY")
```

#### Sending Input

You can send text or raw audio data (PCM).

```swift
// Send text
liveClient.sendTextPrompt("Hello, how are you?")

// Send Audio (e.g., from a microphone buffer)
// Expects Base64 string or Data
liveClient.sendAudio(data: pcmData)
```

#### Function Calling (Tools)

You can define tools that the AI can request to execute.

```swift
// 1. Define the tool definition
let lightTool = [
    "name": "turn_on_lights",
    "description": "Turns on the lights in the room.",
    "parameters": [
        "type": "object",
        "properties": [:], // Add properties if needed
    ]
]

liveClient.addFunctionDeclarations(lightTool)

// 2. Handle the callback
liveClient.setToolCall { name, id, args in
    if name == "turn_on_lights" {
        // Execute your native code here
        print("Lights turned on!")
        
        // 3. Send the result back to Gemini
        let response = ["status": "success"]
        liveClient.sendFunctionResponse(id, response: response)
    }
}
```

### 2. Gemini API (REST)

Use GeminiAPI for single-turn requests or media processing.

```swift
import swift_gemini_api

let api = GeminiAPI(apiKey: "YOUR_API_KEY")
```

#### Text Generation

```swift
let response = try await api.text.generateText("Explain Quantum Computing")
````

#### Text-to-Speech

```swift
let audioData = try await api.speech.synthesizeSpeech("Hello world")
// Returns PCM Data ready for playback
```

## License

[Apache](/LICENSE)