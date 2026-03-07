import Dirs
import Foundation

public struct DXAttr: Hashable {
	public let name: String
	public let value: Data

	public init(name: some IntoString, value: some IntoData) {
		self.name = name.into()
		self.value = value.into()
	}
}

extension DXAttr: CustomDebugStringConvertible {
	public var debugDescription: String {
		"\(self.name):\(String(decoding: self.value.prefix(128), as: UTF8.self))"
	}
}

public struct DXAttrMetadata: Hashable {
	public let name: String
	public let valueLength: Int

	public init(name: some IntoString, valueLength: Int) {
		self.name = name.into()
		self.valueLength = valueLength
	}
}
