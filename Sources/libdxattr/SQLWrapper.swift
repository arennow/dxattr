import Dirs
import Foundation

struct SQLWrapper: ~Copyable {
	enum StorageKind {
		typealias SerializationLoadFunction = () throws -> Data?
		typealias SerializationStoreFunction = (Data) throws -> Void

		case raw(path: String)
		case inMemory
		case serializing(load: SerializationLoadFunction, store: SerializationStoreFunction)
	}

	let interface: SQLiteInterface
	let serializationStoreFunction: StorageKind.SerializationStoreFunction?
	private var hasPreparedTables = false

	// We'll need the ability to borrow out of a dictionary to do this less stupidly
	// `WritableKeyPath` not requiring its elements to be `Copyable` would be good too
	private var getAttributeStmt: SQLitePreparedStatement?
	private var setAttributeStmt: SQLitePreparedStatement?
	private var listNameStmt: SQLitePreparedStatement?

	init(storage: StorageKind) throws {
		let db: SQLiteInterface
		switch storage {
			case .raw(let path): db = try SQLiteInterface(path: path)
			case .inMemory, .serializing: db = try SQLiteInterface(path: ":memory:")
		}

		try db.execute(query: "PRAGMA journal_mode = DELETE;")

		if case .serializing(let load, let store) = storage {
			if let data = try load() {
				try db.deserialize(from: data)
			}
			self.serializationStoreFunction = store
		} else {
			self.serializationStoreFunction = nil
		}

		self.interface = db
	}

	deinit {
		do {
			try self.serializationStoreFunction?(try self.interface.serialize())
		} catch {
			// We can't really do anything about this, and we don't want to crash, so we'll just ignore it
			print("Warning: Failed to serialize database on deinit: \(error)")
		}
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

	mutating func withListNameStmt<T>(_ body: (borrowing SQLitePreparedStatement) throws -> T) throws -> T {
		try self.prepareTablesIfNeeded()

		if self.listNameStmt == nil {
			self.listNameStmt = try SQLitePreparedStatement(db: self.interface.db,
															statementStr: "SELECT name FROM attrs;")
		}
		return try body(self.listNameStmt!)
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

	mutating func listAttributeNames() throws -> Set<String> {
		try self.withListNameStmt { stmt in
			try stmt.reset()
			var names = Set<String>()
			while try stmt.step() {
				names.insert(try stmt.columnText(at: 0))
			}
			return names
		}
	}

	mutating func getAllAttributes() throws -> Set<DXAttr> {
		var out = Set<DXAttr>()

		for name in try self.listAttributeNames() {
			guard let value = try self.getAttribute(name: name) else {
				continue
			}
			out.insert(DXAttr(name: name, value: value))
		}

		return out
	}
}
