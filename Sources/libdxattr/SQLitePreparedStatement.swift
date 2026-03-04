import CSQLite
import Dirs
import Foundation

struct SQLitePreparedStatement: ~Copyable {
	let statementHandle: OpaquePointer

	init(db: OpaquePointer, statementStr: String) throws {
		let statementHandle = try statementStr.withUTF8CString { ccharStrBuf in
			var statementHandle: OpaquePointer?
			let res = sqlite3_prepare_v2(db,
										 ccharStrBuf.baseAddress,
										 -1,
										 &statementHandle,
										 nil)

			try sqlite_res_check(res)
			return statementHandle!
		}

		self.statementHandle = statementHandle
	}

	deinit {
		sqlite3_finalize(self.statementHandle)
	}

	func reset() throws {
		try sqlite_res_check(sqlite3_reset(self.statementHandle))
	}

	// TODO: Return an enum instead of Bool to distinguish between "row available", "done", and "error" states
	func step() throws -> Bool {
		let res = sqlite3_step(self.statementHandle)
		switch res {
			case SQLITE_ROW:
				return true
			case SQLITE_DONE:
				return false
			default:
				try sqlite_res_check(res)
				fatalError("sqlite_res_check should have thrown an error for code \(res)")
		}
	}
}

extension SQLitePreparedStatement {
	func bindText(_ text: String, at index: Int) throws {
		try text.withUTF8CString { strBuf in
			let res = sqlite3_bind_text(self.statementHandle,
										numericCast(index),
										strBuf.baseAddress,
										-1,
										SQLITE_TRANSIENT)
			try sqlite_res_check(res)
		}
	}

	func bindBlob(_ data: some IntoData, at index: Int) throws {
		try data.into().withUnsafeBytes { buf in
			let res = sqlite3_bind_blob(self.statementHandle,
										numericCast(index),
										buf.baseAddress,
										numericCast(buf.count),
										SQLITE_TRANSIENT)
			try sqlite_res_check(res)
		}
	}
}

extension SQLitePreparedStatement {
	func columnText(at index: Int) throws -> String {
		let index = Int32(index)
		guard let cStrPtr = sqlite3_column_text(self.statementHandle, index) else {
			return ""
		}
		return String(cString: cStrPtr)
	}

	func columnBlob(at index: Int) throws -> Data {
		let index = Int32(index)
		guard let blobPtr = sqlite3_column_blob(self.statementHandle, index) else {
			return Data()
		}
		let blobSize = sqlite3_column_bytes(self.statementHandle, index)
		return Data(bytes: blobPtr, count: numericCast(blobSize))
	}
}
