import Dirs
import Foundation

public struct FocusNode: ~Copyable {
	public let node: any Node
	public var ignoreMismatches = false
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
			if !self.ignoreMismatches, try self.node.extendedAttributeString(named: Self.matchupIDXAttrName) != nil {
				throw Matchups.MissingSidecar()
			} else {
				return nil
			}
		}
	}

	private mutating func withSQLWrapperIfFileExists<R>(_ body: (inout SQLWrapper) throws -> R?) throws -> R? {
		try self.existingSidecarFile.flatMap { sidecarFile in
			try self.withSQLWrapper(file: sidecarFile, body)
		}
	}

	private mutating func withSQLWrapper<R>(_ body: (inout SQLWrapper) throws -> R) throws -> R {
		try self.withSQLWrapper(file: self.sidecarFile, body)
	}

	private mutating func withSQLWrapper<R>(file: File, _ body: (inout SQLWrapper) throws -> R) throws -> R {
		if self.sqlWrapper == nil {
			var newWrapper = try SQLWrapper(file: file)

			let (fnMatchups, dbMatchups) = (try self.fnMatchupsIfAny(), try Self.dbMatchupsIfAny(from: &newWrapper))

			if !self.ignoreMismatches {
				try Matchups.checkMatch(fnMatchups, dbMatchups)
			}

			self.sqlWrapper = consume newWrapper
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
			try wrapper.listAttributeNamesWithValues().setMap { name, value in
				DXAttr(name: name, value: value)
			}
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
	static func ensureMatchupID(on focusNode: any Node) throws -> UUID {
		if let existingIDString = try focusNode.extendedAttributeString(named: Self.matchupIDXAttrName) {
			if let uuid = UUID(uuidString: existingIDString) {
				return uuid
			} else {
				throw Matchups.DecodingError.invalidIDUUIDString(existingIDString)
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

	func fnMatchupsIfAny() throws -> Matchups? {
		var outMatchups = Matchups.empty

		if let matchupIDString = try self.node.extendedAttributeString(named: Self.matchupIDXAttrName) {
			if let matchupID = UUID(uuidString: matchupIDString) {
				outMatchups.matchupID = matchupID
			} else {
				throw Matchups.DecodingError.invalidIDUUIDString(matchupIDString)
			}
		}

		if outMatchups == .empty {
			return nil
		} else {
			return outMatchups
		}
	}

	mutating func dbMatchupsIfAny() throws -> Matchups? {
		try self.withSQLWrapperIfFileExists { wrapper in
			try Self.dbMatchupsIfAny(from: &wrapper)
		}
	}

	private static func dbMatchupsIfAny(from wrapper: inout SQLWrapper) throws -> Matchups? {
		guard let matchupIDData = try wrapper.getMatchup(key: .matchupID) else {
			return nil
		}

		var outMatchups = Matchups.empty

		if let matchupIDString = String(data: matchupIDData, encoding: .utf8) {
			if let matchupID = UUID(uuidString: matchupIDString) {
				outMatchups.matchupID = matchupID
			} else {
				throw Matchups.DecodingError.invalidIDUUIDString(matchupIDString)
			}
		}

		return outMatchups
	}
}

public struct Matchups: Equatable, Sendable {
	public struct Mismatch: Error, Equatable, Sendable, CustomStringConvertible {
		public enum Source: Sendable { case focusNode, database, both }
		public enum Kind: Sendable { case missing, valueMismatch }
		public enum Facet: Sendable { case matchupID }

		public let source: Source
		public let kind: Kind
		public let facet: Facet

		public var description: String {
			"Matchup mismatch: \(self.source) \(self.kind): \(self.facet)"
		}
	}

	/// Only for when there's a matchup ID in the FocusNode but no sidecar db file
	public struct MissingSidecar: Error, Equatable, Sendable, CustomStringConvertible {
		public var description: String {
			"Missing sidecar file for matchup ID"
		}
	}

	enum DecodingError: Error {
		case invalidIDUUIDString(String)
	}

	static var empty: Matchups {
		Matchups(matchupID: nil)
	}

	public internal(set) var matchupID: UUID?

	static func checkMatch(_ fnMatchup: Matchups?, _ dbMatchup: Matchups?) throws {
		if fnMatchup == nil, dbMatchup == nil {
			// If they're both nil, it's a match (no dxattrs have been set up yet)
			return
		}

		guard let fnID = fnMatchup?.matchupID else {
			throw Mismatch(source: .focusNode, kind: .missing, facet: .matchupID)
		}

		guard let dbID = dbMatchup?.matchupID else {
			throw Mismatch(source: .database, kind: .missing, facet: .matchupID)
		}

		guard fnID == dbID else {
			throw Mismatch(source: .both, kind: .valueMismatch, facet: .matchupID)
		}
	}
}
