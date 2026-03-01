import Dirs
import Foundation

struct DXAttr: Hashable, Codable {
	let name: String
	let value: Data

	init(name: some IntoString, value: some IntoData) {
		self.name = name.into()
		self.value = value.into()
	}
}

extension DXAttr: ExpressibleByStringLiteral {
	init(stringLiteral value: String) {
		let parts = value.split(separator: ":")
		var partsIterator = parts.makeIterator()
		let name = String(partsIterator.next() ?? "")
		let value = partsIterator.next() ?? ""
		self.init(name: name, value: value)
	}
}

extension DXAttr: CustomDebugStringConvertible {
	var debugDescription: String {
		"\(self.name):\(String(decoding: self.value.prefix(128), as: UTF8.self))"
	}
}
