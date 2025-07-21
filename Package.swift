// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Klinmai",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Klinmai",
            targets: ["Klinmai"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Klinmai",
            path: ".",
            exclude: ["Info.plist", "Klinmai.entitlements"],
            sources: [
                "KlinmaiApp.swift",
                "SmartCareEngine.swift",
                "FileOrganizer.swift",
                "DuplicateScanner.swift",
                "SystemCleaner.swift",
                "MailAndTrashCleaner.swift",
                "LLMHandler.swift",
                "ConsoleView.swift",
                "SmartArchiveManager.swift",
                "ProjectDetector.swift",
                "CopyMascot.swift",
                "SmartCleanManager.swift",
                "Views/SmartCareView.swift",
                "Views/ArchiveView.swift",
                "Views/CompactArchiveView.swift",
                "Views/SimplifiedArchiveRow.swift",
                "Views/SimplifiedArchiveGridItem.swift",
                "Views/ProjectsView.swift",
                "Views/MascotImage.swift",
                "Views/MascotImageLoader.swift",
                "Views/FilePreviewView.swift",
                "Views/ActionBarView.swift",
                "Views/SmartSuggestionsView.swift",
                "Views/iCloudArchiveModal.swift"
            ]
        )
    ]
)