// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TTSVoice",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TTSVoice", targets: ["TTSVoice"]),
    ],
    targets: [
        .executableTarget(
            name: "TTSVoice",
            path: "Sources/TTSVoice",
            exclude: ["Info.plist"],
            resources: [
                .copy("Resources/app-icon.png"),
                .copy("Resources/tray-icon-light.png"),
                .copy("Resources/tray-icon-dark.png"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/TTSVoice/Info.plist",
                ]),
            ]
        ),
    ]
)
