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
}
