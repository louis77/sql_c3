module pg_test @test;

import std::io;
import sql;

String connection_string = "postgres://postgres@localhost/postgres";

fn void! test_pg_success() {
mem::@report_heap_allocs_in_scope() {
	sql::Connection! conn = sql::open("postgres", connection_string);
	conn.ping()!;
	conn.close()!;
};
}

fn void! test_pg_fail() {
mem::@report_heap_allocs_in_scope() {
	String connection_string = "postgres://postgres@THISISWRONG/postgres";
	sql::Connection! conn = sql::open("postgres", connection_string);
	if (catch error = conn.ping()) {
		return; // This is what we expect
	}

	assert(false, "Connection should have failed");
};
}

fn void! test_pg_query() {
mem::@report_heap_allocs_in_scope() {
	sql::Connection conn = sql::open("postgres", "postgres://postgres@localhost/postgres")!;
	defer try conn.close();

	String cmd = `SELECT * FROM (VALUES
		(1, 'hello', true, null),
		(2, 'world', false, null))
	AS t(a_num, a_string, a_bool, a_null)`;
	Result res = conn.query(cmd)!;
	defer res.close();

	usz count = 0;
	while (res.next()) {
		count++;
		int a_num;
		String a_string;
		ZString a_zstring;
		String a_bool;
		int* a_null;
		res.scan(0, &a_num)!;
		res.scan(1, &a_string)!;
		res.scan(1, &a_zstring)!;
		res.scan(2, &a_bool)!;
		res.scan(3, &a_null)!;
		if (count == 1) {
			assert(a_num == 1, "a_num should be 1");
			assert(a_string == "hello", "a_string should be 'hello'");
			assert(a_zstring.str_view() == "hello", "a_zstring should be 'hello'");
			assert(a_bool == "t", "a_bool should be 'true'");
			assert(a_null == null, "a_null should be null");
		}
		if (count == 2) {
			assert(a_num == 2, "a_num should be 2");
			assert(a_string == "world", "a_string should be 'world'");
			assert(a_zstring.str_view() == "world", "a_zstring should be 'world'");
			assert(a_bool == "f", "a_bool should be 'false'");
			assert(a_null == null, "a_null should be null");
		}
	}

	assert(count == 2, "Should have fetched one row");
};
}

fn void! test_pg_malformed_query() {
mem::@report_heap_allocs_in_scope() {
	sql::Connection conn = sql::open("postgres", "postgres://postgres@localhost/postgres")!;
	defer try conn.close();

	String cmd = `SELECT * FR OM what?`;
	Result! res = conn.query(cmd);

	if (catch excuse = res) {
		// This is what we except
		String error_message = conn.last_error();
		assert(error_message.contains("syntax error"), "expected syntax error");
		return;
	}

	assert(false, "Query should have failed");
};
}


fn void! test_pg_exec() {
mem::@report_heap_allocs_in_scope() {
	sql::Connection conn = sql::open("postgres", "postgres://postgres@localhost/postgres")!;
	defer try conn.close();

	String cmd = `CREATE TEMPORARY TABLE IF NOT EXISTS test (col INT)`;
	if (catch excuse = conn.exec(cmd)) {
		io::printn(conn.last_error());
		io::printn("HERE2");
		return excuse?;
	}

	cmd = `INSERT INTO test VALUES (1), (2), (3)`;
	usz! affected_rows = conn.exec(cmd);
	if (catch excuse = affected_rows) {
		io::printn(conn.last_error());
		io::printn("HERE");
		return excuse?;
	}
	assert(affected_rows == 3, "Query didn't affect 3 rows");
};
}

fn void! test_pg_parameterized_query() {
mem::@report_heap_allocs_in_scope() {
	sql::Connection conn = sql::open("postgres", connection_string)!;
	defer try conn.close();

	String expect2 = "efgh";
	String expect = "abcd"; // TODO Test all possible types
	String cmd = `SELECT $1 as a_param, $2 as b_param`;
	Result! res = conn.query(cmd, expect, expect2);

	if (catch excuse = res) {
		io::printn(conn.last_error());
		return excuse?;
	}
	defer res.close();
	assert(res.next(), "expected at least one row, got none");

	String a_param;
	String b_param;
	res.scan(0, &a_param)!;
	res.scan(1, &b_param)!;

	assert(a_param == expect);
	assert(b_param == expect2);
};
}


fn void! test_pg_transaction_success() {
mem::@report_heap_allocs_in_scope()
{
	sql::Connection conn = sql::open("postgres", connection_string)!;
	defer try conn.close();

	conn.tx_begin()!;
	defer (catch err) {
		if (catch conn.tx_rollback()) {
			assert(false, "Rollback failed");
		}
	}

	assert(conn.tx_in_progress(), "Transaction should be in progress");

	String cmd = `DROP TABLE IF EXISTS test`;
	if (catch excuse = conn.exec(cmd)) {
		io::printn(conn.last_error());
		io::printn(excuse);
		return excuse?;
	};

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
	res.scan(0, &x)!;
	assert(x == 1, "x should be 1");
};
}

fn void! test_pg_transaction_rollback() {
mem::@report_heap_allocs_in_scope()
{
	sql::Connection conn = sql::open("postgres", connection_string)!;
	defer try conn.close();

	String cmd = `DROP TABLE IF EXISTS test`;
	conn.exec(cmd)!;

	cmd = `CREATE TABLE test (x INT)`;
	usz affected_rows = conn.exec(cmd)!;

	// Note: DDL in Postgres are part of the transaction.
	// This is why we create the table outside of the transaction,
	// Otherwise we cannot test if the row was actually committed.
	conn.tx_begin()!;
	defer (catch err) {
		if (catch conn.tx_rollback()) {
			assert(false, "Rollback failed");
		}
	}

	assert(conn.tx_in_progress(), "Transaction should be in progress");

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

fn void! test_pg_double_transaction() {
mem::@report_heap_allocs_in_scope()
{
	sql::Connection conn = sql::open("postgres", connection_string)!;
	defer try conn.close();

	if (catch excuse = conn.tx_begin()) {
		assert(excuse == sql::Error.TX_ALREADY_IN_PROGRESS, "Transaction should be already in progress");
	};

	if (try conn.tx_begin()) {
		assert(false, "Transaction should be already in progress");
	}
};
}
