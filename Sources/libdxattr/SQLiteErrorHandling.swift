import CSQLite

func sqlite_res_check(_ result: Int32) throws {
	if result != SQLITE_OK {
		throw SQLiteErrorCode(rawValue: result) ?? SQLiteErrorCode.wrapperUnknownError
	}
}

public enum SQLiteInterfaceError: Error {
	case noSerializationData
}

public enum SQLiteErrorCode: Int32, Error, CustomStringConvertible {
	case error = 1
	case internalError = 2
	case perm = 3
	case abort = 4
	case busy = 5
	case locked = 6
	case noMem = 7
	case readOnly = 8
	case interrupt = 9
	case ioErr = 10
	case corrupt = 11
	case notFound = 12
	case full = 13
	case cantOpen = 14
	case protocolError = 15
	case empty = 16
	case schema = 17
	case tooBig = 18
	case constraint = 19
	case mismatch = 20
	case misuse = 21
	case noLfs = 22
	case auth = 23
	case format = 24
	case range = 25
	case notADb = 26
	case notice = 27
	case warning = 28
	case row = 100
	case done = 101

	case wrapperUnknownError = -1

	public var description: String {
		switch self {
			case .error: return "Generic error"
			case .internalError: return "Internal logic error in SQLite"
			case .perm: return "Access permission denied"
			case .abort: return "Callback routine requested an abort"
			case .busy: return "The database file is locked"
			case .locked: return "A table in the database is locked"
			case .noMem: return "A malloc() failed"
			case .readOnly: return "Attempt to write a readonly database"
			case .interrupt: return "Operation terminated by sqlite3_interrupt()"
			case .ioErr: return "Some kind of disk I/O error occurred"
			case .corrupt: return "The database disk image is malformed"
			case .notFound: return "Unknown opcode in sqlite3_file_control()"
			case .full: return "Insertion failed because database is full"
			case .cantOpen: return "Unable to open the database file"
			case .protocolError: return "Database lock protocol error"
			case .empty: return "Internal use only"
			case .schema: return "The database schema changed"
			case .tooBig: return "String or BLOB exceeds size limit"
			case .constraint: return "Abort due to constraint violation"
			case .mismatch: return "Data type mismatch"
			case .misuse: return "Library used incorrectly"
			case .noLfs: return "Uses OS features not supported on host"
			case .auth: return "Authorization denied"
			case .format: return "Not used"
			case .range: return "2nd parameter to sqlite3_bind out of range"
			case .notADb: return "File opened that is not a database file"
			case .notice: return "Notifications from sqlite3_log()"
			case .warning: return "Warnings from sqlite3_log()"
			case .row: return "sqlite3_step() has another row ready"
			case .done: return "sqlite3_step() has finished executing"
			case .wrapperUnknownError: return "An unknown error occurred in the SQLite wrapper"
		}
	}
}
