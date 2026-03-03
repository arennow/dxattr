import CSQLite

public struct SQLiteInterface: ~Copyable {
	let db: OpaquePointer

	public init(path: String) throws {
		var dbPointer: OpaquePointer? = nil
		try sqlite_res_check(sqlite3_open(path, &dbPointer))
		self.db = dbPointer!
	}

	deinit {
		sqlite3_close(db)
	}

	public func execute(query: String) throws {
		try sqlite_res_check(sqlite3_exec(self.db, query, nil, nil, nil))
	}
}

extension SQLiteInterface {
	struct Row {
		let columns: [String: String]
	}
}

let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
