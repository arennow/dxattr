import Dirs
import Foundation

public struct FocusNode: ~Copyable {
	public let node: any Node

	public init(node: any Node) {
		self.node = node
	}
}

private extension FocusNode {
	var sidecarFileName: String {
		"._\(self.node.name).dxattrs"
	}

	var existingSidecarFile: File? {
		get throws {
			try self.node.parent.file(at: self.sidecarFileName)
		}
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

		var wrapper = try SQLWrapper(file: sidecarFile)
		let attrs = try wrapper.getAllAttributes()
		return (attrs, sidecarFile)
	}

	func withDXAttrs(_ body: (inout Set<DXAttr>) throws -> Void) throws {
		var (dxattrs, sidecarFile) = try self.dxAttrsAndFile()
		try body(&dxattrs)

		if dxattrs.isEmpty {
			// If there are no dxattrs, remove the sidecar file if it exists
			try sidecarFile?.delete()
			return
		} else {
			try sidecarFile?.delete()

			var wrapper = try SQLWrapper(file: self.sidecarFile)
			for dx in dxattrs {
				try wrapper.setAttribute(name: dx.name, value: dx.value)
			}
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
