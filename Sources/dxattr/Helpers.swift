extension BinaryInteger {
	var usFormatted: String {
		let isNegative = self < 0
		var digits = Array(isNegative ? self.description.dropFirst() : self.description[...])
		var i = digits.count - 3
		while i > 0 {
			digits.insert(",", at: i)
			i -= 3
		}
		let formatted = String(digits)
		return isNegative ? "-\(formatted)" : formatted
	}
}
