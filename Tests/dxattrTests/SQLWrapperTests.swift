import Foundation
@testable import libdxattr
import Testing

struct SQLWrapperTests: ~Copyable {
	var wrapper: SQLWrapper

	init() throws {
		self.wrapper = try SQLWrapper(path: ":memory:")
	}

	@Test
	mutating func readEmpty() throws {
		let val1 = try self.wrapper.getAttribute(name: "name")
		let val2 = try self.wrapper.getAttribute(name: "name")
		#expect(val1 == nil)
		#expect(val2 == nil)
	}

	@Test
	mutating func setNew() throws {
		try self.wrapper.setAttribute(name: "name", value: "value")
		let val1 = try self.wrapper.getAttribute(name: "name")
		let val2 = try self.wrapper.getAttribute(name: "name")

		#expect(val1 == Data("value".utf8))
		#expect(val1 == val2)
	}
}
