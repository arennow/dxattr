import Dirs
import Foundation

struct FocusNode {
	let node: any Node
}

extension FocusNode {
	var existingSidecarFile: File? {
		get throws {
			try self.node.parent.file(at: self.sidecarFileName)
		}
	}
}

private extension FocusNode {
	private var sidecarFileName: String {
		"._\(self.node.name).dxattrs"
	}

	var sidecarFile: File {
		get throws {
			try self.node.parent.newOrExistingFile(at: self.sidecarFileName)
		}
	}

	func withDXAttrs(_ body: (inout Set<DXAttr>) throws -> Void) throws {
		var dxattrs = try self.dxattrs()
		try body(&dxattrs)

		if dxattrs.isEmpty {
			// If there are no dxattrs, remove the sidecar file if it exists
			if let existingSidecarFile = try self.existingSidecarFile {
				try existingSidecarFile.delete()
			}
			return
		} else {
			let encodedData = try JSONEncoder().encode(dxattrs)
			try self.sidecarFile.replaceContents(encodedData)
		}
	}
}

extension FocusNode {
	func dxattrs() throws -> Set<DXAttr> {
		guard let sidecarFile = try self.existingSidecarFile else {
			return []
		}

		let contents = try sidecarFile.contents()
		do {
			return try JSONDecoder().decode(Set<DXAttr>.self, from: contents)
		} catch DecodingError.dataCorrupted(let context) {
			if context.codingPath.isEmpty {
				// If there's a data corruption at the root, the file is probably empty
				// or otherwise not meaningful, so treat it as empty
				return []
			} else {
				throw DecodingError.dataCorrupted(context)
			}
		}
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
}
