// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SheetPresentation",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "SheetPresentation",
            targets: ["SheetPresentation"]
        )
    ],
    targets: [
        .target(
            name: "SheetPresentation",
            path: "Sources/SheetPresentation"
        )
    ]
)
