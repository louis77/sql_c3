module mysql8 @if($defined(ping));

import std::io;
import std::collections::list;
import std::net::url;
import libc;
import sql;

struct MysqlDriver (sql::Driver) {
	int _x;
}

struct MysqlResult (sql::Result) {
	CUInt       num_fields;
	MysqlStmt   stmt;
}

struct MysqlConnection (sql::Connection) {
	Mysql  conn;
	String connection_string;
	String _last_error;
	bool   autocommit;
}

// Driver

<*
	@return! sql::Error.NOT_IMPLEMENTED
*>
fn void MysqlDriver.free(MysqlDriver* self) @dynamic {
	library_end();
	free((MysqlDriver*)self);
}

fn void register_driver() @init @private {
	library_init(0, null, null); // TODO should we check for the return value?
	MysqlDriver* db = mem::new(MysqlDriver);
	sql::register_driver("mysql", db);
}

fn sql::Connection! MysqlDriver.open(MysqlDriver* self, String connection_string) @dynamic
{
	Url db_url = url::parse(connection_string)!;
	if (db_url.port == 0) db_url.port = 3306;

	ZString host = db_url.host.zstr_copy();
	ZString user = db_url.username.zstr_copy();
	ZString pass = db_url.password.zstr_copy();
	ZString name = db_url.path[1 .. ].zstr_copy();
	defer {
		mem::free(host);
		mem::free(user);
		mem::free(pass);
		mem::free(name);
	}

	Mysql mysql = init(null);
	Mysql mysql2 = real_connect(mysql, host, user, pass, name, db_url.port, null, 0);
	if (mysql2 == null) {
		return sql::Error.CONNECTION_FAILURE?;
	}

	MysqlConnection* conn = mem::new(MysqlConnection);
	conn.conn = mysql2;
	conn.connection_string = connection_string;
	conn.autocommit = true; // MySQL default for new connections;

	return conn;
}

// Connection

fn void! MysqlConnection.ping(MysqlConnection* self) @dynamic
{
	if (ping(self.conn) != 0) {
		return sql::Error.CONNECTION_FAILURE?;
	}
	return;
}

fn void MysqlConnection.close(MysqlConnection* self) @dynamic
{
	close(self.conn);
	free(self);
}

fn void! bind_parameters(MysqlStmt stmt, args...) @private
{
	MysqlBind* binds = calloc(MysqlBind.sizeof * args.len);
	defer free(binds);
	MysqlBind bind;

	foreach (idx, val : args) {
		bind.buffer_type = TYPE_VARCHAR;
		usz bytes_printed;
		DString out = dstring::new(allocator:allocator::temp());
		bytes_printed = out.appendf("%s", val)!;
		bind.buffer_length = bytes_printed;
		bind.buffer = out.str_view();
		binds[idx] = bind;
	}

	CInt ret = (int)stmt_bind_param(stmt, binds);
	if (ret != 0) {
		io::eprintfn("Binding params failed with code: %d", ret);
		return sql::Error.UNSUPPORTED_BIND_TYPE?;
	}
}

fn sql::Result! MysqlConnection.query(MysqlConnection* self, String command, args...) @dynamic
{
	// If args[] is len > 0 then we _must_ use prepared statements, otherwise we could just use real_query...
	MysqlStmt stmt = stmt_init(self.conn);
	if (stmt == null) {
		return sql::Error.PREPARE_FAILED?;
	}

	ZString zcommand = command.zstr_copy();
	defer free(zcommand);
	CInt ret = stmt_prepare(stmt, zcommand, command.len);
	if (ret != 0) {
		self._last_error = error(self.conn).str_view();
		return sql::Error.PREPARE_FAILED?;
	}

	bind_parameters(stmt, ...args)!;

	ret = stmt_execute(stmt);
	if (ret != 0) {
		self._last_error = error(self.conn).str_view();
		return sql::Error.COMMAND_FAILED?;
	}

	MysqlResult* result = mem::new(MysqlResult);
	result.stmt = stmt;
	result.num_fields = stmt_field_count(stmt);

	// Bind to empty buffer. This is stupidly necessary to tell MySQL that we will
	// later fetch columns individually via fetch_column()

	MysqlBind* empty_bind = calloc(MysqlBind.sizeof * result.num_fields);
	defer free(empty_bind);

	bool bind_ret = stmt_bind_result(stmt, empty_bind);
	if ((int)bind_ret != 0) {
		return sql::Error.PARAM_BINDING_FAILED?;
	}

	return result;
}

