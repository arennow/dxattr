import Dirs
@testable import dxattr
import Foundation
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
	func newFileNoDXAttrs() throws {
		#expect(try self.fn.dxattrs() == [])
	}

	@Test
	func addDXAttr() throws {
		try self.fn.setDXAttr(name: "name", value: "value")
		#expect(try self.fn.dxattrs() == [DXAttr(name: "name", value: Data("value".utf8))])
	}
}
