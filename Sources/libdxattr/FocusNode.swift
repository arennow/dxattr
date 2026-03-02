import Dirs
import Foundation

public struct FocusNode {
	public let node: any Node

	public init(node: any Node) {
		self.node = node
	}
}

extension FocusNode {
	var existingSidecarFile: File? {
		get throws {
			try self.node.parent.file(at: self.sidecarFileName)
		}
	}
}

private extension FocusNode {
	var sidecarFileName: String {
		"._\(self.node.name).dxattrs"
	}

	var sidecarFile: File {
		get throws {
			try self.node.parent.newOrExistingFile(at: self.sidecarFileName)
		}
	}

	func dxAttrsAndFile() throws -> (Set<DXAttr>, File?) {
		guard let sidecarFile = try self.existingSidecarFile else {
			return ([], nil)
		}

		let contents = try sidecarFile.contents()
		do {
			let dxattrs = try JSONDecoder().decode(Set<DXAttr>.self, from: contents)
			return (dxattrs, sidecarFile)
		} catch DecodingError.dataCorrupted(let context) {
			if context.codingPath.isEmpty {
				// If there's a data corruption at the root, the file is probably empty
				// or otherwise not meaningful, so treat it as empty
				return ([], sidecarFile)
			} else {
				throw DecodingError.dataCorrupted(context)
			}
		}
	}

	func withDXAttrs(_ body: (inout Set<DXAttr>) throws -> Void) throws {
		var (dxattrs, sidecarFile) = try self.dxAttrsAndFile()
		try body(&dxattrs)

		if dxattrs.isEmpty {
			// If there are no dxattrs, remove the sidecar file if it exists
			try sidecarFile?.delete()
			return
		} else {
			let encodedData = try JSONEncoder().encode(dxattrs)
			try (sidecarFile ?? self.sidecarFile).replaceContents(encodedData)
		}
	}
}

public extension FocusNode {
	func dxattrs() throws -> Set<DXAttr> {
		try self.dxAttrsAndFile().0
	}

	func setDXAttr(name: String, value: some IntoData) throws {
		try self.withDXAttrs { dxSet in
			if let existingIndex = dxSet.firstIndex(where: { $0.name == name }) {
				dxSet.remove(at: existingIndex)
			}

			let newDXAttr = DXAttr(name: name, value: value.into())
			dxSet.insert(newDXAttr)
		}
	}

	func removeDXAttr(name: String) throws {
		try self.withDXAttrs { dxSet in
			if let existingIndex = dxSet.firstIndex(where: { $0.name == name }) {
				dxSet.remove(at: existingIndex)
			}
		}
	}

	func clearDXAttrs() throws {
		try self.withDXAttrs { $0.removeAll() }
	}
}
