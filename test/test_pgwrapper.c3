module pg;

import std::io;

fn void! test_all() @test
{
	CInt libversion = pq_lib_version();
	io::printf("libpq version: %d\n", libversion);
    assert(libversion > 0, "Lib version should be greater than 0");

	io::printn("Opening connection");
	PGconn conn = pq_connectdb("postgres://postgres@localhost/postgres");

    // At this point, the connection is not established yet

	ConnStatusType dbstatus = pq_status(conn);
	io::printf("-> status: %s\n", dbstatus);
    assert(dbstatus == CONNECTION_OK);

	ZString dbname = pq_db(conn);
	io::printf("-> name: %s\n", dbname);
    assert(ZString.str_view(dbname) == "postgres");

	ZString dbuser = pq_user(conn);
	io::printf("-> user: %s\n", dbuser);

	ZString dbpass = pq_pass(conn);
	io::printf("-> pass: %s\n", dbpass);

	ZString dbhost = pq_host(conn);
	io::printf("-> host: %s\n", dbhost);

	ZString dbhostaddr = pq_hostaddr(conn);
	io::printf("-> hostaddr: %s\n", dbhostaddr);

	ZString dbport = pq_port(conn);
	io::printf("-> port: %s\n", dbport);

	ZString dboptions = pq_options(conn);
	io::printf("-> options: %s\n", dboptions);

	CInt server_version = pq_server_version(conn);
	io::printf("-> server version: %d\n", server_version);

	ZString error = pq_error_message(conn);
	io::printf("-> error: %s\n", error);

	io::printn("Executing a simple query");
	PGresult result = pq_exec(conn, "SELECT 'Hello, World' AS hello, NULL as world");

	ExecStatusType result_status = pq_result_status(result);
	io::printf("-> status: %s\n", result_status);

	CInt ntuples = pq_ntuples(result);
	io::printf("-> rows: %d\n", ntuples);

	CInt nfields = pq_nfields(result);
	io::printf("-> columns: %d\n", nfields);

	ZString cmd_status = pq_cmd_status(result);
	io::printf("-> command status: %s\n", cmd_status);

	for (int i = 0; i < nfields; i++)
	{
		ZString fname = pq_fname(result, i);
		io::printf("-> column %d: '%s'", i+1, fname);

		CInt fnumber = pq_fnumber(result, fname);
		io::printf(" -> position %d", fnumber);

		ColumnFormatCode fformat = pq_fformat(result, i);
		io::printf(" (%s) ", fformat);

		CInt ftype = pq_ftype(result, i);
		io::printf("-> type: %d (%s)\n", ftype, oid_from_int(ftype));
	}

	io::printn("Result values:");
	for (int i = 0; i < ntuples; i++)
	{
		for (int j = 0; j < nfields; j++)
		{
			ZString value = pq_getvalue(result, i, j);
			bool is_null = pq_getisnull(result, i, j);
			io::printf(" [%d][%d] '%s' (NULL? %s)\n", i, j, value, is_null);
		}
		io::printn("");
	}

	pq_clear(result);
	io::printn("-> result cleared");

	io::printn("Closing connection");
	pq_finish(conn);
}