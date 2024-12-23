module pg;

import sql;

struct Postgres (sql::Driver) {
    int x;
}

fn Postgres* new_postgres() {
    Postgres* pg = malloc(Postgres.sizeof);
    return pg;
}

fn void free_postgres(Postgres* pg) {
    free(pg);
}

fn void* Postgres.open(Postgres* self, String connection_string) @dynamic
{
    PGconn conn = pq_connectdb((ZString)connection_string);
    return (void*)conn;
}

fn void Postgres.close(Postgres* self, void* conn) @dynamic
{
    pq_finish((PGconn)conn);
}

fn bool Postgres.ping(Postgres* self, void* conn) @dynamic
{	
    ConnStatusType dbstatus = pq_status(conn);

    return dbstatus == CONNECTION_OK;
}

// Tests

fn void! test_open() @test 
{
    Postgres pg;
    void* conn = pg.open("postgres://postgres@localhost/postgres");
    assert(pg.ping(conn));
    pg.close(conn);
}

fn void! test_close() @test 
{
    Postgres pg;
    void* conn = pg.open("postgres://postgres@localhost/postgres");
    pg.close(conn);
}