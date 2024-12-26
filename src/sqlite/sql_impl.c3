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
    SqliteHandle  conn;
    String connection_string;
    ZString _last_error;
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
}

fn void! SqliteDriver.ping(SqliteDriver* self, sql::Connection conn) @dynamic
{
    // sqlite is file-based, there is nothing to ping. 
    // when the connection is created, we assume everything is ok.
    return;
}

// Connection

fn sql::Result! SqliteConnection.query(SqliteConnection* self, String command, any*... args) @dynamic
{
    ZString cmd = command.zstr_copy();
    defer free(cmd);
    SqliteStmt stmt;
    CInt ret = sqlite3_prepare_v2(self.conn, cmd, -1, &stmt, null);
    if (ret != SQLITE_OK) {
        self._last_error =  sqlite3_errmsg(self.conn);
        return sql::Error.COMMAND_FAILED?;
    }

    SqliteResult* res = mem::new(SqliteResult);
    res.stmt = stmt;

    CInt column_count = sqlite3_column_count(stmt);
    res.column_count = (usz)column_count;
    return res;
}

fn usz! SqliteConnection.exec(SqliteConnection* self, String command, any*... args) @dynamic
{
    ZString cmd = command.zstr_copy();
    defer free(cmd);
    SqliteStmt stmt;
    CInt ret = sqlite3_prepare_v2(self.conn, cmd, -1, &stmt, null);
    if (ret != SQLITE_OK) {
        self._last_error =  sqlite3_errmsg(self.conn);
        return sql::Error.COMMAND_FAILED?;
    }

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

    switch (dest) {
        case String:
            *dest = tmp_value.str_view().copy();
        case String*:
            @set_null_value(dest, tmp_value.str_view().copy(), was_null);
        case ZString:
            *dest = tmp_value;
        case ZString*:
            @set_null_value(dest, tmp_value, was_null);
        case bool:
            *dest = tmp_value.str_view() == "1" ? true : false; 
        case bool*:
            @set_null_value(dest, (tmp_value.str_view() == "1") ? true : false, was_null);
        case int:
            *dest = tmp_value.str_view().to_int()!;
        case int*:
            @set_null_value(dest, tmp_value.str_view().to_int()!, was_null);
        case int128:
            *dest = tmp_value.str_view().to_int128()!;
        case int128*:
            @set_null_value(dest, tmp_value.str_view().to_int128()!, was_null);
        case long:
            *dest = tmp_value.str_view().to_long()!;
        case long*:
            @set_null_value(dest, tmp_value.str_view().to_long()!, was_null);        
        case short:
            *dest = tmp_value.str_view().to_short()!;
        case short*:
            @set_null_value(dest, tmp_value.str_view().to_short()!, was_null);        
        case ichar:
            *dest = tmp_value.str_view().to_ichar()!;
        case ichar*:
            @set_null_value(dest, tmp_value.str_view().to_ichar()!, was_null);        
        case uint128:
            *dest = tmp_value.str_view().to_uint128()!;
        case uint128*:
            @set_null_value(dest, tmp_value.str_view().to_uint128()!, was_null);        
        case ulong:
            *dest = tmp_value.str_view().to_ulong()!;
        case ulong*:
            @set_null_value(dest, tmp_value.str_view().to_ulong()!, was_null);        
        case uint:
            *dest = tmp_value.str_view().to_uint()!;
        case uint*:
            @set_null_value(dest, tmp_value.str_view().to_uint()!, was_null);        
        case ushort:
            *dest = tmp_value.str_view().to_ushort()!;
        case ushort*:
            @set_null_value(dest, tmp_value.str_view().to_ushort()!, was_null);        
        case char:
            *dest = tmp_value.str_view().to_uchar()!;
        case char*:
            @set_null_value(dest, tmp_value.str_view().to_uchar()!, was_null);        
        case double:
            *dest = tmp_value.str_view().to_double()!;
        case double*:
            @set_null_value(dest, tmp_value.str_view().to_double()!, was_null);        
        case float:
            *dest = tmp_value.str_view().to_float()!;
        case float*:
            @set_null_value(dest, tmp_value.str_view().to_float()!, was_null);        
        default:
            return sql::Error.UNSUPPORTED_SCAN_TYPE?;
    }

    return;
}

fn void! SqliteResult.close(SqliteResult* self) @dynamic
{
    sqlite3_finalize(self.stmt);
    return;
}