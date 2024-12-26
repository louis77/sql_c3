module mysql8;

import std::io;
import url;
import sql;

struct MysqlDriver (sql::Driver) {
    int _x;
}

struct MysqlResult (sql::Result) {
    MysqlRes result;
    int current_row_num;  // TODO: Match with maximum size of rows returned by driver
    CUInt num_fields;
    MysqlRow current_row;
}

struct MysqlConnection (sql::Connection) {
    Mysql  conn;
    String connection_string;
    String _last_error;
}

fn MysqlDriver* new_driver() {
    mysql_library_init(0, null, null); // TODO should we check for the return value?
    
    MysqlDriver* db = mem::new(MysqlDriver);
    return db;
}

// Driver

fn void free_driver(Driver db) {
    mysql_library_end();
    free((MysqlDriver*)db);
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

    Mysql mysql = mysql_init(null);
    Mysql mysql2 = mysql_real_connect(mysql, host, user, pass, name, db_url.port, null, 0);
    if (mysql2 == null) {
        return sql::Error.CONNECTION_FAILURE?;
    }

    MysqlConnection* conn = mem::new(MysqlConnection);
    conn.conn = mysql2;
    conn.connection_string = connection_string;

    return conn;
}

fn void MysqlDriver.close(MysqlDriver* self, sql::Connection conn) @dynamic
{
    MysqlConnection* c = (MysqlConnection*)conn;
    mysql_close(c.conn);
}

fn void! MysqlDriver.ping(MysqlDriver* self, sql::Connection conn) @dynamic
{
    MysqlConnection* c = (MysqlConnection*)conn;
    if (mysql_ping(c.conn) != 0) {
        return sql::Error.CONNECTION_FAILURE?;
    }     
    return;
}

// Connection

fn sql::Result! MysqlConnection.query(MysqlConnection* self, String command) @dynamic
{
    CInt success = mysql_real_query(self.conn, (ZString)command, command.len);

    if (success != 0) {
        self._last_error = mysql_error(self.conn).str_view();

        return sql::Error.COMMAND_FAILED?;
    }

    MysqlRes res = mysql_use_result(self.conn);
    MysqlResult* result = mem::alloc(MysqlResult);
    result.current_row_num = -1;
    result.result = res;
    result.num_fields = mysql_num_fields(res);

    return result;
}

fn usz! MysqlConnection.exec(MysqlConnection* self, String command) @dynamic
{
    CInt success = mysql_real_query(self.conn, (ZString)command, command.len);

    if (success != 0) {
        return sql::Error.COMMAND_FAILED?;
    }

    CULong affected_rows = mysql_affected_rows(self.conn);
    if (affected_rows == (ulong)-1) return 0;
    // TODO Should probably throw an error;

    return (usz)affected_rows;
}

fn String MysqlConnection.last_error(MysqlConnection* self) @dynamic
{
    return self._last_error;
}

// Result

fn bool MysqlResult.next(MysqlResult* self) @dynamic
{
    self.current_row_num++;
    MysqlRow row = mysql_fetch_row(self.result);
    if (row == null) {
        return false;
        // TODO we must check for an error here
    }

    self.current_row = row;
    return true;
}

macro @set_null_value(dest, #value, was_null) 
{
    if (was_null) { 
        *dest = null; 
    } else { 
        **dest = #value; 
    }
}

fn void! MysqlResult.scan(MysqlResult* self, int fieldnum, any dest) @dynamic
{   
    if (fieldnum+1 > self.num_fields) {
        return sql::Error.ILLEGAL_COLUMN_ACCESS?;
    }

    ZString tmp_value = (ZString)self.current_row[fieldnum];
    bool was_null = (tmp_value == null);
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
            io::eprintf("scanning faild for row: %d field: %d\n", self.current_row, fieldnum);
            return sql::Error.UNSUPPORTED_SCAN_TYPE?;
    }

    return;
}

fn void! MysqlResult.close(MysqlResult* self) @dynamic
{
    mysql_free_result(self.result);
    return;
}