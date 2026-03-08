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

	@Test
	func noSidecarNoMatchup() throws {
		try #expect(self.file.extendedAttributeNames() == [])

		var fn = FocusNode(node: self.file)
		try fn.setDXAttr(name: "name", value: "value")
		try fn.clearDXAttrs()
		_ = consume fn

		try #expect(self.file.extendedAttributeNames() == [])
	}

	@Test
	func yesSidecarYesMatchup() throws {
		var fn = FocusNode(node: self.file)
		try fn.setDXAttr(name: "name", value: "value")
		let fnMatchups = try fn.matchups()
		_ = consume fn

		try #expect(self.file.extendedAttributeNames() == [FocusNode.matchupIDXAttrName])
		try #expect(self.file.extendedAttributeString(named: FocusNode.matchupIDXAttrName) == fnMatchups.matchupID?.uuidString)
	}
}
