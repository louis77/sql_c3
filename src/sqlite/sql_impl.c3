module sqlite3 @if($defined(open));

import std::io;
import sql;

struct SqliteDriver (sql::Driver) {
	int _x;
}

struct SqliteResult (sql::Result) {
	SqliteStmt stmt;
	usz column_count;
}

struct SqliteConnection (sql::Connection) {
	SqliteHandle    conn;
	String          connection_string;
	ZString         _last_error;
	bool            _tx_in_progress;
}

// Driver

fn void SqliteDriver.free(SqliteDriver* self) @dynamic {
	free((SqliteDriver*)self);
}

fn void register_driver() @init @private {
	SqliteDriver* db = mem::new(SqliteDriver);
	sql::register_driver("sqlite", db);
}

fn sql::Connection! SqliteDriver.open(SqliteDriver* self, String connection_string) @dynamic
{
	SqliteHandle handle;
	ZString connstr = connection_string.zstr_copy();
	defer mem::free(connstr);

	ResultStatus ret = open(connstr, &handle);
	if (ret != OK) {
		return sql::Error.CONNECTION_FAILURE?;
	}

	SqliteConnection* conn = mem::new(SqliteConnection);
	conn.conn = handle;
	conn.connection_string = connection_string;

	return conn;
}

// Connection

fn void! SqliteConnection.ping(SqliteConnection* self) @dynamic
{
	// sqlite is file-based, there is nothing to ping.
	// when the connection is created, we assume everything is ok.
	return;
}

fn void SqliteConnection.close(SqliteConnection* self) @dynamic
{
	close(self.conn);
	free(self);
}

fn void! bind_parameters(SqliteConnection* self, SqliteStmt stmt, args...) @private
{
	ResultStatus ret;
	foreach (idx, val : args) {
		if (val == null) {
			ret = bind_null(stmt, (CInt)idx+1);
		} else {
			usz bytes_printed;
			DString out = dstring::new(allocator:allocator::temp());
			bytes_printed = out.appendf("%s", val)!;

			ret = bind_text(stmt, (CInt)idx+1, out.zstr_view(), (int)out.len(), null);
		}

		if (ret != OK) {
			self._last_error =  errmsg(self.conn);
			return sql::Error.COMMAND_FAILED?;
		}
	}
}

fn sql::Result! SqliteConnection.query(SqliteConnection* self, String command, args...) @dynamic
{
	// TODO: https://www.sqlite.org/c3ref/bind_blob.html
	SqliteStmt stmt;
	ResultStatus ret;

	ZString cmd = command.zstr_copy();
	defer free(cmd);
	ret = prepare_v2(self.conn, cmd, -1, &stmt, null);
	if (ret != OK) {
		self._last_error =  errmsg(self.conn);
		return sql::Error.COMMAND_FAILED?;
	}

	bind_parameters(self, stmt, ...args)!;

	SqliteResult* res = mem::new(SqliteResult);
	res.stmt = stmt;

	res.column_count = (usz)column_count(stmt);
	return res;
}

fn usz! SqliteConnection.exec(SqliteConnection* self, String command, args...) @dynamic
{
	ZString cmd = command.zstr_copy();
	defer free(cmd);
	SqliteStmt stmt;
	ResultStatus ret = prepare_v2(self.conn, cmd, -1, &stmt, null);
	if (ret != OK) {
		self._last_error =  errmsg(self.conn);
		return sql::Error.COMMAND_FAILED?;
	}

	bind_parameters(self, stmt, ...args)!;

	ret = step(stmt);
	if (ret != DONE) {
		self._last_error =  errmsg(self.conn);
		return sql::Error.COMMAND_FAILED?;
	}

	CLong affected_rows = changes64(self.conn);
	return (usz)affected_rows;
}

fn String SqliteConnection.last_error(SqliteConnection* self) @dynamic
{
	return self._last_error.str_view();
}

