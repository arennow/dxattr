import Dirs
import Foundation

public struct FocusNode: ~Copyable {
	public let node: any Node
	private var sqlWrapper: SQLWrapper?

	public init(node: any Node) {
		self.node = node
	}

	deinit {
		do {
			if try self.sqlWrapper?.canDelete() == true {
				#if os(Windows)
					#warning("This might be unsafe on Windows")
				#endif
				// On UNIX, it's safe to delete the file while the DB is still open
				// (`sqlWrapper != nil`). Windows platforms may have issues
				try self.existingSidecarFile?.delete()
			}
		} catch {
			fputs("Warning: Failed to delete sidecar file for node '\(self.node.name)': \(error.localizedDescription)\n", stderr)
		}
	}

	private mutating func withSQLWrapper<R>(_ body: (inout SQLWrapper) throws -> R) throws -> R {
		if self.sqlWrapper == nil {
			self.sqlWrapper = try SQLWrapper(file: self.sidecarFile)
		}

		return try body(&self.sqlWrapper!)
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
}

public extension FocusNode {
	mutating func dxattrs() throws -> Set<DXAttr> {
		try self.withSQLWrapper { wrapper in
			try wrapper.getAllAttributes()
		}
	}

	mutating func setDXAttr(name: String, value: some IntoData) throws {
		try self.withSQLWrapper { wrapper in
			try wrapper.setAttribute(name: name, value: value.into())
		}
	}

	mutating func removeDXAttr(name: String) throws {
		try self.withSQLWrapper { wrapper in
			try wrapper.removeAttribute(name: name)
		}
	}

	mutating func clearDXAttrs() throws {
		try self.withSQLWrapper { wrapper in
			try wrapper.clearAllAttributes()
		}
	}
}
