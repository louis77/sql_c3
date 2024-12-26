module mysql8 @test;

import std::io;

fn void! test_all() {
    mysql_library_init(0, null, null);

    Mysql mysql = mysql_init(null);
    assert(mysql != null, "mysql_init failed");
    
    Mysql mysql2 = mysql_real_connect(mysql, "localhost", "root", "", "test", 3306, null, 0);
    if (mysql2 == null) {
        CUInt errno = mysql_errno(mysql);
        io::printf("Errno: %d\n", errno);

        ZString error = mysql_error(mysql);
        assert(mysql != null, "mysql_real_connect failed, error: %d", error);
    }

    CUInt error = mysql_errno(mysql);
    assert(error == 0, "connect failed, expected 0, got %d", error);

    ZString cmd = "SELECT 'Hello, World' AS hello, 1 as world";
    CInt result = mysql_real_query(mysql, cmd, cmd.len());
    assert(result == 0, "query failed, expected 0, got %d", result);

    MysqlRes res = mysql_use_result(mysql);
    assert(res != null, "mysql_use_result failed");

    CUInt num_fields = mysql_num_fields(res);
    assert(num_fields == 2, "mysql_num_fields failed, expected 2, got %d", num_fields);

    MysqlRow row = mysql_fetch_row(res);
    assert(row != null, "mysql_fetch_row failed");

    mysql_close(mysql);
    mysql_library_end();
}