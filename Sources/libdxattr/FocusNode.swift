import Dirs
import Foundation

public struct FocusNode: ~Copyable {
	public let node: any Node
	public var ignoreMismatches = false
	private var sqlWrapper: SQLWrapper?
	private var shouldClearFNMatchupsOnDeinit = false

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
			} else if self.shouldClearFNMatchupsOnDeinit {
				try self.node.removeExtendedAttribute(named: Self.matchupIDXAttrName)
			}
		} catch {
			FileHandle.standardError.write(Data("Warning: Failed to delete sidecar file for node '\(self.node.name)': \(error.localizedDescription)\n".utf8))
		}
	}

	private struct WrapperAccessOptions: OptionSet {
		let rawValue: Int

		static let createIfNeeded = Self(rawValue: 1 << 0)
		static let updateMatchupsIfNeeded = Self(rawValue: 1 << 1)
		static let ignoreMatchupMismatches = Self(rawValue: 1 << 2)
	}

	private mutating func withSQLWrapper<R>(accessOptions: WrapperAccessOptions, _ body: (inout SQLWrapper) throws -> R) throws -> R? {
		if self.sqlWrapper == nil {
			var accessOptions = accessOptions
			if self.ignoreMismatches {
				accessOptions.insert(.ignoreMatchupMismatches)
			}

			let resolvedFile: File

			if let existingSidecarFile = try self.existingSidecarFile {
				resolvedFile = existingSidecarFile
			} else if !accessOptions.contains(.ignoreMatchupMismatches), try Self.readMatchupIDString(from: self.node) != nil {
				self.shouldClearFNMatchupsOnDeinit = true
				throw Matchups.MissingSidecar()
			} else {
				if accessOptions.contains(.createIfNeeded) {
					resolvedFile = try self.sidecarFile
				} else {
					return nil
				}
			}

			var newWrapper = try SQLWrapper(file: resolvedFile)

			if !accessOptions.contains(.ignoreMatchupMismatches) {
				let fnMatchups = try self.fnMatchupsIfAny()
				let dbMatchups = try Self.dbMatchupsIfAny(from: &newWrapper)
				try Matchups.checkMatch(fnMatchups, dbMatchups)
			}

			if accessOptions.contains(.updateMatchupsIfNeeded) {
				let matchupID = try Self.ensureMatchupID(on: self.node)
				try newWrapper.setMatchup(key: .matchupID, value: matchupID.uuidString)
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
		try self.withSQLWrapper(accessOptions: []) { wrapper in
			try wrapper.listAttributeNames()
		} ?? []
	}

	mutating func dxattrMetadata() throws -> Set<DXAttrMetadata> {
		try self.withSQLWrapper(accessOptions: []) { wrapper in
			try wrapper.listAttributeNamesWithValueLengths()
		} ?? []
	}

	mutating func dxattrs() throws -> Set<DXAttr> {
		try self.withSQLWrapper(accessOptions: []) { wrapper in
			try wrapper.listAttributeNamesWithValues().setMap { name, value in
				DXAttr(name: name, value: value)
			}
		} ?? []
	}

	mutating func setDXAttr(name: String, value: some IntoData) throws {
		try self.withSQLWrapper(accessOptions: [.createIfNeeded, .updateMatchupsIfNeeded]) { wrapper in
			try wrapper.setAttribute(name: name, value: value.into())
		}
	}

	mutating func removeDXAttr(name: String) throws {
		try self.withSQLWrapper(accessOptions: [.updateMatchupsIfNeeded]) { wrapper in
			try wrapper.removeAttribute(name: name)
		}
	}

	mutating func clearDXAttrs() throws {
		try self.withSQLWrapper(accessOptions: [.updateMatchupsIfNeeded]) { wrapper in
			try wrapper.clearAllAttributes()
		}
	}
}

private extension FocusNode {
	/// Reads the matchupID string from the canonical xattr, falling back to the SMB name.
	static func readMatchupIDString(from node: any Node) throws -> String? {
		if let value = try node.extendedAttributeString(named: Self.matchupIDXAttrName) {
			return value
		}
		return try node.extendedAttributeString(named: Self.smbMatchupIDXAttrName)
	}

	static func ensureMatchupID(on focusNode: any Node) throws -> UUID {
		if let existingIDString = try Self.readMatchupIDString(from: focusNode) {
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
	static let matchupIDXAttrName = "user.com.lithiumcube.dxattr.matchupID"
	/// Read-only fallback for files whose matchup ID was written by an SMB client
	/// as an alternate data stream xattr. Never written by this library.
	static let smbMatchupIDXAttrName = "user.DosStream.user.com.lithiumcube.dxattr.matchupID:$DATA"

	func fnMatchupsIfAny() throws -> Matchups? {
		var outMatchups = Matchups.empty

		if let matchupIDString = try Self.readMatchupIDString(from: self.node) {
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
		try self.withSQLWrapper(accessOptions: [.ignoreMatchupMismatches]) { wrapper in
			try Self.dbMatchupsIfAny(from: &wrapper)
		}.flatMap(\.self)
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
			"Matchup mismatch: \(self.source) \(self.kind) \(self.facet)"
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
