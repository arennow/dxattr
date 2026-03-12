import Dirs
import Foundation
@testable import libdxattr
import Testing

struct MatchupTests {
	let fs: MockFSInterface
	let file: File
	var sidecarFile: File? {
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

		try self.sidecarFile?.delete()
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

		try self.sidecarFile?.delete()
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
}
