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
	private var listNamesStmt: SQLitePreparedStatement?
	private var listNamesWithValueLengthsStmt: SQLitePreparedStatement?
	private var listNamesWithValuesStmt: SQLitePreparedStatement?
	private var removeAttributeStmt: SQLitePreparedStatement?
	private var clearAllAttributesStmt: SQLitePreparedStatement?

	private var getMatchupStmt: SQLitePreparedStatement?
	private var setMatchupStmt: SQLitePreparedStatement?

	init(file: File) throws {
		if file.fs is MockFSInterface {
			try self.init(storage: .serializing(load: {
				try file.contents()
			}, store: { newValue in
				try file.replaceContents(newValue)
			}))
		} else {
			try self.init(storage: .raw(path: file.path.string))
		}
	}

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
		} catch is NoSuchNode {
			#if os(Windows)
				#warning("This might be unsafe on Windows")
			#endif
			// This can happen if the database file was deleted while the db connection is open
			// That's fine on UNIX systems, since their file handle remains open even after
			// a delete
		} catch {
			// We can't really do anything about this, and we don't want to crash, so we'll just ignore it
			fputs("Warning: Failed to serialize database on deinit: \(error)\n", stderr)
		}
	}

	func canDelete() throws -> Bool {
		do {
			try self.interface.execute(query: "BEGIN EXCLUSIVE;")
			let tableHasContent = try self.interface.queryProducesRows(query: "SELECT 1 FROM attrs LIMIT 1;")
			try self.interface.execute(query: "COMMIT;")
			return !tableHasContent
		} catch SQLiteErrorCode.busy, SQLiteErrorCode.locked {
			return true
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

		CREATE TABLE IF NOT EXISTS matchups (
			key TEXT PRIMARY KEY,
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

	mutating func withListNamesStmt<T>(_ body: (borrowing SQLitePreparedStatement) throws -> T) throws -> T {
		try self.prepareTablesIfNeeded()

		if self.listNamesStmt == nil {
			self.listNamesStmt = try SQLitePreparedStatement(db: self.interface.db,
															 statementStr: "SELECT name FROM attrs;")
		}
		return try body(self.listNamesStmt!)
	}

	mutating func withListNamesWithValueLengthsStmt<T>(_ body: (borrowing SQLitePreparedStatement) throws -> T) throws -> T {
		try self.prepareTablesIfNeeded()

		if self.listNamesWithValueLengthsStmt == nil {
			self.listNamesWithValueLengthsStmt = try SQLitePreparedStatement(db: self.interface.db,
																			 statementStr: "SELECT name, LENGTH(value) FROM attrs;")
		}
		return try body(self.listNamesWithValueLengthsStmt!)
	}

	mutating func withListNamesWithValuesStmt<T>(_ body: (borrowing SQLitePreparedStatement) throws -> T) throws -> T {
		try self.prepareTablesIfNeeded()

		if self.listNamesWithValuesStmt == nil {
			self.listNamesWithValuesStmt = try SQLitePreparedStatement(db: self.interface.db,
																	   statementStr: "SELECT name, value FROM attrs;")
		}
		return try body(self.listNamesWithValuesStmt!)
	}

	mutating func withRemoveAttributeStmt<T>(_ body: (borrowing SQLitePreparedStatement) throws -> T) throws -> T {
		try self.prepareTablesIfNeeded()

		if self.removeAttributeStmt == nil {
			self.removeAttributeStmt = try SQLitePreparedStatement(db: self.interface.db,
																   statementStr: "DELETE FROM attrs WHERE name = ?;")
		}
		return try body(self.removeAttributeStmt!)
	}

	mutating func withClearAllAttributesStmt<T>(_ body: (borrowing SQLitePreparedStatement) throws -> T) throws -> T {
		try self.prepareTablesIfNeeded()

		if self.clearAllAttributesStmt == nil {
			self.clearAllAttributesStmt = try SQLitePreparedStatement(db: self.interface.db,
																	  statementStr: "DELETE FROM attrs;")
		}
		return try body(self.clearAllAttributesStmt!)
	}

	mutating func withGetMatchupStmt<T>(_ body: (borrowing SQLitePreparedStatement) throws -> T) throws -> T {
		try self.prepareTablesIfNeeded()

		if self.getMatchupStmt == nil {
			self.getMatchupStmt = try SQLitePreparedStatement(db: self.interface.db,
															  statementStr: "SELECT value FROM matchups WHERE key = ?;")
		}
		return try body(self.getMatchupStmt!)
	}

	mutating func withSetMatchupStmt<T>(_ body: (borrowing SQLitePreparedStatement) throws -> T) throws -> T {
		try self.prepareTablesIfNeeded()

		if self.setMatchupStmt == nil {
			self.setMatchupStmt = try SQLitePreparedStatement(db: self.interface.db,
															  statementStr: """
															  INSERT INTO matchups (key, value)
															  VALUES (?, ?)
															  ON CONFLICT(key) DO UPDATE SET
															  value = excluded.value
															  WHERE matchups.value IS NOT excluded.value;
															  """)
		}
		return try body(self.setMatchupStmt!)
	}
}

extension SQLWrapper {
	mutating func getAttribute(name: String) throws -> Data? {
		try self.withGetAttributeStmt { stmt in
			try stmt.reset()
			try stmt.bindText(name, at: 1)
			if try stmt.step() == .row {
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
			assert(res == .done, "Expected step to return .done after executing an INSERT statement, but got \(res)")
		}
	}

	mutating func listAttributeNames() throws -> Set<String> {
		try self.withListNamesStmt { stmt in
			try stmt.reset()
			var names = Set<String>()
			while try stmt.step() == .row {
				names.insert(try stmt.columnText(at: 0))
			}
			return names
		}
	}

	mutating func listAttributeNamesWithValueLengths() throws -> Set<DXAttrMetadata> {
		try self.withListNamesWithValueLengthsStmt { stmt in
			try stmt.reset()
			var out = Set<DXAttrMetadata>()
			while try stmt.step() == .row {
				out.insert(DXAttrMetadata(name: try stmt.columnText(at: 0),
										  valueLength: try stmt.columnInt(at: 1)))
			}
			return out
		}
	}

	mutating func listAttributeNamesWithValues() throws -> [String: Data] {
		try self.withListNamesWithValuesStmt { stmt in
			try stmt.reset()
			var out = [String: Data]()
			while try stmt.step() == .row {
				out[try stmt.columnText(at: 0)] = try stmt.columnBlob(at: 1)
			}
			return out
		}
	}

	mutating func removeAttribute(name: String) throws {
		try self.withRemoveAttributeStmt { stmt in
			try stmt.reset()
			try stmt.bindText(name, at: 1)
			let res = try stmt.step()
			assert(res == .done, "Expected step to return .done after executing a DELETE statement, but got \(res)")
		}
	}

	mutating func clearAllAttributes() throws {
		try self.withClearAllAttributesStmt { stmt in
			try stmt.reset()
			let res = try stmt.step()
			assert(res == .done, "Expected step to return .done after executing a DELETE statement, but got \(res)")
		}
	}
}

extension SQLWrapper {
	enum MatchupKey: String {
		case matchupID
	}

	mutating func getMatchup(key: MatchupKey) throws -> Data? {
		try self.withGetMatchupStmt { stmt in
			try stmt.reset()
			try stmt.bindText(key.rawValue, at: 1)
			if try stmt.step() == .row {
				return try stmt.columnBlob(at: 0)
			} else {
				return nil
			}
		}
	}

	mutating func setMatchup(key: MatchupKey, value: some IntoData) throws {
		try self.withSetMatchupStmt { stmt in
			try stmt.reset()
			try stmt.bindText(key.rawValue, at: 1)
			try stmt.bindBlob(value, at: 2)
			let res = try stmt.step()
			assert(res == .done, "Expected step to return .done after executing an INSERT statement, but got \(res)")
		}
	}
}
