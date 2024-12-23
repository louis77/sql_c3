module sql;

import pg;

fn void! test_all() @test {
    Driver driver = pg::new_postgres();

    void* conn = driver.open("postgres://postgres@localhost/postgres");

    assert(driver.ping(conn) == true);
    
    driver.close(conn);
}