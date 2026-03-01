// swift-tools-version: 6.2

import PackageDescription

let package = Package(name: "dxattr",
					  platforms: [
					  	.macOS(.v10_15),
					  ],
					  products: [
					  	.library(name: "dxattr",
								   targets: ["dxattr"]),
					  ],
					  dependencies: [
					  	.package(url: "https://github.com/arennow/Dirs", from: "0.13.0"),
					  ],
					  targets: [
					  	.target(name: "dxattr",
								  dependencies: ["Dirs"]),
					  	.testTarget(name: "dxattrTests",
									  dependencies: ["dxattr"]),
					  ])
