module mysqltest @test;

import std::io;

fn void! test_all() {
std::core::mem::@report_heap_allocs_in_scope() {
	library_init(0, null, null);

	Mysql mysql = init(null);
	assert(mysql != null, "init failed");

	Mysql mysql2 = real_connect(mysql, "localhost", "root", "", "test", 3306, null, 0);
	if (mysql2 == null) {
		CUInt err_number = errno(mysql);
		io::printf("Errno: %d\n", err_number);

		ZString err = error(mysql);
		assert(mysql != null, "real_connect failed, error: %d", err);
	}

	CUInt error = errno(mysql);
	assert(error == 0, "connect failed, expected 0, got %d", error);

	ZString cmd = "SELECT 'Hello, World' AS hello, 1 as world";
	CInt result = real_query(mysql, cmd, cmd.len());
	assert(result == 0, "query failed, expected 0, got %d", result);

	MysqlRes res = use_result(mysql);
	assert(res != null, "use_result failed");

	CUInt count = num_fields(res);
	assert(count == 2, "num_fields failed, expected 2, got %d", count);

	MysqlRow row = fetch_row(res);
	assert(row != null, "fetch_row failed");

	close(mysql);
	library_end();
};
}