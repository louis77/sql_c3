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

fn MysqlDriver* new_mysql() {
    mysql_library_init(0, null, null); // TODO should we check for the return value?
    
    MysqlDriver* db = mem::new(MysqlDriver);
    return db;
}

// Driver

fn void free_mysql(Driver db) {
    mysql_library_end();
    free((MysqlDriver*)db);
}

fn sql::Connection! MysqlDriver.open(MysqlDriver* self, String connection_string) @dynamic
{
    Url db_url = url::parse(connection_string)!;
    if (db_url.port == 0) db_url.port = 3306;

    Mysql mysql = mysql_init(null);
    Mysql mysql2 = mysql_real_connect(mysql, db_url.host.zstr_copy(), db_url.username.zstr_copy(), db_url.password.zstr_copy(), db_url.path[1 .. ].zstr_copy(), db_url.port, null, 0);
    
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

fn void! MysqlDriver.ping(MysqlDriver* self, String connection_string) @dynamic
{
    Url db_url = url::parse(connection_string)!;
    if (db_url.port == 0) db_url.port = 3306;

    Mysql mysql = mysql_init(null);
    Mysql mysql2 = mysql_real_connect(mysql, db_url.host.zstr_copy(), db_url.username.zstr_copy(), db_url.password.zstr_copy(), db_url.path[1 .. ].zstr_copy(), db_url.port, null, 0);
    
    if (mysql2 == null) {
        return sql::Error.CONNECTION_FAILURE?;
    }

    if (mysql_ping(mysql) != 0) {
        return sql::Error.CONNECTION_FAILURE?;
    }     
    return;
}

// Connection

fn sql::Result! MysqlConnection.query(MysqlConnection* self, String command) @dynamic
{
    CInt success = mysql_real_query(self.conn, (ZString)command, command.len);

    if (success != 0) {
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
    return sql::Error.NOT_IMPLEMENTED?;
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

fn void! MysqlResult.scan(MysqlResult* self, int fieldnum, any dest) @dynamic
{   
    if (fieldnum+1 > self.num_fields) {
        return sql::Error.ILLEGAL_COLUMN_ACCESS?;
    }

    ZString tmp_value = (ZString)self.current_row[fieldnum];
    if (tmp_value == null) {
        tmp_value = "";
        return;
    }

    switch (dest) {
        case String:
            *dest = tmp_value.str_view().copy();
        case ZString:
            *dest = tmp_value;
        case bool:
            if (tmp_value.str_view() == "1") { 
                *dest = true; 
            }
            else { 
                *dest = false;
            }
        case int:
            *dest = tmp_value.str_view().to_int()!;
        case int128:
            *dest = tmp_value.str_view().to_int128()!;
        case long:
            *dest = tmp_value.str_view().to_long()!;
        case short:
            *dest = tmp_value.str_view().to_short()!;
        case ichar:
            *dest = tmp_value.str_view().to_ichar()!;
        case uint128:
            *dest = tmp_value.str_view().to_uint128()!;
        case ulong:
            *dest = tmp_value.str_view().to_ulong()!;
        case uint:
            *dest = tmp_value.str_view().to_uint()!;
        case ushort:
            *dest = tmp_value.str_view().to_ushort()!;
        case char:
            *dest = tmp_value.str_view().to_uchar()!;
        case double:
            *dest = tmp_value.str_view().to_double()!;
        case float:
            *dest = tmp_value.str_view().to_float()!;
        default:
            io::eprintf("scanning faild for row: %d field: %d\n", self.current_row, fieldnum);
            return sql::Error.UNSUPPORTED_SCAN_TYPE?;
    }

    return;
}

fn void! MysqlResult.close(MysqlResult* self) @dynamic
{
    mem::free(self);
    return;
}