fn usz! MysqlConnection.exec(MysqlConnection* self, String command, args...) @dynamic
{
   // If args[] is len > 0 then we _must_ use prepared statements, otherwise we could just use real_query...
	MysqlStmt stmt = stmt_init(self.conn);
	if (stmt == null) {
		return sql::Error.PREPARE_FAILED?;
	}

	ZString zcommand = command.zstr_copy();
	defer free(zcommand);
	CInt ret = stmt_prepare(stmt, zcommand, command.len);
	if (ret != 0) {
		self._last_error = error(self.conn).str_view();
		return sql::Error.PREPARE_FAILED?;
	}

	bind_parameters(stmt, ...args)!;

	ret = stmt_execute(stmt);
	if (ret != 0) {
		self._last_error = error(self.conn).str_view();
		return sql::Error.COMMAND_FAILED?;
	}

	CULong rows = affected_rows(self.conn);
	if (rows == (ulong)-1) return 0;
	// TODO Should probably throw an error;

	return (usz)rows;
}

fn String MysqlConnection.last_error(MysqlConnection* self) @dynamic
{
	return self._last_error;
}

fn void! MysqlConnection.tx_begin(MysqlConnection* self) @dynamic
{
	if (!self.autocommit) {
		return sql::Error.TX_ALREADY_IN_PROGRESS?;
	}
	bool ret = autocommit(self.conn, Autocommit.AUTOCOMMIT_OFF);
	if (ret != (bool)0) {
		return sql::Error.COMMAND_FAILED?;
	}
	self.autocommit = false;
}

fn void! MysqlConnection.tx_commit(MysqlConnection* self) @dynamic
{
	defer {
		autocommit(self.conn, Autocommit.AUTOCOMMIT_ON);
		self.autocommit = true;
	}
	bool ret = commit(self.conn);
	if (ret != (bool)0) {
		return sql::Error.COMMAND_FAILED?;
	}
}

fn void! MysqlConnection.tx_rollback(MysqlConnection* self) @dynamic
{
	defer {
		autocommit(self.conn, Autocommit.AUTOCOMMIT_ON);
		self.autocommit = true;
	}
	bool ret = rollback(self.conn);
	if (ret != (bool)0) {
		return sql::Error.COMMAND_FAILED?;
	}
}

<*
	@pure
	@return! sql::Error.NOT_IMPLEMENTED
*>
fn bool MysqlConnection.tx_in_progress(MysqlConnection* self) @dynamic
{
	return !self.autocommit;
}


// Result

fn usz MysqlResult.num_columns(MysqlResult* self) @dynamic
{
	return self.num_fields;
}

fn bool MysqlResult.next(MysqlResult* self) @dynamic
{
	CInt status = stmt_fetch(self.stmt);
	if (status == 1 || status == MYSQL_NO_DATA) return false;

	return true;
}

fn void! MysqlResult.scan_field(MysqlResult* self, usz fieldnum, any dest) @dynamic
{
	if (fieldnum+1 > self.num_fields) {
		return sql::Error.ILLEGAL_COLUMN_ACCESS?;
	}

	DString builder = dstring::new(allocator:allocator::temp());

	usz chunk = 0;
	usz ret_size = 0;
	CULong buffer_size = 1024;
	CULong offset = 0;
	bool is_null;
	ZString buffer = (ZString)calloc(char.sizeof * buffer_size);
	defer free(buffer);

	MysqlBind* bind = calloc(MysqlBind.sizeof);
	defer free(bind);
	bind.buffer_type = TYPE_VARCHAR;
	bind.buffer = buffer;
	bind.buffer_length = buffer_size;
	bind.is_null = &is_null;

	do {
		chunk++;

		CInt status = stmt_fetch_column(self.stmt, bind, (CUInt)fieldnum, offset);
		if (status != 0) return sql::Error.UNKNOWN_ERROR?;

		ret_size = libc::strlen(buffer);

		if (ret_size > 0) {
			offset += ret_size;
			builder.write(buffer[..ret_size-1])!;
		}

	} while(ret_size > 0 && ret_size == buffer_size);

	sql::@convert_builder_value(builder, dest, is_null)!;

	return;
}


fn void! MysqlResult.scan(MysqlResult* self, dests...) @dynamic
{
	for (usz fieldnum = 0; fieldnum < dests.len; fieldnum++)
	{
		self.scan_field(fieldnum, dests[fieldnum])!;
	}

	return;
}


fn void MysqlResult.close(MysqlResult* self) @dynamic
{
	stmt_free_result(self.stmt);
	free(self);
	return;
}
