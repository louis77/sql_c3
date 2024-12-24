module pg;

import std::io;
import sql;

fault PostgresError
{
    CONNECTION_FAILURE,
    NOT_IMPLEMENTED,
    COMMAND_FAILED,
    UNSUPPORTED_SCAN_TYPE,
}

struct Postgres (sql::Driver) {
    int x;
}

struct PostgresResult (sql::Result) {
    PGresult result;
    int current_row;  // TODO: Match with maximum size of rows returned by driver
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

def StringPtr  = String*;
def BoolPtr    = bool*;
def IntPtr     = int*;
def Int128Ptr  = int128;
def LongPtr    = long*;
def ShortPtr   = short*;
def ICharPtr   = ichar*;
def UInt128Ptr = uint128;
def ULongPtr   = ulong*;
def UIntPtr    = uint*;
def UShortPtr  = ushort*;
def CharPtr    = char*;
def DoublePtr  = double*;
def FloatPtr   = float*;

fn void! PostgresResult.scan(PostgresResult* self, int fieldnum, any dest) @dynamic
{
    io::printf("scanning row: %d field: %d\n", self.current_row, fieldnum);
    
    bool is_null = pq_getisnull(self.result, self.current_row, fieldnum);
    if (is_null) {
        io::printn("-> was null");
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
        case IntPtr:
            io::printn("INT POINTER");
        default:
            return PostgresError.UNSUPPORTED_SCAN_TYPE?;
    }

    return;
}

fn void! PostgresResult.close(PostgresResult* self) @dynamic
{
    pq_clear(self.result);
    mem::free(self);
    return;
}