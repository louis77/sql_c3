module sqlite;

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

fn SqliteDriver* new_driver() {
    // There is nothing to do
    SqliteDriver* db = mem::new(SqliteDriver);
    return db;
}

// Driver

fn void free_driver(Driver db) {
    free((SqliteDriver*)db);
}

fn sql::Connection! SqliteDriver.open(SqliteDriver* self, String connection_string) @dynamic
{
    SqliteHandle handle;
    ZString connstr = connection_string.zstr_copy();
    defer mem::free(connstr);

    CInt ret = sqlite3_open(connstr, &handle);
    if (ret != SQLITE_OK) {
        return sql::Error.CONNECTION_FAILURE?;
    }

    SqliteConnection* conn = mem::new(SqliteConnection);
    conn.conn = handle;
    conn.connection_string = connection_string;

    return conn;
}

fn void SqliteDriver.close(SqliteDriver* self, sql::Connection conn) @dynamic
{
    SqliteConnection* c = (SqliteConnection*)conn;
    sqlite3_close(c.conn);
    free(c);
}

fn void! SqliteDriver.ping(SqliteDriver* self, sql::Connection conn) @dynamic
{
    // sqlite is file-based, there is nothing to ping.
    // when the connection is created, we assume everything is ok.
    return;
}

// Connection

fn void! bind_parameters(SqliteConnection* self, SqliteStmt stmt, args...) @private
{
    CInt ret;
    foreach (idx, val : args) {
        if (val == null) {
            ret = sqlite::sqlite3_bind_null(stmt, (CInt)idx+1);
        } else {
            usz bytes_printed;
            DString out = dstring::new(allocator:allocator::temp());
            bytes_printed = out.appendf("%s", val)!;

            ret = sqlite::sqlite3_bind_text(stmt, (CInt)idx+1, out.zstr_view(), (int)out.len(), null);
        }

        if (ret != SQLITE_OK) {
            self._last_error =  sqlite3_errmsg(self.conn);
            return sql::Error.COMMAND_FAILED?;
        }
    }
}

fn sql::Result! SqliteConnection.query(SqliteConnection* self, String command, args...) @dynamic
{
    // TODO: https://www.sqlite.org/c3ref/bind_blob.html
    SqliteStmt stmt;
    CInt ret;

    ZString cmd = command.zstr_copy();
    defer free(cmd);
    ret = sqlite3_prepare_v2(self.conn, cmd, -1, &stmt, null);
    if (ret != SQLITE_OK) {
        self._last_error =  sqlite3_errmsg(self.conn);
        return sql::Error.COMMAND_FAILED?;
    }

    bind_parameters(self, stmt, ...args)!;

    SqliteResult* res = mem::new(SqliteResult);
    res.stmt = stmt;

    CInt column_count = sqlite3_column_count(stmt);
    res.column_count = (usz)column_count;
    return res;
}

fn usz! SqliteConnection.exec(SqliteConnection* self, String command, args...) @dynamic
{
    ZString cmd = command.zstr_copy();
    defer free(cmd);
    SqliteStmt stmt;
    CInt ret = sqlite3_prepare_v2(self.conn, cmd, -1, &stmt, null);
    if (ret != SQLITE_OK) {
        self._last_error =  sqlite3_errmsg(self.conn);
        return sql::Error.COMMAND_FAILED?;
    }

    bind_parameters(self, stmt, ...args)!;

    ret = sqlite3_step(stmt);
    if (ret != SQLITE_DONE) {
        self._last_error =  sqlite3_errmsg(self.conn);
        return sql::Error.COMMAND_FAILED?;
    }

    CLong affected_rows = sqlite3_changes64(self.conn);
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

    CInt ret = sqlite3_exec(self.conn, "BEGIN", null, null, &self._last_error);
    if (ret != SQLITE_OK) {
        self._last_error =  sqlite3_errmsg(self.conn);
        return sql::Error.COMMAND_FAILED?;
    }
    self._tx_in_progress = true;
}

fn void! SqliteConnection.tx_commit(SqliteConnection* self) @dynamic
{
    CInt ret = sqlite3_exec(self.conn, "COMMIT", null, null, &self._last_error);
    if (ret != SQLITE_OK) {
        self._last_error =  sqlite3_errmsg(self.conn);
        return sql::Error.COMMAND_FAILED?;
    }
    self._tx_in_progress = false;
}

fn void! SqliteConnection.tx_rollback(SqliteConnection* self) @dynamic
{
    CInt ret = sqlite3_exec(self.conn, "ROLLBACK", null, null, &self._last_error);
    if (ret != SQLITE_OK) {
        self._last_error =  sqlite3_errmsg(self.conn);
        return sql::Error.COMMAND_FAILED?;
    }
    self._tx_in_progress = false;
}

fn bool SqliteConnection.tx_in_progress(SqliteConnection* self) @dynamic
{
    return self._tx_in_progress;
}

// Result

fn bool SqliteResult.next(SqliteResult* self) @dynamic
{
    CInt ret = sqlite3_step(self.stmt);
    if (ret == SQLITE_DONE) return false;

    if (ret != SQLITE_ROW) return false; // TODO This is an error!
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

fn void! SqliteResult.scan(SqliteResult* self, int fieldnum, any dest) @dynamic
{
    if (fieldnum+1 > self.column_count) {
        return sql::Error.ILLEGAL_COLUMN_ACCESS?;
    }

    CInt column_type = sqlite3_column_type(self.stmt, fieldnum);
    ZString tmp_value = sqlite3_column_text(self.stmt, fieldnum);

    bool was_null = (column_type == SQLITE_NULL);
    if (was_null) {
        tmp_value = "";
    }

    DString builder = dstring::new("", allocator::temp());
    builder.append(tmp_value.str_view());
    sql::@convert_builder_value(builder, dest, was_null)!;

    return;
}

fn void SqliteResult.close(SqliteResult* self) @dynamic
{
    sqlite3_finalize(self.stmt);
    mem::free(self);
    return;
}