import Dirs
@testable import dxattr
import Testing

struct DXAttrCRUDTests {
	let fs: MockFSInterface
	let file: File
	let fn: FocusNode

	init() throws {
		self.fs = MockFSInterface()
		self.file = try self.fs.createFile(at: "/file")
		self.fn = FocusNode(node: self.file)
	}

	@Test
	func newFileNoDXAttrs() {
		#expect(self.fn.dxattrs.isEmpty)
	}
}
