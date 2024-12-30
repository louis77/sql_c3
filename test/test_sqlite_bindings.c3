module sqlite_tests @test;

import std::io;
import sqlite;

fn void! test_sqlite_open()
{
mem::@report_heap_allocs_in_scope()
{
    SqliteHandle handle;
    CInt ret = sqlite::sqlite3_open("test.sqlite", &handle);
    assert(ret == sqlite::SQLITE_OK, "error on open(): %d", ret);

    ret = sqlite::sqlite3_close(handle);
    assert(ret == sqlite::SQLITE_OK, "error on close(): %d", ret);
};
}

fn void! test_sqlite_simple_query()
{
mem::@report_heap_allocs_in_scope()
{
    SqliteHandle handle;
    CInt ret = sqlite::sqlite3_open("test.sqlite", &handle);
    assert(ret == sqlite::SQLITE_OK, "error on open(): %d", ret);

    ZString* errmsgs;
    ret = sqlite::sqlite3_exec(handle, "SELECT 'hello' as world, 1 as a_num", fn CInt (void* context, CInt num_columns, ZString* result, ZString* col_names){
        assert(num_columns == 2, "incorrect number of columns returned: %d", num_columns);
        assert(col_names[0].str_view() == "world", "unexpected name of col[0]: '%s'", col_names[0]);
        assert(col_names[1].str_view() == "a_num", "unexpected name of col[1]: '%s'", col_names[1]);

        assert(result[0].str_view() == "hello", "unexpected result[0]: '%s'", result[0]);
        assert(result[1].str_view() == "1", "unexpected result[1]: '%s'", result[1]);

        return sqlite::SQLITE_OK;
    }, null, errmsgs);
    assert(ret == sqlite::SQLITE_OK, "error on exec(): %d", ret);

    ret = sqlite::sqlite3_close(handle);
    assert(ret == sqlite::SQLITE_OK, "error on close(): %d", ret);
};
}

fn void! test_sqlite_prepare()
{
mem::@report_heap_allocs_in_scope()
{
    SqliteHandle handle;
    CInt ret = sqlite::sqlite3_open("test.sqlite", &handle);
    assert(ret == sqlite::SQLITE_OK, "error on open(): %d", ret);
    assert(handle != null, "handle was null");

    ZString cmd = "SELECT 'hello' AS greeting;";
    SqliteStmt stmt;
    ret = sqlite::sqlite3_prepare_v2(handle, cmd, -1, &stmt, null);

    assert(ret == sqlite::SQLITE_OK, "error on prepare_v2(): %d", ret);
    assert(stmt != null, "stmt was null");

    while(true) {
        ret = sqlite::sqlite3_step(stmt);
        assert(ret == sqlite::SQLITE_ROW, "error on step(): %s", status_string(ret));

        ZString val = sqlite::sqlite3_column_text(stmt, 0);
        assert(val.str_view() == "hello", "value should be 'hello', was '%s'", val);
        break;
    }

    ret = sqlite::sqlite3_finalize(stmt);
    assert(ret == sqlite::SQLITE_OK);

    ret = sqlite::sqlite3_close(handle);
    assert(ret == sqlite::SQLITE_OK, "error on close(): %d", ret);
};
}