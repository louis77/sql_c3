module pg;

import std::io;
import sql;

struct Postgres (sql::Driver) {
    int _x;
}

struct PostgresResult (sql::Result) {
    PGresult result;
    int current_row;  // TODO: Match with maximum size of rows returned by driver
    usz row_count;
}

struct PostgresConnection (sql::Connection) {
    void* conn;
    String connection_string;
    String _last_error;
}


fn Postgres* new_driver() {
    Postgres* pg = mem::new(Postgres);
    return pg;
}

// Driver

fn void free_driver(Driver pg) {
    // TODO: Call Postgres destructor
    free((Postgres*)pg);
}

fn sql::Connection! Postgres.open(Postgres* self, String connection_string) @dynamic
{
    PGconn conn = pq_connectdb((ZString)connection_string);
    PostgresConnection* c = mem::new(PostgresConnection);
    c.conn = conn;
    c.connection_string = connection_string.copy();
    return (sql::Connection) c;   
}

fn void Postgres.close(Postgres* self, sql::Connection conn) @dynamic
{
    PostgresConnection* c = (PostgresConnection*)conn;
    pq_finish(c.conn);
}

fn void! Postgres.ping(Postgres* self, sql::Connection conn) @dynamic
{	
    PostgresConnection* c = (PostgresConnection*)conn;
    PGconn tmp_conn = pq_connectdb((ZString)c.connection_string);
    ConnStatusType dbstatus = pq_status(tmp_conn);
    if (dbstatus != CONNECTION_OK)
    {
        return sql::Error.CONNECTION_FAILURE?;
    }
}

// Connection

fn sql::Result! PostgresConnection.query(PostgresConnection* self, String command) @dynamic
{
    PostgresResult* res = mem::new(PostgresResult);
    PGresult result = pq_exec(self.conn, (ZString)command);

    if (pq_result_status(result) != PGRES_TUPLES_OK) {
        self._last_error = pq_result_error_message(result).str_view();
        return sql::Error.COMMAND_FAILED?;
    }

    res.row_count = pq_ntuples(result);
    res.current_row = -1;
    res.result = result;

    return (sql::Result) res;
}

fn usz! PostgresConnection.exec(PostgresConnection* self, String command) @dynamic
{
    PostgresResult* res = mem::new(PostgresResult);
    PGresult result = pq_exec(self.conn, (ZString)command);

    if (pq_result_status(result) != PGRES_COMMAND_OK) {
        return sql::Error.COMMAND_FAILED?;
    }

    ZString affected_rows_str = pq_cmd_tuples(result);
    usz! affected_rows = (usz)affected_rows_str.str_view().to_ulong();
    if (catch excuse = affected_rows) {
        if (excuse == NumberConversion.EMPTY_STRING) return 0;
    }

    return affected_rows;
}

fn String PostgresConnection.last_error(PostgresConnection* self) @dynamic
{
    return self._last_error;
}

// Result

fn bool PostgresResult.next(PostgresResult* self) @dynamic 
{
    self.current_row++;
    if (self.current_row > (self.row_count-1)) {
        return false;
    }
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

fn void! PostgresResult.scan(PostgresResult* self, int fieldnum, any dest) @dynamic
{
    ZString tmp_value = pq_getvalue(self.result, self.current_row, fieldnum);
    bool was_null = pq_getisnull(self.result, self.current_row, fieldnum);
    if (was_null) {
        tmp_value = "";
    }

    // Sadly our driver currently always returns values as string
    // In the future, we'll use binary data and avoid conversions from string
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
            *dest = tmp_value.str_view() == "t" ? true : false;
        case bool*:
            @set_null_value(dest, (tmp_value.str_view() == "t") ? true : false, was_null);
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

fn void! PostgresResult.close(PostgresResult* self) @dynamic
{
    pq_clear(self.result);
    mem::free(self);
    return;
}