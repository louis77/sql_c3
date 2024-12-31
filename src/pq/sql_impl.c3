module pq @if($defined(status));

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

// Driver

fn void Postgres.free(Postgres* self) @dynamic {
    free((Postgres*)self);
}

fn void register_driver() @init @private {
    Postgres* db = mem::new(Postgres);
    sql::register_driver("postgres", db);
}


fn sql::Connection! Postgres.open(Postgres* self, String connection_string) @dynamic
{
    PGconn conn = connectdb((ZString)connection_string);
    ConnStatusType dbstatus = status(conn);
    if (dbstatus != OK)
    {
        return sql::Error.CONNECTION_FAILURE?;
    }

    PostgresConnection* c = mem::new(PostgresConnection);
    c.conn = conn;
    c.connection_string = connection_string.copy();
    c._tx_in_progress = false;
    return (sql::Connection) c;
}

// Connection

fn void! PostgresConnection.ping(PostgresConnection* self) @dynamic
{
    PGconn tmp_conn = connectdb((ZString)self.connection_string);
    ConnStatusType dbstatus = status(tmp_conn);
    if (dbstatus != OK)
    {
        return sql::Error.CONNECTION_FAILURE?;
    }
}

fn void PostgresConnection.close(PostgresConnection* self) @dynamic
{
    finish(self.conn);
    free(self.connection_string);
    free(self);
}

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

        paramTypes[idx] = Oid.CSTRINGOID.oid;
        paramValues[idx] = out.zstr_view();
        paramLengths[idx] = (int)out.len();
        paramFormats[idx] = 0;
    }

    PGresult res = exec_params(self.conn, (ZString)command, args.len,
        paramTypes, paramValues, paramLengths, paramFormats, 0); // 0 = TEXT

    ExecStatusType status = result_status(res);
    if ((status != TUPLES_OK) && (status != COMMAND_OK)) {
        self._last_error = result_error_message(res).str_view();
        return sql::Error.COMMAND_FAILED?;
    }

    return res;
}


fn sql::Result! PostgresConnection.query(PostgresConnection* self, String command, args...) @dynamic
{
    PGresult result = bind_parameters_and_exec(self, command, ...args)!;

    PostgresResult* res = mem::new(PostgresResult);
    res.row_count = ntuples(result);
    res.current_row = -1;
    res.result = result;

    return (sql::Result) res;
}

fn usz! PostgresConnection.exec(PostgresConnection* self, String command, args...) @dynamic
{
    PGresult result = bind_parameters_and_exec(self, command, ...args)!;

    ZString affected_rows_str = cmd_tuples(result);
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

    PGresult res = exec(self.conn, "BEGIN");

    ExecStatusType status = result_status(res);
    if (status != COMMAND_OK) {
        self._last_error = result_error_message(res).str_view();
        return sql::Error.COMMAND_FAILED?;
    }

    self._tx_in_progress = true;
}

fn void! PostgresConnection.tx_commit(PostgresConnection* self) @dynamic
{
    PGresult res = exec(self.conn, "COMMIT");

    ExecStatusType status = result_status(res);
    if (status != COMMAND_OK) {
        self._last_error = result_error_message(res).str_view();
        return sql::Error.COMMAND_FAILED?;
    }

    self._tx_in_progress = false;
}

fn void! PostgresConnection.tx_rollback(PostgresConnection* self) @dynamic
{
    PGresult res = exec(self.conn, "ROLLBACK");

    ExecStatusType status = result_status(res);
    if (status != COMMAND_OK) {
        self._last_error = result_error_message(res).str_view();
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
    ZString tmp_value = getvalue(self.result, self.current_row, fieldnum);
    bool was_null = getisnull(self.result, self.current_row, fieldnum);
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
    clear(self.result);
    mem::free(self);
    return;
}