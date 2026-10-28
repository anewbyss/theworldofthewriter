// swift-tools-version: 5.8

// Swift Playgrounds app package for WOW Brainstorm.
// Open this .swiftpm folder in Swift Playgrounds on iPad (or Xcode on a Mac).

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "WOW Brainstorm",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "WOW Brainstorm",
            targets: ["AppModule"],
            bundleIdentifier: "com.wowbrainstorm.app",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .pencil),
            accentColor: .presetColor(.purple),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
