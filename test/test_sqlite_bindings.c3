module sqlite_tests @test @if(!$feature(NO_SQLITE));

import std::io;
import sqlite3;

fn void! test_sqlite_open()
{
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	SqliteHandle handle;
	ResultStatus ret = sqlite3::open("test.sqlite", &handle);
	assert(ret == sqlite3::OK, "error on open(): %d", ret);

	ret = sqlite3::close(handle);
	assert(ret == sqlite3::OK, "error on close(): %d", ret);
};
}

fn void! test_sqlite_simple_query()
{
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	SqliteHandle handle;
	ResultStatus ret = sqlite3::open("test.sqlite", &handle);
	assert(ret == sqlite3::OK, "error on open(): %d", ret);

	ZString* errmsgs;
	ret = sqlite3::exec(handle, "SELECT 'hello' as world, 1 as a_num", fn ResultStatus (void* context, CInt num_columns, ZString* result, ZString* col_names){
		assert(num_columns == 2, "incorrect number of columns returned: %d", num_columns);
		assert(col_names[0].str_view() == "world", "unexpected name of col[0]: '%s'", col_names[0]);
		assert(col_names[1].str_view() == "a_num", "unexpected name of col[1]: '%s'", col_names[1]);

		assert(result[0].str_view() == "hello", "unexpected result[0]: '%s'", result[0]);
		assert(result[1].str_view() == "1", "unexpected result[1]: '%s'", result[1]);

		return sqlite3::OK;
	}, null, errmsgs);
	assert(ret == sqlite3::OK, "error on exec(): %d", ret);

	ret = sqlite3::close(handle);
	assert(ret == sqlite3::OK, "error on close(): %d", ret);
};
}

fn void! test_sqlite_prepare()
{
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	SqliteHandle handle;
	ResultStatus ret = sqlite3::open("test.sqlite", &handle);
	assert(ret == sqlite3::OK, "error on open(): %d", ret);
	assert(handle != null, "handle was null");

	ZString cmd = "SELECT 'hello' AS greeting;";
	SqliteStmt stmt;
	ret = sqlite3::prepare_v2(handle, cmd, -1, &stmt, null);

	assert(ret == sqlite3::OK, "error on prepare_v2(): %d", ret);
	assert(stmt != null, "stmt was null");

	while(true) {
		ret = sqlite3::step(stmt);
		assert(ret == sqlite3::ROW, "error on step(): %s", status_string(ret));

		ZString val = sqlite3::column_text(stmt, 0);
		assert(val.str_view() == "hello", "value should be 'hello', was '%s'", val);
		break;
	}

	ret = sqlite3::finalize(stmt);
	assert(ret == sqlite3::OK);

	ret = sqlite3::close(handle);
	assert(ret == sqlite3::OK, "error on close(): %d", ret);
};
}