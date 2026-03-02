import ArgumentParser
import Dirs
import Foundation
import libdxattr
import SystemPackage

func makeFocusNode(path: String) throws -> FocusNode {
	var fp: FilePath = path.into()
	if fp.isRelative {
		fp.components.insert("./", at: fp.components.startIndex)
	}

	let node = try RealFSInterface().node(at: fp)
	return FocusNode(node: node)
}

@main
struct DXAttrCommand: ParsableCommand {
	static let configuration = CommandConfiguration(commandName: "dxattr",
													abstract: "Read and write dxattrs on files and directories.",
													subcommands: [List.self, Print.self, Write.self, Delete.self, Clear.self],
													defaultSubcommand: List.self)
}

// MARK: - Subcommands

extension DXAttrCommand {
	struct List: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "List dxattr names on a file (default).")

		@Flag(name: .customShort("v"), help: "Also show each attribute's value.")
		var verbose = false

		@Argument(help: "The file or directory to inspect.")
		var file: String

		func run() throws {
			let fn = try makeFocusNode(path: file)
			let attrs = try fn.dxattrs().sorted { $0.name < $1.name }
			for attr in attrs {
				if self.verbose {
					print("\(attr.name): \(String(decoding: attr.value, as: UTF8.self))")
				} else {
					print(attr.name)
				}
			}
		}
	}

	struct Print: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Print the value of a named dxattr.")

		@Flag(name: .customShort("v"), help: "Print in 'name: value' format.")
		var verbose = false

		@Argument(help: "The dxattr name to read.")
		var name: String

		@Argument(help: "The file or directory to inspect.")
		var file: String

		func run() throws {
			let fn = try makeFocusNode(path: file)
			let attrs = try fn.dxattrs()
			guard let attr = attrs.first(where: { $0.name == name }) else {
				throw ValidationError("No such dxattr: \(self.name)")
			}
			let value = String(decoding: attr.value, as: UTF8.self)
			if self.verbose {
				print("\(self.name): \(value)")
			} else {
				print(value)
			}
		}
	}

	struct Write: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Write (upsert) a dxattr on a file.")

		@Argument(help: "The dxattr name to write.")
		var name: String

		@Argument(help: "The value to store.")
		var value: String

		@Argument(help: "The file or directory to modify.")
		var file: String

		func run() throws {
			let fn = try makeFocusNode(path: file)
			try fn.setDXAttr(name: self.name, value: self.value)
		}
	}

	struct Delete: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Delete a named dxattr from a file.")

		@Argument(help: "The dxattr name to delete.")
		var name: String

		@Argument(help: "The file or directory to modify.")
		var file: String

		func run() throws {
			let fn = try makeFocusNode(path: file)
			try fn.removeDXAttr(name: self.name)
		}
	}

	struct Clear: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Remove all dxattrs from a file.")

		@Argument(help: "The file or directory to clear.")
		var file: String

		func run() throws {
			let fn = try makeFocusNode(path: file)
			try fn.clearDXAttrs()
		}
	}
}
