import CSQLite
import Foundation

public struct SQLiteInterface: ~Copyable {
	let db: OpaquePointer

	public init(path: String) throws {
		var dbPointer: OpaquePointer? = nil
		try sqlite_res_check(sqlite3_open(path, &dbPointer))
		self.db = dbPointer!
	}

	deinit {
		// Use sqlite3_close_v2 rather than sqlite3_close so that if any prepared
		// statements (held by SQLWrapper) happen to be deinitialized after this
		// connection (destruction order of ~Copyable struct properties is
		// unspecified), the connection becomes a "zombie" and is properly closed
		// once the last associated resource is released, preventing FD leaks.
		sqlite3_close_v2(db)
	}

	public func execute(query: String) throws {
		try sqlite_res_check(sqlite3_exec(self.db, query, nil, nil, nil))
	}

	public func queryProducesRows(query: String) throws -> Bool {
		let stmt = try SQLitePreparedStatement(db: self.db, statementStr: query)
		return try stmt.step() == .row
	}
}

extension SQLiteInterface {
	func deserialize(from data: Data) throws {
		let bufSize: sqlite3_uint64 = numericCast(data.count + 1_048_576) // + 1 MiB
		guard let sqlManagedBuffer = sqlite3_malloc64(bufSize) else {
			throw SQLiteErrorCode.noMem
		}
		data.withUnsafeBytes { srcBuf in
			if let baseAddress = srcBuf.baseAddress {
				_ = memcpy(sqlManagedBuffer, baseAddress, srcBuf.count)
			}
		}

		// `SQLITE_DESERIALIZE_RESIZEABLE` allows SQLite to resize the buffer as needed,
		// and `SQLITE_DESERIALIZE_FREEONCLOSE` tells it to free the buffer when it's done with it,
		// so we don't have to worry about freeing it ourselves

		let res = sqlite3_deserialize(self.db,
									  nil,
									  sqlManagedBuffer,
									  numericCast(data.count),
									  numericCast(bufSize),
									  numericCast(SQLITE_DESERIALIZE_RESIZEABLE | SQLITE_DESERIALIZE_FREEONCLOSE))
		try sqlite_res_check(res)
	}

	func serialize() throws -> Data {
		var bufSize: sqlite3_uint64 = 0
		guard let sqlManagedBuffer = sqlite3_serialize(self.db, nil, &bufSize, 0) else {
			throw SQLiteInterfaceError.noSerializationData
		}

		return Data(bytesNoCopy: sqlManagedBuffer,
					count: numericCast(bufSize),
					deallocator: .custom { (ptr, _) in sqlite3_free(ptr) })
	}
}

// periphery:ignore - Just for parallelism with `SQLITE_TRANSIENT`
let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
