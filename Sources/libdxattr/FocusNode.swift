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
				try self.node.removeExtendedAttribute(named: Self.matchupIDXAttrName)
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
		try self.withSQLWrapper { [focusNode = self.node] wrapper in
			try wrapper.setAttribute(name: name, value: value.into())

			let matchupID = try Self.ensureMatchupID(on: focusNode)
			try wrapper.setMatchup(key: .matchupID, value: matchupID.uuidString)
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

private extension FocusNode {
	enum MatchupIDError: Error {
		case invalidUUIDString(String)
	}

	static func ensureMatchupID(on focusNode: any Node) throws -> UUID {
		if let existingIDString = try focusNode.extendedAttributeString(named: Self.matchupIDXAttrName) {
			if let uuid = UUID(uuidString: existingIDString) {
				return uuid
			} else {
				throw MatchupIDError.invalidUUIDString(existingIDString)
			}
		} else {
			let newID = UUID()
			try focusNode.setExtendedAttribute(named: Self.matchupIDXAttrName, to: newID.uuidString)
			return newID
		}
	}
}

public extension FocusNode {
	static let matchupIDXAttrName = "com.lithiumcube.dxattr.matchupID"

	func fnMatchups() throws -> Matchups {
		var outMatchups = Matchups.empty

		if let matchupIDString = try self.node.extendedAttributeString(named: Self.matchupIDXAttrName) {
			if let matchupID = UUID(uuidString: matchupIDString) {
				outMatchups.matchupID = matchupID
			} else {
				throw MatchupIDError.invalidUUIDString(matchupIDString)
			}
		}

		return outMatchups
	}

	mutating func dbMatchups() throws -> Matchups {
		var outMatchups = Matchups.empty

		try self.withSQLWrapperIfFileExists { wrapper in
			if let matchupIDData = try wrapper.getMatchup(key: .matchupID),
			   let matchupIDString = String(data: matchupIDData, encoding: .utf8)
			{
				if let matchupID = UUID(uuidString: matchupIDString) {
					outMatchups.matchupID = matchupID
				} else {
					throw MatchupIDError.invalidUUIDString(matchupIDString)
				}
			}
		}

		return outMatchups
	}
}

public struct Matchups: Equatable, Sendable {
	package static var empty: Matchups {
		Matchups(matchupID: nil)
	}

	public internal(set) var matchupID: UUID?
}
