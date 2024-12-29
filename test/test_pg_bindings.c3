module pg @test;

import std::io;

ZString connection_string = "postgres://postgres@localhost/postgres";

fn void! test_all()
{
mem::@report_heap_allocs_in_scope() {
	CInt libversion = pq_lib_version();
    assert(libversion > 0, "Lib version should be greater than 0");

	PGconn conn = pq_connectdb(connection_string);

    // At this point, the connection is not established yet

	ConnStatusType dbstatus = pq_status(conn);
    assert(dbstatus == CONNECTION_OK);

	ZString dbname = pq_db(conn);
    assert(ZString.str_view(dbname) == "postgres");

	ZString dbuser = pq_user(conn);
	assert(ZString.str_view(dbuser) == "postgres");

	ZString dbhost = pq_host(conn);
	assert(ZString.str_view(dbhost) == "localhost");

	ZString dbhostaddr = pq_hostaddr(conn);
	ZString dbport = pq_port(conn);
	ZString dboptions = pq_options(conn);

	PGresult result = pq_exec(conn, "SELECT 'Hello, World' AS hello, NULL as world");
	ExecStatusType result_status = pq_result_status(result);
	assert(result_status == PGRES_TUPLES_OK);

	CInt ntuples = pq_ntuples(result);
	assert(ntuples == 1, "wrong number of tuples returned, expected 1");

	CInt nfields = pq_nfields(result);
	assert(nfields == 2, "wrong number of fields returned, expected 2");

	ZString cmd_status = pq_cmd_status(result);
	assert(ZString.str_view(cmd_status) == "SELECT 1");

	for (int i = 0; i < nfields; i++)
	{
		ZString fname = pq_fname(result, i);

		CInt fnumber = pq_fnumber(result, fname);
		assert(fnumber == i);

		ColumnFormatCode fformat = pq_fformat(result, i);
		assert(fformat == TEXT);

		CInt ftype = pq_ftype(result, i);
		assert(ftype == 25);
		assert(oid_from_int(ftype) == TEXTOID);
	}

	for (int i = 0; i < ntuples; i++)
	{
		for (int j = 0; j < nfields; j++)
		{
			ZString value = pq_getvalue(result, i, j);
			bool is_null = pq_getisnull(result, i, j);
		}
	}

	pq_clear(result);
	pq_finish(conn);
};
}

fn void! test_cmd_tuples()
{
mem::@report_heap_allocs_in_scope()
{
	PGconn conn = pq_connectdb(connection_string);
	ConnStatusType dbstatus = pq_status(conn);
    assert(dbstatus == CONNECTION_OK);

	PGresult result = pq_exec(conn, "CREATE TEMPORARY TABLE test (col INT)");
	ZString cmd_status = pq_cmd_status(result);

	result = pq_exec(conn, "INSERT INTO test VALUES (1)");
	ZString ntuples = pq_cmd_tuples(result);

	pq_clear(result);
	pq_finish(conn);
};
}