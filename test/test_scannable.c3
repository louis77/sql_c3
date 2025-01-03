module scantest @if(!$feature(NO_PQ));

import std::io;
import sql;

String connection_string = "postgres://postgres@localhost/postgres";

struct MyScanner
{
    int  int_value;
	bool valid;
}

fn void! MyScanner.decode(&self, ZString raw_value) @dynamic
{
    int tmp = raw_value.str_view().to_int()!;
    self.int_value = tmp;
	self.valid = true;
}

fn void! test_scannable_decode() @test {
	sql::Connection conn = sql::open("postgres", connection_string)!;
	defer try conn.close();

	int expect = 2;
	String cmd = `SELECT $1 as a_param`;
	Result! res = conn.query(cmd, expect);

	if (catch excuse = res) {
		io::printn(conn.last_error());
		return excuse?;
	}
	defer res.close();
	assert(res.next(), "expected at least one row, got none");

	MyScanner a_param;
	res.scan(a_param)!;

	assert(a_param.int_value == expect);
}

struct MyUndecodableScanner
{
    int  int_value;
	bool valid;
}

// This type is missing the decode() function

fn void! test_scannable_decode_fail() @test {
	sql::Connection conn = sql::open("postgres", connection_string)!;
	defer try conn.close();

	int expect = 2;
	String cmd = `SELECT $1 as a_param`;
	Result! res = conn.query(cmd, expect);

	if (catch excuse = res) {
		io::printn(conn.last_error());
		return excuse?;
	}
	defer res.close();
	assert(res.next(), "expected at least one row, got none");

	MyUndecodableScanner a_param;
	if (catch excuse = res.scan(a_param)) {
		if (!(excuse == sql::Error.UNSUPPORTED_SCAN_TYPE)) {
			return excuse?;
		}
		else {
			return;
		}
	}
	assert(false, "a type without decode() should not be scannable");
}

fn void! test_scannable_decode_fail_with_null() @test {
	sql::Connection conn = sql::open("postgres", connection_string)!;
	defer try conn.close();

	int expect = 2;
	String cmd = `SELECT NULL as a_param`;
	Result! res = conn.query(cmd, expect);

	if (catch excuse = res) {
		io::printn(conn.last_error());
		return excuse?;
	}
	defer res.close();
	assert(res.next(), "expected at least one row, got none");

	MyUndecodableScanner a_param;
	if (catch excuse = res.scan(a_param)) {
		if (!(excuse == sql::Error.UNSUPPORTED_SCAN_TYPE)) {
			return excuse?;
		}
		else {
			return;
		}
	}
	assert(false, "a type without decode() should fail even with NULL values");
}



struct AccessKey {
	String group    @SqlName("grp");
	String key      @SqlOmit;
	String ts       @SqlName("updated_at");
	String name;
	String type;
}

fn void! test_scan_struct() @test
{
	sql::Connection conn = sql::open("postgres", connection_string)!;
	defer try conn.close();

	String cmd = `SELECT 'vt' as grp, '1234' as key, 'now' as updated_at, 'John' as name, 'person' as type`;
	Result! res = conn.query(cmd);

	if (catch excuse = res) {
		io::printn(conn.last_error());
		return excuse?;
	}
	defer res.close();
	assert(res.next(), "expected at least one row, got none");

	AccessKey ak;
	res.@scan_struct(ak)!;

	assert(ak.group == "vt", "ak.group should be 'vt', was '%s'", ak.group);
	assert(ak.key == "", "ak.key should be omitted, was '%s'", ak.key);
	assert(ak.ts == "now", "ak.ts should be 'now', was '%s'", ak.ts);
	assert(ak.name == "John", "ak.name should be 'John', was '%s'", ak.name);
	assert(ak.type == "person", "ak.type should be 'person', was '%s'", ak.type);
}