fn void! SqliteConnection.tx_begin(SqliteConnection* self) @dynamic
{
	if (self._tx_in_progress) {
		return sql::Error.TX_ALREADY_IN_PROGRESS?;
	}

	ResultStatus ret = exec(self.conn, "BEGIN", null, null, &self._last_error);
	if (ret != OK) {
		self._last_error =  errmsg(self.conn);
		return sql::Error.COMMAND_FAILED?;
	}
	self._tx_in_progress = true;
}

fn void! SqliteConnection.tx_commit(SqliteConnection* self) @dynamic
{
	ResultStatus ret = exec(self.conn, "COMMIT", null, null, &self._last_error);
	if (ret != OK) {
		self._last_error = errmsg(self.conn);
		return sql::Error.COMMAND_FAILED?;
	}
	self._tx_in_progress = false;
}

fn void! SqliteConnection.tx_rollback(SqliteConnection* self) @dynamic
{
	ResultStatus ret = exec(self.conn, "ROLLBACK", null, null, &self._last_error);
	if (ret != OK) {
		self._last_error =  errmsg(self.conn);
		return sql::Error.COMMAND_FAILED?;
	}
	self._tx_in_progress = false;
}

fn bool SqliteConnection.tx_in_progress(SqliteConnection* self) @dynamic
{
	return self._tx_in_progress;
}

// Result

fn usz SqliteResult.num_columns(SqliteResult* self) @dynamic
{
	return 0;
}

fn bool SqliteResult.next(SqliteResult* self) @dynamic
{
	ResultStatus ret = step(self.stmt);
	if (ret == DONE) return false;

	if (ret != ROW) return false; // TODO This is an error!
	return true;
}

macro @set_null_value(dest, #value, was_null) @private
{
	if (was_null) {
		*dest = null;
	} else {
		**dest = #value;
	}
}

fn void! SqliteResult.scan_field(SqliteResult* self, usz fieldnum, any dest) @dynamic
{
	if (fieldnum+1 > self.column_count) {
		return sql::Error.ILLEGAL_COLUMN_ACCESS?;
	}

	ColumnType col_type = column_type(self.stmt, (int)fieldnum);

	bool was_null = (col_type == NULL);

	// Use binary functions first
	// switch (col_type)
	// {
	// 	case INTEGER:
	// 		io::printfn("scanning field %d natively", fieldnum);
	// 		@scan_natively_int(dests[fieldnum], self.stmt, fieldnum, was_null)!;
	// 		continue;
	// 	case NULL:
	// 		if (dests[fieldnum].type.kindof == POINTER)
	// 		{
	// 			dests[fieldnum] = null;
	// 			continue;
	// 		}
	// 		else
	// 		{
	// 			// *(dests[fieldnum]) = 0;
	// 		}
	// 	default:
	// 		io::printfn("scanning field %d via builder", fieldnum);
	// }

	// Then fallback to generic text-to-* converter
	ZString tmp_value = column_text(self.stmt, (int)fieldnum);
	if (was_null) {
		tmp_value = "";
	}
	DString builder = dstring::new("", allocator::temp());
	builder.append(tmp_value.str_view());
	sql::@convert_builder_value(builder, dest, was_null)!;

	return;
}


fn void! SqliteResult.scan(SqliteResult* self, dests...) @dynamic
{
	for (usz fieldnum = 0; fieldnum < dests.len; fieldnum++)
	{
		self.scan_field(fieldnum, dests[fieldnum])!;
	}

	return;
}

fn void SqliteResult.close(SqliteResult* self) @dynamic
{
	finalize(self.stmt);
	mem::free(self);
	return;
}

macro void! @scan_natively_int(dest, stmt, fieldnum, was_null)
{
	CUInt value = column_int(stmt, (int)fieldnum);
	switch (dest) {
		case int:
			*dest = value;
		case int*:
			@set_null_value(dest, value, was_null);
		case bool:
			*dest = (value != 0);
		case bool*:
			@set_null_value(dest, value != 0, was_null);
		default:
			return Error.TYPE_MISMATCH?;
	}
}
