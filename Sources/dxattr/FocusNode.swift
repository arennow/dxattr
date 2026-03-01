import Dirs
import Foundation

struct FocusNode {
	let node: any Node
}

private extension FocusNode {
	var sidecarFile: File {
		get throws {
			let sidecarFileName = "._\(self.node.name).dxattrs"
			return try self.node.parent.newOrExistingFile(at: sidecarFileName)
		}
	}

	func withDXAttrs(_ body: (inout Set<DXAttr>) throws -> Void) throws {
		var dxattrs = try self.dxattrs()
		try body(&dxattrs)
		let encodedData = try JSONEncoder().encode(dxattrs)
		try self.sidecarFile.replaceContents(encodedData)
	}
}

extension FocusNode {
	func dxattrs() throws -> Set<DXAttr> {
		let contents = try self.sidecarFile.contents()
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
}
