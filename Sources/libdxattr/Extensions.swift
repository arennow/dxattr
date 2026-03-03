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
