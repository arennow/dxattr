import libdxattr

extension DXAttr: ExpressibleByStringLiteral {
	public init(stringLiteral value: String) {
		let parts = value.split(separator: ":")
		var partsIterator = parts.makeIterator()
		let name = String(partsIterator.next() ?? "")
		let value = partsIterator.next() ?? ""
		self.init(name: name, value: value)
	}
}
