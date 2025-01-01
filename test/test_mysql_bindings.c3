module mysqltest @test @if(!$feature(NO_MYSQL));

import std::io;
import mysql8;

fn void! test_all() {
std::core::mem::@report_heap_allocs_in_scope($feature(MEMCHECK)) {
	mysql8::library_init(0, null, null);

	Mysql mysql = mysql8::init(null);
	assert(mysql != null, "init failed");

	Mysql mysql2 = mysql8::real_connect(mysql, "localhost", "root", "", "test", 3306, null, 0);
	if (mysql2 == null) {
		CUInt err_number = mysql8::errno(mysql);
		io::printf("Errno: %d\n", err_number);

		ZString err = mysql8::error(mysql);
		assert(mysql != null, "real_connect failed, error: %d", err);
	}

	CUInt error = mysql8::errno(mysql);
	assert(error == 0, "connect failed, expected 0, got %d", error);

	ZString cmd = "SELECT 'Hello, World' AS hello, 1 as world";
	CInt result = mysql8::real_query(mysql, cmd, cmd.len());
	assert(result == 0, "query failed, expected 0, got %d", result);

	MysqlRes res = mysql8::use_result(mysql);
	assert(res != null, "use_result failed");

	CUInt count = mysql8::num_fields(res);
	assert(count == 2, "num_fields failed, expected 2, got %d", count);

	MysqlRow row = mysql8::fetch_row(res);
	assert(row != null, "fetch_row failed");

	mysql8::close(mysql);
	mysql8::library_end();
};
}