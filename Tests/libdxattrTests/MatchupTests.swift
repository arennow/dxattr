import Dirs
import Foundation
@testable import libdxattr
import Testing

struct MatchupTests {
	let fs: MockFSInterface
	let file: File
	var existingSidecarFile: File? {
		try? self.fs.rootDir.file(at: "/._file.dxattrs")
	}

	init() throws {
		self.fs = MockFSInterface()
		self.file = try self.fs.createFile(at: "/file")
	}

	@discardableResult
	func withFN<R>(_ body: (inout FocusNode) throws -> R) rethrows -> R {
		var fn = FocusNode(node: self.file)
		return try body(&fn)
	}

	@Test
	func noSidecarNoMatchups() throws {
		try #expect(self.file.extendedAttributeNames() == [])

		try self.withFN { fn in
			try fn.setDXAttr(name: "name", value: "value")
			try fn.clearDXAttrs()
		}

		try self.withFN { fn in
			try #expect(fn.fnMatchupsIfAny() == nil)
			try #expect(fn.dbMatchupsIfAny() == nil)
		}

		try #expect(self.file.extendedAttributeNames() == [])
	}

	@Test
	func yesSidecarYesMatchups() throws {
		try self.withFN { fn in
			try fn.setDXAttr(name: "name", value: "value")
		}

		let (fnMatchups, dbMatchups) = try self.withFN { fn in
			try (fn.fnMatchupsIfAny(), fn.dbMatchupsIfAny())
		}

		#expect(fnMatchups == dbMatchups)

		try #expect(self.file.extendedAttributeNames() == [FocusNode.matchupIDXAttrName])
		try #expect(self.file.extendedAttributeString(named: FocusNode.matchupIDXAttrName) == fnMatchups?.matchupID?.uuidString)
	}

	@Test
	func nonMatchingMatchups() throws {
		try self.withFN { fn in
			try fn.setDXAttr(name: "name", value: "value")
		}

		try self.file.setExtendedAttribute(named: FocusNode.matchupIDXAttrName, to: UUID().uuidString)
		self.withFN { fn in
			#expect(throws: Matchups.Mismatch(source: .both, kind: .valueMismatch, facet: .matchupID)) {
				try fn.dxattrs()
			}
		}

