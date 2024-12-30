module pg_tests @test;

import std::io;
import pq;

ZString connection_string = "postgres://postgres@localhost/postgres";


fn void! test_all()
{
mem::@report_heap_allocs_in_scope() {
	CInt libversion = pq::lib_version();
    assert(libversion > 0, "Lib version should be greater than 0");

	PGconn conn = pq::connectdb(connection_string);

    // At this point, the connection is not established yet

	ConnStatusType dbstatus = pq::status(conn);
    assert(dbstatus == OK);

	ZString dbname = pq::db(conn);
    assert(ZString.str_view(dbname) == "postgres");

	ZString dbuser = pq::user(conn);
	assert(ZString.str_view(dbuser) == "postgres");

	ZString dbhost = pq::host(conn);
	assert(ZString.str_view(dbhost) == "localhost");

	ZString dbhostaddr = pq::hostaddr(conn);
	ZString dbport = pq::port(conn);
	ZString dboptions = pq::options(conn);

	PGresult result = pq::exec(conn, "SELECT 'Hello, World' AS hello, NULL as world");
	ExecStatusType result_status = pq::result_status(result);
	assert(result_status == TUPLES_OK);

	CInt ntuples = pq::ntuples(result);
	assert(ntuples == 1, "wrong number of tuples returned, expected 1");

	CInt nfields = pq::nfields(result);
	assert(nfields == 2, "wrong number of fields returned, expected 2");

	ZString cmd_status = pq::cmd_status(result);
	assert(ZString.str_view(cmd_status) == "SELECT 1");

	for (int i = 0; i < nfields; i++)
	{
		ZString fname = pq::fname(result, i);

		CInt fnumber = pq::fnumber(result, fname);
		assert(fnumber == i);

		ColumnFormatCode fformat = pq::fformat(result, i);
		assert(fformat == TEXT);

		CInt ftype = pq::ftype(result, i);
		assert(ftype == 25);
		assert(oid_from_int(ftype) == TEXTOID);
	}

	for (int i = 0; i < ntuples; i++)
	{
		for (int j = 0; j < nfields; j++)
		{
			ZString value = pq::getvalue(result, i, j);
			bool is_null = pq::getisnull(result, i, j);
		}
	}

	pq::clear(result);
	pq::finish(conn);
};
}

fn void! test_cmd_tuples()
{
mem::@report_heap_allocs_in_scope()
{
	PGconn conn = pq::connectdb(connection_string);
	ConnStatusType dbstatus = pq::status(conn);
    assert(dbstatus == OK);

	PGresult result = pq::exec(conn, "CREATE TEMPORARY TABLE test (col INT)");
	ZString cmd_status = pq::cmd_status(result);

	result = pq::exec(conn, "INSERT INTO test VALUES (1)");
	ZString ntuples = pq::cmd_tuples(result);

	pq::clear(result);
	pq::finish(conn);
};
}