// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-gemini-api",
	platforms: [
		.iOS(.v14),
		.macOS(.v12)
	],
    products: [
        .library(
            name: "swift-gemini-api",
            targets: ["swift-gemini-api"]
        ),
    ],
    targets: [
        .target(
            name: "swift-gemini-api",
			linkerSettings: [
				.linkedFramework("AudioToolbox"),
				.linkedFramework("AVFoundation"),
				.linkedFramework("AVFAudio"),
			]
        ),

    ]
)
