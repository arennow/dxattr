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
					  	.package(url: "https://github.com/arennow/Dirs", branch: "main"),
					  	.package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
					  ],
					  targets: [
					  	.target(name: "CSQLite",
								  path: "Sources/CSQLite",
								  publicHeadersPath: ".",
								  cSettings: [
								  	.define("SQLITE_THREADSAFE", to: "1"),
								  	.define("SQLITE_OMIT_LOAD_EXTENSION"),
								  	.define("SQLITE_ENABLE_DESERIALIZE"),
								  	.unsafeFlags([
								  		"-Wno-ambiguous-macro",
								  	]),
								  ]),
					  	.target(name: "libdxattr",
								  dependencies: ["Dirs", "CSQLite"]),
					  	.executableTarget(name: "dxattr",
											dependencies: [
												"libdxattr",
												"Dirs",
												.product(name: "ArgumentParser",
														 package: "swift-argument-parser"),
											]),
					  	.testTarget(name: "libdxattrTests",
									  dependencies: ["libdxattr"]),
					  	.testTarget(name: "dxattrTests",
									  dependencies: ["dxattr"]),
					  ])
