import Dirs
import Foundation

struct SQLWrapper: ~Copyable {
	let interface: SQLiteInterface
	private var hasPreparedTables = false

	// We'll need the ability to borrow out of a dictionary to do this less stupidly
	// `WritableKeyPath` not requiring its elements to be `Copyable` would be good too
	private var getAttributeStmt: SQLitePreparedStatement?
	private var setAttributeStmt: SQLitePreparedStatement?

	init(path: String) throws {
		let db = try SQLiteInterface(path: path)
		try db.execute(query: "PRAGMA journal_mode = DELETE;")
		self.interface = db
	}
}

private extension SQLWrapper {
	mutating func prepareTables() throws {
		try self.interface.execute(query: """
			CREATE TABLE IF NOT EXISTS attrs (
				name TEXT PRIMARY KEY,
				value BLOB
			) WITHOUT ROWID;
		""")

		self.hasPreparedTables = true
	}

	mutating func prepareTablesIfNeeded() throws {
		if !self.hasPreparedTables {
			try self.prepareTables()
			self.hasPreparedTables = true
		}
	}

	mutating func withGetAttributeStmt<T>(_ body: (borrowing SQLitePreparedStatement) throws -> T) throws -> T {
		try self.prepareTablesIfNeeded()

		if self.getAttributeStmt == nil {
			self.getAttributeStmt = try SQLitePreparedStatement(db: self.interface.db,
																statementStr: "SELECT value FROM attrs WHERE name = ?;")
		}
		return try body(self.getAttributeStmt!)
	}

	mutating func withSetAttributeStmt<T>(_ body: (borrowing SQLitePreparedStatement) throws -> T) throws -> T {
		try self.prepareTablesIfNeeded()

		if self.setAttributeStmt == nil {
			self.setAttributeStmt = try SQLitePreparedStatement(db: self.interface.db,
																statementStr: "INSERT OR REPLACE INTO attrs (name, value) VALUES (?, ?);")
		}
		return try body(self.setAttributeStmt!)
	}
}

extension SQLWrapper {
	mutating func getAttribute(name: String) throws -> Data? {
		try self.withGetAttributeStmt { stmt in
			try stmt.reset()
			try stmt.bindText(name, at: 1)
			if try stmt.step() {
				return try stmt.columnBlob(at: 0)
			} else {
				return nil
			}
		}
	}

	mutating func setAttribute(name: String, value: some IntoData) throws {
		try self.withSetAttributeStmt { stmt in
			try stmt.reset()
			try stmt.bindText(name, at: 1)
			try stmt.bindBlob(value, at: 2)
			let res = try stmt.step()
			assert(res == false, "Expected step to return false after executing an INSERT statement, but got \(res)")
		}
	}
}
