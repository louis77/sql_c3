module sql;

import std::io;
import pg;

 String connection_string = "postgres://postgres@localhost/postgres";

fn void! test_success() @test {
    Driver driver = pg::new_postgres();
    defer pg::free_postgres(driver);
    Connection conn = driver.open(connection_string)!;
    driver.ping(connection_string)!;
    driver.close(conn);
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

    String cmd = "SELECT * FROM (VALUES(1, 'hello', null), (2, 'world', null)) AS t(a_num, a_string, a_null)";
    Result res = conn.query(cmd)!;

    usz count = 0;
    while (res.next()) {
        count++;
        int a_num;
        String a_string;
        String a_null;
        res.scan(0, &a_num)!;
        res.scan(1, &a_string)!;
        res.scan(2, &a_null)!;
        if (count == 1) {
            assert(a_num == 1, "a_num should be 1");
            assert(a_string == "hello", "a_string should be 'hello");
            assert(a_null == "", "a_null should be null");
        } 
        if (count == 2) {
            assert(a_num == 2, "a_num should be 1");
            assert(a_string == "world", "a_string should be 'hello");
            assert(a_null == "", "a_null should be null");
        }
    }

    assert(count == 2, "Should have fetched one row");

    driver.close(conn);
}