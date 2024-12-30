module pg_tests @test;

import std::io;
import pg;

ZString connection_string = "postgres://postgres@localhost/postgres";


fn void! test_all()
{
mem::@report_heap_allocs_in_scope() {
	CInt libversion = pg::pq_lib_version();
    assert(libversion > 0, "Lib version should be greater than 0");

	PGconn conn = pg::pq_connectdb(connection_string);

    // At this point, the connection is not established yet

	ConnStatusType dbstatus = pg::pq_status(conn);
    assert(dbstatus == CONNECTION_OK);

	ZString dbname = pg::pq_db(conn);
    assert(ZString.str_view(dbname) == "postgres");

	ZString dbuser = pg::pq_user(conn);
	assert(ZString.str_view(dbuser) == "postgres");

	ZString dbhost = pg::pq_host(conn);
	assert(ZString.str_view(dbhost) == "localhost");

	ZString dbhostaddr = pg::pq_hostaddr(conn);
	ZString dbport = pg::pq_port(conn);
	ZString dboptions = pg::pq_options(conn);

	PGresult result = pg::pq_exec(conn, "SELECT 'Hello, World' AS hello, NULL as world");
	ExecStatusType result_status = pg::pq_result_status(result);
	assert(result_status == PGRES_TUPLES_OK);

	CInt ntuples = pg::pq_ntuples(result);
	assert(ntuples == 1, "wrong number of tuples returned, expected 1");

	CInt nfields = pg::pq_nfields(result);
	assert(nfields == 2, "wrong number of fields returned, expected 2");

	ZString cmd_status = pg::pq_cmd_status(result);
	assert(ZString.str_view(cmd_status) == "SELECT 1");

	for (int i = 0; i < nfields; i++)
	{
		ZString fname = pg::pq_fname(result, i);

		CInt fnumber = pg::pq_fnumber(result, fname);
		assert(fnumber == i);

		ColumnFormatCode fformat = pg::pq_fformat(result, i);
		assert(fformat == TEXT);

		CInt ftype = pg::pq_ftype(result, i);
		assert(ftype == 25);
		assert(oid_from_int(ftype) == TEXTOID);
	}

	for (int i = 0; i < ntuples; i++)
	{
		for (int j = 0; j < nfields; j++)
		{
			ZString value = pg::pq_getvalue(result, i, j);
			bool is_null = pg::pq_getisnull(result, i, j);
		}
	}

	pg::pq_clear(result);
	pg::pq_finish(conn);
};
}

fn void! test_cmd_tuples()
{
mem::@report_heap_allocs_in_scope()
{
	PGconn conn = pg::pq_connectdb(connection_string);
	ConnStatusType dbstatus = pg::pq_status(conn);
    assert(dbstatus == CONNECTION_OK);

	PGresult result = pg::pq_exec(conn, "CREATE TEMPORARY TABLE test (col INT)");
	ZString cmd_status = pg::pq_cmd_status(result);

	result = pg::pq_exec(conn, "INSERT INTO test VALUES (1)");
	ZString ntuples = pg::pq_cmd_tuples(result);

	pg::pq_clear(result);
	pg::pq_finish(conn);
};
}