import Dirs
import libdxattr
import Testing

struct MatchupTests {
	let fs: MockFSInterface
	let file: File

	init() throws {
		self.fs = MockFSInterface()
		self.file = try self.fs.createFile(at: "/file")
	}

	func withFN<R>(_ body: (inout FocusNode) throws -> R) rethrows -> R {
		var fn = FocusNode(node: self.file)
		return try body(&fn)
	}

	@Test
	func noSidecarNoFNMatchups() throws {
		try #expect(self.file.extendedAttributeNames() == [])

		try self.withFN { fn in
			try fn.setDXAttr(name: "name", value: "value")
			try fn.clearDXAttrs()
		}

		try self.withFN { fn in
			try #expect(fn.fnMatchups() == .empty)
			try #expect(fn.dbMatchups() == .empty)
		}

		try #expect(self.file.extendedAttributeNames() == [])
	}

	@Test
	func yesSidecarYesFNMatchups() throws {
		try self.withFN { fn in
			try fn.setDXAttr(name: "name", value: "value")
		}

		let (fnMatchups, dbMatchups) = try self.withFN { fn in
			try (fn.fnMatchups(), fn.dbMatchups())
		}

		#expect(fnMatchups == dbMatchups)

		try #expect(self.file.extendedAttributeNames() == [FocusNode.matchupIDXAttrName])
		try #expect(self.file.extendedAttributeString(named: FocusNode.matchupIDXAttrName) == fnMatchups.matchupID?.uuidString)
	}
}
