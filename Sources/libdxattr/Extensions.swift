extension String {
	func withUTF8CString<T>(_ body: (UnsafeBufferPointer<CChar>) throws -> T) rethrows -> T {
		var zelf = self
		return try zelf.withUTF8 { utf8StrBuf in
			try utf8StrBuf.withMemoryRebound(to: CChar.self) { ccharStrBuf in
				try body(ccharStrBuf)
			}
		}
	}
}

extension Sequence {
	func setMap<T: Hashable>(_ transform: (Element) throws -> T) rethrows -> Set<T> {
		var out = Set<T>()
		for element in self {
			try out.insert(transform(element))
		}
		return out
	}
}
