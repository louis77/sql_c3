module mysql8_test @test @if(!$feature(NO_MYSQL));

import std::io;
import sql;

String connection_string = "mysql://root@localhost:3306/test";

fn void! test_mysql_success() {
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	sql::Connection conn = sql::open("mysql", connection_string)!;
	defer try conn.close();

	conn.ping()!;
};
}

fn void! test_mysql_query() {
mem::@report_heap_allocs_in_scope(false)
{
	sql::Connection conn = sql::open("mysql", connection_string)!;
	defer try conn.close();

	String cmd = `SELECT 1 as an_int, 'hello' as a_string, TRUE as a_bool, null as a_null
		UNION
		SELECT 2 as an_int, 'world' as a_string, FALSE as a_bool, null as a_null`;
	Result res = conn.query(cmd)!;

	usz count = 0;
	while (res.next()) {
		count++;
		int a_num;
		String a_string;
		bool a_bool;
		int* a_null;
		res.scan(a_num, a_string, a_bool, a_null)!;
		if (count == 1) {
			assert(a_num == 1, "a_num should be 1");
			assert(a_string == "hello", "a_string should be 'hello'");
			assert(a_bool, "a_bool should be 'true'");
			assert(a_null == null, "a_null should be null");
		}
		if (count == 2) {
			assert(a_num == 2, "a_num should be 2");
			assert(a_string == "world", "a_string should be 'world'");
			assert(!a_bool, "a_bool should be 'false'");
			assert(a_null == null, "a_null should be null");
		}
	}

	assert(count == 2, "Should have fetched two rows");
};
}

fn void! test_mysql_fail()
{
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	String connection_string = "mysql://WHUUT@loca lhost:3306/test";
	sql::Connection! conn = sql::open("mysql", connection_string);

	if (catch excuse = conn) {
		return; // This is what we expect
	}

	assert(false, "Connection should have failed");
};
}

fn void! test_mysql_exec()
{
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	sql::Connection conn = sql::open("mysql", connection_string)!;
	defer conn.close();

	String cmd = `DROP TABLE test`;
	conn.exec(cmd)!;

	cmd = `CREATE TABLE test (x INT)`;
	usz affected_rows = conn.exec(cmd) ?? 0;
	assert(affected_rows == 0, "CREATE TABLE should not affect any rows");

	cmd = `INSERT INTO test VALUES (1)`;
	affected_rows = conn.exec(cmd) ?? 0;
	assert(affected_rows == 1, "INSERT INTO should affect 1 row");
};
}

fn void! test_mysql_malformed_query() {
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	sql::Connection conn = sql::open("mysql", connection_string)!;
	defer conn.close();

	String cmd = `SELECT * FR OM what?`;
	Result! res = conn.query(cmd);

	if (catch excuse = res) {
		// This is what we except
		String error_message = conn.last_error();
		assert(error_message.contains("error in your SQL syntax"), "expected syntax error, got '%s'", error_message);
		return;
	}

	assert(false, "Query should have failed");
};
}

fn void! test_mysql_parameterized_query() {
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	sql::Connection conn = sql::open("mysql", connection_string)!;
	defer try conn.close();

	String expect2 = "efgh";
	String expect = "abcd";
	String cmd = `SELECT ? as a_param, ? as b_param`;
	Result res = conn.query(cmd, expect, expect2)!;
	defer res.close();

	assert(res.next(), "expected at least one row, got none");

	String a_param;
	String b_param;
	res.scan(a_param, b_param)!;

	assert(a_param == expect);
	assert(b_param == expect2);
};
}

fn void! test_mysql_transaction_success() {
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	sql::Connection conn = sql::open("mysql", connection_string)!;
	defer try conn.close();

	conn.tx_begin()!;
	defer (catch err) {
		if (catch conn.tx_rollback()) {
			assert(false, "Rollback failed");
		}
	}

	assert(conn.tx_in_progress(), "Transaction should be in progress");

	String cmd = `DROP TABLE IF EXISTS test`;
	conn.exec(cmd)!;

	cmd = `CREATE TABLE test (x INT)`;
	usz affected_rows = conn.exec(cmd)!;

	cmd = `INSERT INTO test VALUES (1)`;
	affected_rows = conn.exec(cmd)!;
	assert(affected_rows == 1, "INSERT INTO should affect 1 row");

	conn.tx_commit()!;
	assert(!conn.tx_in_progress(), "Transaction should not be in progress");

	// We expect now this row to exist
	cmd = `SELECT * FROM test`;
	Result res = conn.query(cmd)!;
	defer res.close();

	assert(res.next(), "expected at least one row, got none");

	int x;
	res.scan(&x)!;
	assert(x == 1, "x should be 1");
};
}

fn void! test_mysql_transaction_rollback() {
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	sql::Connection conn = sql::open("mysql", connection_string)!;
	defer try conn.close();

	conn.tx_begin()!;
	defer (catch err) {
		if (catch conn.tx_rollback()) {
			assert(false, "Rollback failed");
		}
	}

	assert(conn.tx_in_progress(), "Transaction should be in progress");

	String cmd = `DROP TABLE IF EXISTS test`;
	conn.exec(cmd)!;

	cmd = `CREATE TABLE test (x INT)`;
	usz affected_rows = conn.exec(cmd)!;

	cmd = `INSERT INTO test VALUES (1)`;
	affected_rows = conn.exec(cmd)!;
	assert(affected_rows == 1, "INSERT INTO should affect 1 row");

	conn.tx_rollback()!;
	assert(!conn.tx_in_progress(), "Transaction should not be in progress");

	// We expect now this row to not exist
	cmd = `SELECT * FROM test`;
	Result res = conn.query(cmd)!;
	defer res.close();

	assert(!res.next(), "expected no rows, got one");
};
}

fn void! test_mysql_double_transaction() {
mem::@report_heap_allocs_in_scope($feature(MEMCHECK))
{
	sql::Connection conn = sql::open("mysql",connection_string)!;
	defer try conn.close();

	if (catch excuse = conn.tx_begin()) {
		assert(excuse == sql::Error.TX_ALREADY_IN_PROGRESS, "Transaction should be already in progress");
	};

	if (try conn.tx_begin()) {
		assert(false, "Transaction should be already in progress");
	}
};
}
