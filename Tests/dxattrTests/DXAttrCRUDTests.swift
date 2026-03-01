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
		try #expect(self.fn.existingSidecarFile == nil)
		try #expect(self.fn.dxattrs() == [])
		try #expect(self.fn.existingSidecarFile == nil)
	}

	@Test
	func addDXAttr() throws {
		try self.fn.setDXAttr(name: "name", value: "value")
		try #expect(self.fn.dxattrs() == ["name:value"])
		try #expect(self.fn.existingSidecarFile != nil)
	}

	@Test
	func overwriteDXAttr() throws {
		try self.fn.setDXAttr(name: "name", value: "value")
		try self.fn.setDXAttr(name: "name", value: "newValue")
		try #expect(self.fn.dxattrs() == ["name:newValue"])
		try #expect(self.fn.existingSidecarFile != nil)
	}

	@Test
	func appendDXAttr() throws {
		try self.fn.setDXAttr(name: "name1", value: "value1")
		try self.fn.setDXAttr(name: "name2", value: "value2")
		try #expect(self.fn.dxattrs() == ["name1:value1", "name2:value2"])
		try #expect(self.fn.existingSidecarFile != nil)
	}

	@Test
	func removeDXAttr() throws {
		try self.fn.setDXAttr(name: "name1", value: "value1")
		try self.fn.setDXAttr(name: "name2", value: "value2")
		try self.fn.removeDXAttr(name: "name1")
		try #expect(self.fn.dxattrs() == ["name2:value2"])
		try #expect(self.fn.existingSidecarFile != nil)
	}

	@Test
	func removingAllDXAttrsRemovesSidecarFile() throws {
		try self.fn.setDXAttr(name: "name1", value: "value1")
		try self.fn.removeDXAttr(name: "name1")
		try #expect(self.fn.dxattrs() == [])
		try #expect(self.fn.existingSidecarFile == nil)
	}
}
