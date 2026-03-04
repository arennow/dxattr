@testable import dxattr
import Testing

struct IntegerUSFormattedTests {
	@Test func zero() {
		#expect(0.usFormatted == "0")
	}

	@Test func positiveIntegers() {
		#expect(1.usFormatted == "1")
		#expect(12.usFormatted == "12")
		#expect(123.usFormatted == "123")
		#expect(1234.usFormatted == "1,234")
		#expect(12_345.usFormatted == "12,345")
		#expect(123_456.usFormatted == "123,456")
		#expect(1_234_567.usFormatted == "1,234,567")
		#expect(12_345_678.usFormatted == "12,345,678")
		#expect(123_456_789.usFormatted == "123,456,789")
		#expect(1_234_567_890.usFormatted == "1,234,567,890")
	}

	@Test func negativeIntegers() {
		#expect((-1).usFormatted == "-1")
		#expect((-12).usFormatted == "-12")
		#expect((-123).usFormatted == "-123")
		#expect((-1234).usFormatted == "-1,234")
		#expect((-12_345).usFormatted == "-12,345")
		#expect((-123_456).usFormatted == "-123,456")
		#expect((-1_234_567).usFormatted == "-1,234,567")
		#expect((-12_345_678).usFormatted == "-12,345,678")
		#expect((-123_456_789).usFormatted == "-123,456,789")
		#expect((-1_234_567_890).usFormatted == "-1,234,567,890")
	}
}
