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

/// Retry logic with configurable retries, delay, and exponential backoff
func retry<T>(_ block: @escaping () async throws -> T, retries: Int = 3, initialDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 30.0) async throws -> T {
    var attempt = 0
    var currentDelay = initialDelay
    
    while attempt < retries {
        do {
            // Attempt the block (e.g., making the request)
            return try await block()
        } catch {
            attempt += 1
            if attempt == retries {
                throw error // Rethrow error after max retries
            }
            
            // Print retry information
            print("Attempt \(attempt) failed. Retrying in \(currentDelay) seconds...")

            // Delay before retrying with exponential backoff (max delay is optional)
            try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000)) // Convert to nanoseconds
            currentDelay = min(currentDelay * 2, maxDelay) // Exponential backoff, capped by maxDelay
        }
    }
    
    throw NSError(domain: "RetryFailed", code: 0, userInfo: nil)
}
