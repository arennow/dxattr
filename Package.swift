// swift-tools-version: 6.2

import PackageDescription

let package = Package(name: "dxattr",
					  platforms: [
					  	.macOS(.v10_15),
					  ],
					  products: [
					  	.library(name: "libdxattr",
								   targets: ["libdxattr"]),
					  	.executable(name: "dxattr",
									  targets: ["dxattr"]),
					  ],
					  dependencies: [
					  	.package(url: "https://github.com/arennow/Dirs", from: "0.13.0"),
					  	.package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
					  ],
					  targets: [
					  	.target(name: "libdxattr",
								  dependencies: ["Dirs"]),
					  	.executableTarget(name: "dxattr",
											dependencies: [
												"libdxattr",
												"Dirs",
												.product(name: "ArgumentParser",
														 package: "swift-argument-parser"),
											]),
					  	.testTarget(name: "dxattrTests",
									  dependencies: ["libdxattr"]),
					  ])
