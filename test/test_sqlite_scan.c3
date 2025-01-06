module sqlite_test_scan @test @if(!$feature(NO_SQLITE));

import std::io;
import sql;

String connection_string = "test.sqlite";

fn void! test_sqlite_scan_int()
{
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	sql::Connection conn = sql::open("sqlite", connection_string)!;
	defer try conn.close();

	String cmd = `SELECT 1 as an_int`;
	Result res = conn.query(cmd)!;
	defer res.close();

	usz count = 0;
	while (res.next()) {
		count++;
		int value;
		res.scan(value)!;
		assert(value == 1, "a_num should be 1");
	}
};
}

fn void! test_sqlite_scan_intptr()
{
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	sql::Connection conn = sql::open("sqlite", connection_string)!;
	defer try conn.close();

	String cmd = `SELECT 1 as an_int`;
	Result res = conn.query(cmd)!;
	defer res.close();

	usz count = 0;
	while (res.next()) {
		count++;
		int value;
		res.scan(&value)!;
		assert(value == 1, "a_num should be 1");
	}
};
}


fn void! test_sqlite_scan_intnull()
{
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	sql::Connection conn = sql::open("sqlite", connection_string)!;
	defer try conn.close();

	String cmd = `SELECT NULL as an_int`;
	Result res = conn.query(cmd)!;
	defer res.close();

	usz count = 0;
	while (res.next()) {
		count++;
		int value;
		res.scan(value)!;
		assert(value == 0, "value should be 0");
	}
};
}

/*
fn void! test_sqlite_scan_intptrnull()
{
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	sql::Connection conn = sql::open("sqlite", connection_string)!;
	defer try conn.close();

	String cmd = `SELECT NULL as an_int`;
	Result res = conn.query(cmd)!;
	defer res.close();

	usz count = 0;
	while (res.next()) {
		count++;
		int* value = &&99;
		res.scan(&value)!;
		assert(value == null, "value* should be null");
	}
};
}
