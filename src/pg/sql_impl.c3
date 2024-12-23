module pg;

import std::io;
import sql;

fault PostgresError
{
    CONNECTION_FAILURE,
    NOT_IMPLEMENTED,
    COMMAND_FAILED,
}

struct Postgres (sql::Driver) {
    int x;
}

struct PostgresResult (sql::Result) {
    PGresult result;
    int current_row; // TODO: Match with maximum size of rows returned by driver
    usz row_count;
}

struct PostgresConnection (sql::Connection) {
    void* conn;
    String connection_string;
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
        io::printf("-> status: %s\n", dbstatus);
        return PostgresError.CONNECTION_FAILURE?;
    }
}

// Connection

fn sql::Result! PostgresConnection.query(PostgresConnection* self, String command) @dynamic
{
    PostgresResult* res = mem::new(PostgresResult);
    PGresult result = pq_exec(self.conn, (ZString)command);

    if (pq_result_status(result) != PGRES_TUPLES_OK) {
        return PostgresError.COMMAND_FAILED?;
    }

    res.row_count = pq_ntuples(result);
    res.current_row = -1;
    res.result = result;

    return (sql::Result) res;
}

fn usz! PostgresConnection.exec(PostgresConnection* self, String command) @dynamic
{
    return 0;
}

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
    io::printf("scanning row: %d field: %d\n", self.current_row, fieldnum);
    
    String* our_dest = (String*)dest;
    bool is_null = pq_getisnull(self.result, self.current_row, fieldnum);
    if (is_null) {
        io::printn("-> was null");
        dest = null;
        return;
    }

    String value = pq_getvalue(self.result, self.current_row, fieldnum).str_view();
    *our_dest = value.copy();
    return;
}

fn void! PostgresResult.close(PostgresResult* self) @dynamic
{
    pq_clear(self.result);
    mem::free(self);
    return;
}