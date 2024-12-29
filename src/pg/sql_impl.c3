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
    bool   _tx_in_progress;
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
    c._tx_in_progress = false;
    return (sql::Connection) c;
}

fn void Postgres.close(Postgres* self, sql::Connection conn) @dynamic
{
    PostgresConnection* c = (PostgresConnection*)conn;
    pq_finish(c.conn);
    free(c.connection_string);
    free(c);
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

fn PGresult! bind_parameters_and_exec(PostgresConnection* self, String command, args...) @private
{
    CInt[]  paramTypes = mem::new_array(CInt, args.len);
    ZString[]  paramValues = mem::new_array(ZString, args.len);
    CInt[]     paramLengths = mem::new_array(CInt, args.len);
    CInt[]     paramFormats = mem::new_array(CInt, args.len);
    defer free(paramTypes);
    defer free(paramValues);
    defer free(paramLengths);
    defer free(paramFormats);

    foreach (idx, val : args) {
        usz bytes_printed;
        DString out = dstring::new(allocator:allocator::temp());
        bytes_printed = out.appendf("%s", val)!;

        paramTypes[idx] = pg::Oid.CSTRINGOID.oid;
        paramValues[idx] = out.zstr_view();
        paramLengths[idx] = (int)out.len();
        paramFormats[idx] = 0;
    }

    PGresult res = pq_exec_params(self.conn, (ZString)command, args.len,
        paramTypes, paramValues, paramLengths, paramFormats, 0); // 0 = TEXT

    pg::ExecStatusType status = pq_result_status(res);
    if ((status != PGRES_TUPLES_OK) && (status != PGRES_COMMAND_OK)) {
        self._last_error = pq_result_error_message(res).str_view();
        return sql::Error.COMMAND_FAILED?;
    }

    return res;
}


fn sql::Result! PostgresConnection.query(PostgresConnection* self, String command, args...) @dynamic
{
    PGresult result = bind_parameters_and_exec(self, command, ...args)!;

    PostgresResult* res = mem::new(PostgresResult);
    res.row_count = pq_ntuples(result);
    res.current_row = -1;
    res.result = result;

    return (sql::Result) res;
}

fn usz! PostgresConnection.exec(PostgresConnection* self, String command, args...) @dynamic
{
    PGresult result = bind_parameters_and_exec(self, command, ...args)!;

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

fn void! PostgresConnection.tx_begin(PostgresConnection* self) @dynamic
{
    if (self._tx_in_progress) {
        return sql::Error.TX_ALREADY_IN_PROGRESS?;
    }

    PGresult res = pq_exec(self.conn, "BEGIN");

    pg::ExecStatusType status = pq_result_status(res);
    if (status != PGRES_COMMAND_OK) {
        self._last_error = pq_result_error_message(res).str_view();
        return sql::Error.COMMAND_FAILED?;
    }

    self._tx_in_progress = true;
}

fn void! PostgresConnection.tx_commit(PostgresConnection* self) @dynamic
{
    PGresult res = pq_exec(self.conn, "COMMIT");

    pg::ExecStatusType status = pq_result_status(res);
    if (status != PGRES_COMMAND_OK) {
        self._last_error = pq_result_error_message(res).str_view();
        return sql::Error.COMMAND_FAILED?;
    }

    self._tx_in_progress = false;
}

fn void! PostgresConnection.tx_rollback(PostgresConnection* self) @dynamic
{
    PGresult res = pq_exec(self.conn, "ROLLBACK");

    pg::ExecStatusType status = pq_result_status(res);
    if (status != PGRES_COMMAND_OK) {
        self._last_error = pq_result_error_message(res).str_view();
        return sql::Error.COMMAND_FAILED?;
    }

    self._tx_in_progress = false;
}

fn bool PostgresConnection.tx_in_progress(PostgresConnection* self) @dynamic
{
    return self._tx_in_progress;
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

    DString builder = dstring::new(allocator:allocator::temp());
    builder.append(tmp_value.str_view());

    // Sadly our driver currently always returns values as string
    // In the future, we'll use binary data and avoid conversions from string
    sql::@convert_builder_value(builder, dest, was_null)!;

    return;
}

fn void PostgresResult.close(PostgresResult* self) @dynamic
{
    pq_clear(self.result);
    mem::free(self);
    return;
}