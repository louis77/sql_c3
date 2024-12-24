module sql;

import std::io;
import pg;

 String connection_string = "postgres://postgres@localhost/postgres";

fn void! test_success() @test {
    Driver driver = pg::new_postgres();
    defer pg::free_postgres(driver);

    Connection conn = driver.open(connection_string)!;
    defer driver.close(conn);

    driver.ping(connection_string)!;
}

fn void! test_fail() @test {
    String connection_string = "postgres://postgres@THISISWRONG/postgres";

    Driver driver = pg::new_postgres();
    defer pg::free_postgres(driver);

    if (catch error = driver.ping(connection_string)) {
        return; // This is what we expect
    }

    assert(false, "Connection should have failed");
}

fn void! test_query() @test {
    Driver driver = pg::new_postgres();
    defer pg::free_postgres(driver);

    Connection conn = driver.open("postgres://postgres@localhost/postgres")!;
    defer driver.close(conn);

    String cmd = `SELECT * FROM (VALUES
        (1, 'hello', true, null), 
        (2, 'world', false, null)) 
    AS t(a_num, a_string, a_bool, a_null)`;
    Result res = conn.query(cmd)!;

    usz count = 0;
    while (res.next()) {
        count++;
        int a_num;
        String a_string;
        ZString a_zstring;
        String a_bool;
        String a_null;
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
            assert(a_null == "", "a_null should be null");
        } 
        if (count == 2) {
            assert(a_num == 2, "a_num should be 2");
            assert(a_string == "world", "a_string should be 'world'");
            assert(a_zstring.str_view() == "world", "a_zstring should be 'world'");
            assert(a_bool == "f", "a_bool should be 'false'");
            assert(a_null == "", "a_null should be null");
        }
    }

    assert(count == 2, "Should have fetched one row");
}

fn void! test_malformed_query() @test {
    Driver driver = pg::new_postgres();
    defer pg::free_postgres(driver);

    Connection conn = driver.open("postgres://postgres@localhost/postgres")!;
    defer driver.close(conn);

    String cmd = `SELECT * FR OM what?`;
    Result! res = conn.query(cmd);

    if (catch excuse = res) {
        // This is what we except
        String error_message = conn.last_error();
        assert(error_message.contains("syntax error"), "expected syntax error");
        return; 
    }

    assert(false, "Query should have failed");
}


fn void! test_exec() @test {
    Driver driver = pg::new_postgres();
    defer pg::free_postgres(driver);

    Connection conn = driver.open("postgres://postgres@localhost/postgres")!;
    defer driver.close(conn);

    String cmd = `CREATE TEMPORARY TABLE IF NOT EXISTS test (col INT)`;
    conn.exec(cmd)!;
    
    cmd = `INSERT INTO test VALUES (1), (2), (3)`;
    usz affected_rows = conn.exec(cmd)!;
    assert(affected_rows == 3, "Query didn't affect 3 rows");
}