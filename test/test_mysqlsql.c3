module mysql_test @test;

import std::io;
import mysql8;
import sql;

String connection_string = "mysql://root@localhost:3306/test";

fn void! test_mysql_success() {
    Driver driver = mysql8::new_mysql();
    defer mysql8::free_mysql(driver);

    sql::Connection conn = driver.open(connection_string)!;
    defer driver.close(conn);

    driver.ping(connection_string)!;
}

fn void! test_mysql_query() @test {
    Driver driver = mysql8::new_mysql();
    defer mysql8::free_mysql(driver);

    sql::Connection conn = driver.open(connection_string)!;
    defer driver.close(conn);


    String cmd = `SELECT 1 as an_int, 'hello' as a_string, TRUE as a_bool, null as a_null 
        UNION
        SELECT 2 as an_int, 'world' as a_string, FALSE as a_bool, null as a_null`;
    Result res = conn.query(cmd)!;

    usz count = 0;
    while (res.next()) {
        count++;
        int a_num;
        String a_string;
        ZString a_zstring;
        bool a_bool;
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
            assert(a_bool, "a_bool should be 'true'");
            assert(a_null == "", "a_null should be null");
        } 
        if (count == 2) {
            assert(a_num == 2, "a_num should be 2");
            assert(a_string == "world", "a_string should be 'world'");
            assert(a_zstring.str_view() == "world", "a_zstring should be 'world'");
            assert(!a_bool, "a_bool should be 'false'");
            assert(a_null == "", "a_null should be null");
        }
    }

    assert(count == 2, "Should have fetched two rows");
}