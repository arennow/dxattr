import Dirs
import Foundation
@testable import libdxattr
import Testing

struct MatchupTests {
	let fs: MockFSInterface
	let file: File

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
}
