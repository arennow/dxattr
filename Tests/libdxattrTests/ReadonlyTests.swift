import Dirs
@testable import libdxattr
import Testing

struct ReadonlyTests {
	let fs: MockFSInterface
	let file: File

	init() throws {
		self.fs = MockFSInterface()
		self.file = try self.fs.createFile(at: "/file")
	}

	@Test
	func noMutationsWhenReadingWithoutSidecar() throws {
		try self.fs.setWritableForTesting(at: self.fs.rootDir, writable: false)
		var fn = FocusNode(node: self.file)

		try #expect(fn.dxattrNames() == [])
		try #expect(fn.dxattrMetadata() == [])
		try #expect(fn.dxattrs() == [])
	}

	@Test
	func noMutationsWhenReadingWithSidecar() throws {
		var fn = FocusNode(node: self.file)
		try fn.setDXAttr(name: "name", value: "value!")
		_ = consume fn

		try self.fs.setWritableForTesting(at: self.fs.rootDir, writable: false)
		fn = FocusNode(node: self.file)

		try #expect(fn.dxattrNames() == ["name"])
		try #expect(fn.dxattrMetadata() == [DXAttrMetadata(name: "name", valueLength: 6)])
		try #expect(fn.dxattrs() == ["name:value!"])
	}
}
