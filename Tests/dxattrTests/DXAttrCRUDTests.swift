import Dirs
import Foundation
@testable import libdxattr
import Testing

struct DXAttrCRUDTests {
	let fs: MockFSInterface
	let file: File
	let sidecarFilePath: String
	var sidecarFileExists: Bool {
		get throws {
			try self.fs.rootDir.file(at: self.sidecarFilePath) != nil
		}
	}

	init() throws {
		self.fs = MockFSInterface()
		self.file = try self.fs.createFile(at: "/file")
		self.sidecarFilePath = "/._file.dxattrs"
	}

	func withFN<R>(_ body: (inout FocusNode) throws -> R) rethrows -> R {
		var fn = FocusNode(node: self.file)
		return try body(&fn)
	}

	@Test
	func newFileNoDXAttrs() throws {
		try #expect(self.sidecarFileExists == false)
		try self.withFN { fn in
			try #expect(fn.dxattrs() == [])
		}
		try #expect(self.sidecarFileExists == false)
	}

	@Test
	func addDXAttr() throws {
		try self.withFN { fn in
			try fn.setDXAttr(name: "name", value: "value")
			try #expect(fn.dxattrs() == ["name:value"])
		}
		try #expect(self.sidecarFileExists == true)
	}

	@Test
	func overwriteDXAttr() throws {
		try self.withFN { fn in
			try fn.setDXAttr(name: "name", value: "value")
			try fn.setDXAttr(name: "name", value: "newValue")
			try #expect(fn.dxattrs() == ["name:newValue"])
		}
		try #expect(self.sidecarFileExists == true)
	}

	@Test
	func appendDXAttr() throws {
		try self.withFN { fn in
			try fn.setDXAttr(name: "name1", value: "value1")
			try fn.setDXAttr(name: "name2", value: "value2")
			try #expect(fn.dxattrs() == ["name1:value1", "name2:value2"])
		}
		try #expect(self.sidecarFileExists == true)
	}

	@Test
	func removeDXAttr() throws {
		try self.withFN { fn in
			try fn.setDXAttr(name: "name1", value: "value1")
			try fn.setDXAttr(name: "name2", value: "value2")
			try fn.removeDXAttr(name: "name1")
			try #expect(fn.dxattrs() == ["name2:value2"])
		}
		try #expect(self.sidecarFileExists == true)
	}

	@Test
	func removingAllDXAttrsRemovesSidecarFile() throws {
		try self.withFN { fn in
			try fn.setDXAttr(name: "name1", value: "value1")
			try fn.removeDXAttr(name: "name1")
			try #expect(fn.dxattrs() == [])
		}
		try #expect(self.sidecarFileExists == false)
	}
}
