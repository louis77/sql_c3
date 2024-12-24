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


fn Postgres* new_postgres() {
    Postgres* pg = mem::new(Postgres);
    return pg;
}

// Driver

fn void free_postgres(Driver pg) {
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

fn void! Postgres.ping(Postgres* self, String connection_string) @dynamic
{	
    PGconn conn = pq_connectdb((ZString)connection_string);
    ConnStatusType dbstatus = pq_status(conn);
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
        if (excuse == NumberConversion.EMPTY_STRING) return 9;
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

fn void! PostgresResult.scan(PostgresResult* self, int fieldnum, any dest) @dynamic
{
    bool is_null = pq_getisnull(self.result, self.current_row, fieldnum);
    if (is_null) {
        // TODO : Handle NULL so user knows about it
        dest = null;
        return;
    }

    ZString tmp_value = pq_getvalue(self.result, self.current_row, fieldnum);

    // Sadly our driver currently always returns values as string
    // In the future, we'll use binary data and avoid conversions from string
    switch (dest) {
        case String:
            *dest = tmp_value.str_view().copy();
        case ZString:
            *dest = tmp_value;
        case bool:
            if (tmp_value == "t") { 
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

fn void! PostgresResult.close(PostgresResult* self) @dynamic
{
    pq_clear(self.result);
    mem::free(self);
    return;
}