		try self.file.removeExtendedAttribute(named: FocusNode.matchupIDXAttrName)
		self.withFN { fn in
			#expect(throws: Matchups.Mismatch(source: .focusNode, kind: .missing, facet: .matchupID)) {
				try fn.dxattrs()
			}
		}
	}

	@Test
	func fnMatchupIDButNoDB() throws {
		try self.file.setExtendedAttribute(named: FocusNode.matchupIDXAttrName, to: "any random string")
		self.withFN { fn in
			#expect(throws: Matchups.MissingSidecar()) {
				try fn.dxattrs()
			}
		}
	}

	@Test
	func overrideNonMatchingMatchupsForReads() throws {
		try self.withFN { fn in
			try fn.setDXAttr(name: "name", value: "value")
		}

		try self.file.setExtendedAttribute(named: FocusNode.matchupIDXAttrName, to: UUID().uuidString)
		try self.withFN { fn in
			#expect(throws: Matchups.Mismatch(source: .both, kind: .valueMismatch, facet: .matchupID)) {
				try fn.dxattrs()
			}

			fn.ignoreMismatches = true
			try #expect(fn.dxattrNames() == ["name"])
			try #expect(fn.dxattrMetadata() == [.init(name: "name", valueLength: 5)])
			try #expect(fn.dxattrs() == ["name:value"])
		}

		try self.existingSidecarFile?.delete()
		try self.withFN { fn in
			#expect(throws: Matchups.MissingSidecar()) {
				try fn.dxattrs()
			}

			fn.ignoreMismatches = true
			try #expect(fn.dxattrNames() == [])
			try #expect(fn.dxattrMetadata() == [])
			try #expect(fn.dxattrs() == [])
		}
	}

	@Test
	func overrideNonMatchingMatchupsForWrites() throws {
		try self.withFN { fn in
			try fn.setDXAttr(name: "name1", value: "value1")
		}

		let newUUID = UUID()

		try self.file.setExtendedAttribute(named: FocusNode.matchupIDXAttrName, to: newUUID.uuidString)
		try self.withFN { fn in
			#expect(throws: Matchups.Mismatch(source: .both, kind: .valueMismatch, facet: .matchupID)) {
				try fn.setDXAttr(name: "name2", value: "value2")
			}

			fn.ignoreMismatches = true
			try fn.setDXAttr(name: "name3", value: "value3")
			try #expect(fn.dxattrs() == ["name1:value1", "name3:value3"])
			try #expect(fn.dbMatchupsIfAny()?.matchupID == newUUID)
		}

		try self.existingSidecarFile?.delete()
		try self.withFN { fn in
			#expect(throws: Matchups.MissingSidecar()) {
				try fn.setDXAttr(name: "name4", value: "value4")
			}

			fn.ignoreMismatches = true
			try fn.setDXAttr(name: "name5", value: "value5")

			try #expect(fn.dxattrs() == ["name5:value5"])
			try #expect(fn.dbMatchupsIfAny()?.matchupID == newUUID)
		}
	}

	@Test
	func overrideNonMatchingMatchupsForRemoves() throws {
		try self.withFN { fn in
			try fn.setDXAttr(name: "name1", value: "value1")
			try fn.setDXAttr(name: "name2", value: "value2")
		}

		let newUUID = UUID()

		try self.file.setExtendedAttribute(named: FocusNode.matchupIDXAttrName, to: newUUID.uuidString)
		try self.withFN { fn in
			#expect(throws: Matchups.Mismatch(source: .both, kind: .valueMismatch, facet: .matchupID)) {
				try fn.removeDXAttr(name: "name1")
			}

			fn.ignoreMismatches = true
			try fn.removeDXAttr(name: "name1")
			try #expect(fn.dxattrs() == ["name2:value2"])
			try #expect(fn.fnMatchupsIfAny()?.matchupID == newUUID)
			try #expect(fn.dbMatchupsIfAny()?.matchupID == newUUID)
		}

		try self.existingSidecarFile?.delete()
		try self.withFN { fn in
			#expect(throws: Matchups.MissingSidecar()) {
				try fn.removeDXAttr(name: "name2")
			}

			fn.ignoreMismatches = true
			try fn.removeDXAttr(name: "name2")

			try #expect(fn.dxattrs() == [])
		}

		try self.withFN { fn in
			try #expect(fn.fnMatchupsIfAny()?.matchupID == nil)
		}
		#expect(self.existingSidecarFile == nil)
	}

	/// Verifies that a matchup ID stored only under the SMB xattr name is found when
	/// reading, that writes succeed without promoting to the canonical name, and that
	/// creating a brand-new matchup ID only ever uses the canonical name.
	@Test
	func smbXAttrNameFallbackRead() throws {
		// Set up: write a dxattr so a sidecar exists with a known matchupID
		try self.withFN { fn in
			try fn.setDXAttr(name: "key", value: "val")
		}

		// Move the matchup ID to the SMB name only
		let originalUUID = try self.withFN { fn in try fn.fnMatchupsIfAny()?.matchupID }
		try self.file.removeExtendedAttribute(named: FocusNode.matchupIDXAttrName)
		try self.file.setExtendedAttribute(named: FocusNode.smbMatchupIDXAttrName, to: try #require(originalUUID?.uuidString))

		// Reading via the SMB name should work and return the correct matchupID
		try self.withFN { fn in
			try #expect(fn.fnMatchupsIfAny()?.matchupID == originalUUID)
			try #expect(fn.dxattrs() == ["key:val"])
		}
	}

	@Test
	func smbXAttrNameFallbackWrite() throws {
		// Set up: write a dxattr so a sidecar exists with a known matchupID
		try self.withFN { fn in
			try fn.setDXAttr(name: "key", value: "val")
		}

		// Move the matchup ID to the SMB name only
		let originalUUID = try self.withFN { fn in try fn.fnMatchupsIfAny()?.matchupID }
		try self.file.removeExtendedAttribute(named: FocusNode.matchupIDXAttrName)
		try self.file.setExtendedAttribute(named: FocusNode.smbMatchupIDXAttrName, to: try #require(originalUUID?.uuidString))

		// Writing with SMB-only matchup ID should succeed
		try self.withFN { fn in
			try fn.setDXAttr(name: "key2", value: "val2")
		}

		// The SMB xattr is left unchanged and the canonical name is NOT written
		try #expect(self.file.extendedAttributeString(named: FocusNode.smbMatchupIDXAttrName) == originalUUID!.uuidString)
		try #expect(self.file.extendedAttributeString(named: FocusNode.matchupIDXAttrName) == nil)

		// The written dxattr is readable
		try self.withFN { fn in
			try #expect(fn.dxattrs() == ["key:val", "key2:val2"])
		}
	}

	@Test
	func newMatchupIDUsesCanonicalNameOnly() throws {
		// Create a fresh file with no xattrs and write a dxattr
		try self.withFN { fn in
			try fn.setDXAttr(name: "key", value: "val")
		}

		// Only the canonical xattr name should be present; the SMB name must not be written
		try #expect(self.file.extendedAttributeNames() == [FocusNode.matchupIDXAttrName])
		try #expect(self.file.extendedAttributeString(named: FocusNode.smbMatchupIDXAttrName) == nil)
	}
}
