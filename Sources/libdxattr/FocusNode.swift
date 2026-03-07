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

	private mutating func withSQLWrapperIfFileExists<R>(_ body: (inout SQLWrapper) throws -> R) throws -> R? {
		if let sidecarFile = try self.existingSidecarFile {
			return try self.withSQLWrapper(file: sidecarFile, body)
		} else {
			return nil
		}
	}

	private mutating func withSQLWrapper<R>(_ body: (inout SQLWrapper) throws -> R) throws -> R {
		try self.withSQLWrapper(file: self.sidecarFile, body)
	}

	private mutating func withSQLWrapper<R>(file: File, _ body: (inout SQLWrapper) throws -> R) throws -> R {
		if self.sqlWrapper == nil {
			self.sqlWrapper = try SQLWrapper(file: file)
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
	mutating func dxattrNames() throws -> Set<String> {
		try self.withSQLWrapperIfFileExists { wrapper in
			try wrapper.listAttributeNames()
		} ?? []
	}

	mutating func dxattrMetadata() throws -> Set<DXAttrMetadata> {
		try self.withSQLWrapperIfFileExists { wrapper in
			try wrapper.listAttributeNamesWithValueLengths()
		} ?? []
	}

	mutating func dxattrs() throws -> Set<DXAttr> {
		try self.withSQLWrapperIfFileExists { wrapper in
			try wrapper.getAllAttributes()
		} ?? []
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
