import Foundation
@testable import libdxattr
import Testing

struct SQLWrapperInMemoryTests: ~Copyable {
	var wrapper: SQLWrapper

	init() throws {
		self.wrapper = try SQLWrapper(storage: .inMemory)
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

	@Test
	mutating func listAttributeNames() throws {
		try self.wrapper.setAttribute(name: "name1", value: "value1")
		try self.wrapper.setAttribute(name: "name2", value: "value2")

		try #expect(self.wrapper.listAttributeNames() == Set(["name1", "name2"]))
		try #expect(self.wrapper.listAttributeNames() == Set(["name1", "name2"]))
	}

	@Test
	mutating func getAllAttributes() throws {
		try self.wrapper.setAttribute(name: "name1", value: "value1")
		try self.wrapper.setAttribute(name: "name2", value: "value2")

		try #expect(self.wrapper.getAllAttributes() == ["name1:value1", "name2:value2"])
	}
}

final class SQLWrapperSerializingTests {
	private var persistence: Data?
	private func createWrapper() throws -> SQLWrapper {
		try SQLWrapper(storage: .serializing(load: { self.persistence }, store: { self.persistence = $0 }))
	}

	@Test
	func readEmpty() throws {
		var wrapper = try self.createWrapper()

		let val1 = try wrapper.getAttribute(name: "name")
		let val2 = try wrapper.getAttribute(name: "name")
		#expect(val1 == nil)
		#expect(val2 == nil)

		_ = consume wrapper
		#expect(self.persistence != nil)

		wrapper = try self.createWrapper()

		let val3 = try wrapper.getAttribute(name: "name")
		let val4 = try wrapper.getAttribute(name: "name")
		#expect(val3 == nil)
		#expect(val4 == nil)

		_ = consume wrapper
		#expect(self.persistence != nil)
	}

	@Test
	func setNew() throws {
		var wrapper = try self.createWrapper()

		try wrapper.setAttribute(name: "name", value: "value")
		let val1 = try wrapper.getAttribute(name: "name")
		let val2 = try wrapper.getAttribute(name: "name")
		#expect(val1 == Data("value".utf8))
		#expect(val1 == val2)

		_ = consume wrapper
		#expect(self.persistence != nil)

		wrapper = try self.createWrapper()

		let val3 = try wrapper.getAttribute(name: "name")
		let val4 = try wrapper.getAttribute(name: "name")
		#expect(val3 == Data("value".utf8))
		#expect(val3 == val4)

		_ = consume wrapper
		#expect(self.persistence != nil)
	}
}
