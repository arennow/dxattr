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
}

extension FocusNode {
	func dxattrs() throws -> Array<DXAttr> {
		let contents = try self.sidecarFile.contents()
		do {
			return try JSONDecoder().decode(Array<DXAttr>.self, from: contents)
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
		let newDXAttr = DXAttr(name: name, value: value.into())
		let encodedData = try JSONEncoder().encode([newDXAttr])
		try self.sidecarFile.replaceContents(encodedData)
	}
}
