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

public class GeminiFilesAPI {
    let apiKey: String
    let host: String
    let version: String
    
	public init(
        apiKey: String,
        host:String = "generativelanguage.googleapis.com",
        version:String = "v1beta"
    ) {
        self.apiKey = apiKey
        self.host = host
        self.version = version
    }

    // MARK: - Upload File

	func uploadFile(path: PathConvertible, displayName: String) async throws -> String {
		let fileURL = path.asURL()!

		// Load file data
		let fileData = try Data(contentsOf: fileURL)
		let mimeType = mimeTypeForPath(fileURL)
		let numBytes = fileData.count

		// Build start-upload request
		let startURL = URL(string: "https://\(host)/upload/\(version)/files")!
		var startRequest = URLRequest(url: startURL)
		startRequest.httpMethod = "POST"
		startRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
		startRequest.setValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol")
		startRequest.setValue("start", forHTTPHeaderField: "X-Goog-Upload-Command")
		startRequest.setValue("\(numBytes)", forHTTPHeaderField: "X-Goog-Upload-Header-Content-Length")
		startRequest.setValue(mimeType, forHTTPHeaderField: "X-Goog-Upload-Header-Content-Type")
		startRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

		startRequest.httpBody = """
		{
			"file": {
				"display_name": "\(displayName)"
			}
		}
		""".data(using: .utf8)

		// Perform start request
		let (_, response) = try await URLSession.shared.data(for: startRequest)

		guard
			let httpResponse = response as? HTTPURLResponse,
			let uploadURLString = httpResponse.value(forHTTPHeaderField: "x-goog-upload-url"),
			let uploadURL = URL(string: uploadURLString)
		else {
			throw NSError(domain: "Upload start failed", code: 0)
		}

		// Build upload request
		var uploadRequest = URLRequest(url: uploadURL)
		uploadRequest.httpMethod = "POST"
		uploadRequest.setValue("\(numBytes)", forHTTPHeaderField: "Content-Length")
		uploadRequest.setValue("0", forHTTPHeaderField: "X-Goog-Upload-Offset")
		uploadRequest.setValue("upload, finalize", forHTTPHeaderField: "X-Goog-Upload-Command")
		uploadRequest.httpBody = fileData

		// Perform upload request
		let (data, _) = try await URLSession.shared.data(for: uploadRequest)

		// Parse JSON result
		guard
			let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
			let file = json["file"] as? [String: Any],
			let uri = file["uri"] as? String
		else {
			throw NSError(domain: "Upload response parse error", code: 0)
		}

		return uri
	}


    // MARK: - Get File Metadata

	func getFileMetadata(fileName: String) async throws -> [String: Any] {
		var request = URLRequest(url: URL(string: "https://\(host)/\(version)/files/\(fileName)")!)
		request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

		let (data, _) = try await URLSession.shared.data(for: request)

		guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
			throw NSError(domain: "Invalid JSON", code: 0)
		}

		return json
	}


    // MARK: - List Files

	func listFiles() async throws -> [[String: Any]] {
		var request = URLRequest(url: URL(string: "\(host)/\(version)/files?key=\(apiKey)")!)
		request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

		let (data, _) = try await URLSession.shared.data(for: request)

		guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
			  let files = json["files"] as? [[String: Any]] else {
			throw NSError(domain: "Invalid list JSON", code: 0)
		}

		return files
	}

    // MARK: - Delete File

	func deleteFile(fileName: String) async throws -> Bool {
		var request = URLRequest(url: URL(string: "https://\(host)/\(version)/files/\(fileName)?key=\(apiKey)")!)
		request.httpMethod = "DELETE"
		request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

		let (_, response) = try await URLSession.shared.data(for: request)

		guard let httpResponse = response as? HTTPURLResponse else {
			throw URLError(.badServerResponse)
		}

		return httpResponse.statusCode == 200
	}
    
    // MARK: - Wait for Active state
	
    /// Polls the file metadata until the file is in ACTIVE state or timeout is reached.
    /// - Parameters:
    ///   - fileURI: The URI of the uploaded file.
    ///   - timeout: Maximum time to wait in seconds.
    ///   - pollInterval: Interval between polling attempts in seconds.
    /// - Throws: `GeminiAPIError.uploadFailed` if the file name cannot be parsed,
    ///           or `GeminiAPIError.fileNotReady` if timeout expires before file becomes ACTIVE.
	func waitForFileActiveState(
		fileURI: String,
		timeout: TimeInterval = 60,
		pollInterval: TimeInterval = 2
	) async throws {
		guard let fileName = fileURI.components(separatedBy: "/").last else {
			throw GeminiAPIError.uploadFailed
		}

		let deadline = Date().addingTimeInterval(timeout)

		while Date() < deadline {
			let metadata = try await getFileMetadata(fileName: fileName)

			if let status = metadata["state"] as? String, status.uppercased() == "ACTIVE" {
				return
			}

			try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
		}

		// Final check
		let finalMetadata = try await getFileMetadata(fileName: fileName)
		if let finalStatus = finalMetadata["state"] as? String, finalStatus.uppercased() == "ACTIVE" {
			return
		} else {
			throw GeminiAPIError.fileNotReady
		}
	}
	

    // MARK: - Helpers

    private func mimeTypeForPath(_ url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
            case "mp3": return "audio/mpeg"
            case "wav": return "audio/wav"
            case "jpg", "jpeg": return "image/jpeg"
            case "png": return "image/png"
            case "mp4": return "video/mp4"
            case "pdf": return "application/pdf"
            default: return "application/octet-stream"
        }
    }
    
    /// Helper to get MIME type
    static public func mimeType(forPath path: PathConvertible) -> String {
        let url = path.asURL()!
        if let type = UTType(filenameExtension: url.pathExtension),
           let mimeType = type.preferredMIMEType {
            return mimeType
        }
        return "application/octet-stream"
    }
}

// -------------------------------------------

public protocol PathConvertible {
    func asURL() -> URL?
}

extension String: PathConvertible {
	public func asURL() -> URL? {
        return URL(fileURLWithPath: self)
    }
}

extension URL: PathConvertible {
	public func asURL() -> URL? {
        return self
    }
}

extension URLRequest: PathConvertible {
	public func asURL() -> URL? {
        return self.url
    }
}
